#!/usr/bin/env python3
"""
GitHub Runner Automation - Web Management Interface
A Flask-based web GUI for managing GitHub runners and servers
"""

from flask import Flask, render_template, request, jsonify, redirect, url_for, flash
import subprocess
import json
import os
import yaml
from datetime import datetime
import threading
import time
import re
import logging

app = Flask(__name__)
app.secret_key = 'your-secret-key-change-this'

# Configuration
CONFIG_FILE = 'config.json'
INVENTORY_FILE = '../inventory/hosts'
VAULT_FILE = '../group_vars/runner-hosts/vault.yml'

# Cache for server status (5 seconds)
status_cache = {}
cache_timeout = 5

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(levelname)s in %(module)s: %(message)s')

class RunnerManager:
    def __init__(self):
        self.servers = self.load_servers()
        self.config = self.load_config()
    
    def load_servers(self):
        """Load servers from Ansible inventory"""
        servers = []
        try:
            with open(INVENTORY_FILE, 'r') as f:
                content = f.read()
                lines = content.split('\n')
                for line in lines:
                    if 'ansible_host=' in line and not line.startswith('#'):
                        parts = line.split()
                        if len(parts) >= 2:
                            name = parts[0]
                            host = parts[1].split('=')[1]
                            servers.append({
                                'name': name,
                                'host': host,
                                'status': 'unknown'
                            })
        except Exception as e:
            logging.error(f"Error loading servers: {e}")
        return servers
    
    def load_config(self):
        """Load configuration from vault file"""
        config = {}
        try:
            with open(VAULT_FILE, 'r') as f:
                content = f.read()
                for line in content.split('\n'):
                    if 'github_token:' in line and 'ghp_' in line:
                        config['github_token'] = line.split('"')[1]
                    elif 'github_username:' in line and not line.startswith('#'):
                        config['github_username'] = line.split('"')[1]
                    elif 'scan_interval_minutes:' in line:
                        config['scan_interval'] = int(line.split(':')[1].strip())
        except Exception as e:
            logging.error(f"Error loading config: {e}")
        return config
    
    def run_ansible_command(self, command, timeout=10, become=False, become_user=None):
        """Run an Ansible command and return the result"""
        try:
            ansible_cmd = f"ansible -i {INVENTORY_FILE} runner-hosts -m shell -a '{command}'"
            if become:
                ansible_cmd += f" -b -u {become_user}"
            result = subprocess.run(
                ansible_cmd,
                shell=True, capture_output=True, text=True, timeout=timeout
            )
            logging.debug(f"Ansible command: {ansible_cmd}")
            logging.debug(f"subprocess result: {result}")
            logging.debug(f"stdout: {result.stdout}")
            logging.debug(f"stderr: {result.stderr}")
            logging.debug(f"returncode: {result.returncode}")
            return result.stdout, result.stderr, result.returncode
        except Exception as e:
            logging.error(f"Exception in run_ansible_command: {e}")
            return '', str(e), 1
    
    def clean_ansible_output(self, output):
        """Clean Ansible output to extract just the actual result"""
        if not output:
            return output
        
        # Remove Ansible formatting
        lines = output.split('\n')
        cleaned_lines = []
        
        for line in lines:
            # Skip Ansible status lines
            if re.match(r'^.*\|.*CHANGED.*\|.*rc=\d+.*$', line):
                continue
            if re.match(r'^.*\|.*SUCCESS.*\|.*rc=\d+.*$', line):
                continue
            if re.match(r'^.*\|.*FAILED.*\|.*rc=\d+.*$', line):
                continue
            if line.startswith('[') and ']' in line and '|' in line:
                continue
            if line.strip() and not line.startswith('['):
                cleaned_lines.append(line.strip())
        
        return '\n'.join(cleaned_lines) if cleaned_lines else output.strip()
    
    def get_server_status(self, host):
        """Get status of a server via Ansible with caching"""
        global status_cache
        
        # Check cache first
        current_time = time.time()
        if host in status_cache:
            cached_data, cache_time = status_cache[host]
            if current_time - cache_time < cache_timeout:
                return cached_data
        
        try:
            # Quick status check with shorter timeout
            stdout, stderr, code = self.run_ansible_command('systemctl is-active github-runner-auto-register.timer', timeout=5)
            timer_status = self.clean_ansible_output(stdout).strip() if code == 0 else 'inactive'
            
            # Get all runner services and count in Python, using become for the github-runner user
            ansible_cmd = 'systemctl list-units --type=service | grep github-runner | grep "active running"'
            stdout, stderr, code = self.run_ansible_command(ansible_cmd, timeout=5, become=True, become_user='github-runner')
            logging.debug(f"Raw runner service output for {host}:\n{stdout}")
            logging.debug(f"repr(stdout): {repr(stdout)}")
            logging.debug(f"stderr: {stderr}")
            logging.debug(f"returncode: {code}")
            runner_lines = [line.strip() for line in self.clean_ansible_output(stdout).split('\n') if 'github-runner@' in line and 'active running' in line]
            logging.debug(f"Parsed runner lines for {host}: {runner_lines}")
            runner_count = len(runner_lines)
            logging.debug(f"Runner count for {host}: {runner_count}")
            
            # Quick log check
            stdout, stderr, code = self.run_ansible_command('tail -1 /var/log/github-runner-auto-register.log 2>/dev/null || echo "No log available"', timeout=5)
            last_log = self.clean_ansible_output(stdout).strip() if code == 0 and self.clean_ansible_output(stdout).strip() else 'No log available'
            
            # Determine overall status
            if timer_status == 'active':
                status = 'online'
            else:
                status = 'offline'
            
            # Cache the result
            result = {
                'status': status,
                'automation': 'active' if timer_status == 'active' else 'inactive',
                'runners': runner_count,
                'last_activity': last_log
            }
            
            status_cache[host] = (result, current_time)
            return result
            
        except Exception as e:
            logging.error(f"Error getting status for {host}: {e}")
            return {
                'status': 'offline',
                'automation': 'inactive',
                'runners': 0,
                'last_activity': f'Error: {str(e)}'
            }
    
    def get_runners(self, host):
        """Get all runner services and their repo mapping for a server"""
        ansible_cmd = 'systemctl list-units --type=service | grep github-runner@ | awk "{print $1}"'
        stdout, stderr, code = self.run_ansible_command(ansible_cmd, timeout=5, become=True, become_user='github-runner')
        runner_services = [line.strip() for line in self.clean_ansible_output(stdout).split('\n') if line.strip()]
        runners = []
        for service in runner_services:
            # Get Description and ActiveState
            show_cmd = f'systemctl show {service} --property=Description,ActiveState'
            show_out, show_err, show_code = self.run_ansible_command(show_cmd, timeout=5, become=True, become_user='github-runner')
            desc = ''
            state = ''
            repo = ''
            for line in show_out.split('\n'):
                if line.startswith('Description='):
                    desc = line.split('=',1)[1]
                    # Try to extract repo from description
                    if 'for ' in desc:
                        repo = desc.split('for ',1)[1]
                if line.startswith('ActiveState=') and not state:
                    # Only take the first valid ActiveState line
                    state_val = line.split('=',1)[1].strip()
                    # Only accept simple values (active, inactive, etc.)
                    if state_val in ['active', 'inactive', 'activating', 'deactivating', 'failed', 'reloading', 'maintenance']: 
                        state = state_val
                    else:
                        # If the value is weird (concatenated error), default to 'unknown'
                        state = 'unknown'
            runners.append({
                'service': service,
                'repo': repo,
                'escaped_repo': repo.replace('/', '-') if repo else '',
                'status': state,
                'description': desc
            })
        return runners
    
    def start_runner(self, host, service_name):
        """Start a runner service"""
        try:
            stdout, stderr, code = self.run_ansible_command(f'systemctl start {service_name}')
            return code == 0, stdout, stderr
        except Exception as e:
            return False, "", str(e)
    
    def stop_runner(self, host, service_name):
        """Stop a runner service"""
        try:
            stdout, stderr, code = self.run_ansible_command(f'systemctl stop {service_name}')
            return code == 0, stdout, stderr
        except Exception as e:
            return False, "", str(e)
    
    def restart_automation(self, host):
        """Restart the automation timer"""
        try:
            stdout, stderr, code = self.run_ansible_command('systemctl restart github-runner-auto-register.timer')
            return code == 0, stdout, stderr
        except Exception as e:
            return False, "", str(e)
    
    def trigger_scan(self, host):
        """Trigger a manual scan"""
        try:
            stdout, stderr, code = self.run_ansible_command('/usr/local/bin/register-github-runners')
            return code == 0, stdout, stderr
        except Exception as e:
            return False, "", str(e)

# Initialize the manager
manager = RunnerManager()

@app.route('/')
def dashboard():
    """Main dashboard page - loads immediately without server data"""
    return render_template('dashboard.html', 
                         servers=manager.servers, 
                         config=manager.config)

@app.route('/api/server-status')
def api_server_status():
    """API endpoint to get server statuses"""
    try:
        # Update server statuses
        for server in manager.servers:
            status = manager.get_server_status(server['host'])
            server.update(status)
        
        return jsonify({
            'success': True,
            'servers': manager.servers,
            'config': manager.config
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })

@app.route('/server/<host>')
def server_detail(host):
    """Server detail page"""
    server = next((s for s in manager.servers if s['host'] == host), None)
    if not server:
        return "Server not found", 404
    
    status = manager.get_server_status(host)
    runners = manager.get_runners(host)
    
    return render_template('server_detail.html', 
                         server=server, 
                         status=status, 
                         runners=runners)

@app.route('/api/server-detail/<host>')
def api_server_detail(host):
    """API endpoint for server detail with runner codes"""
    server = next((s for s in manager.servers if s['host'] == host), None)
    if not server:
        return jsonify({'success': False, 'error': 'Server not found'}), 404
    status = manager.get_server_status(host)
    runners = manager.get_runners(host)
    return jsonify({'success': True, 'server': server, 'status': status, 'runners': runners})

@app.route('/api/start_runner', methods=['POST'])
def api_start_runner():
    """API endpoint to start a runner"""
    data = request.get_json()
    host = data.get('host')
    service_name = data.get('service_name')
    
    success, stdout, stderr = manager.start_runner(host, service_name)
    return jsonify({'success': success, 'stdout': stdout, 'stderr': stderr})

@app.route('/api/stop_runner', methods=['POST'])
def api_stop_runner():
    """API endpoint to stop a runner"""
    data = request.get_json()
    host = data.get('host')
    service_name = data.get('service_name')
    
    success, stdout, stderr = manager.stop_runner(host, service_name)
    return jsonify({'success': success, 'stdout': stdout, 'stderr': stderr})

@app.route('/api/restart_automation', methods=['POST'])
def api_restart_automation():
    """API endpoint to restart automation"""
    data = request.get_json()
    host = data.get('host')
    
    success, stdout, stderr = manager.restart_automation(host)
    return jsonify({'success': success, 'stdout': stdout, 'stderr': stderr})

@app.route('/api/trigger_scan', methods=['POST'])
def api_trigger_scan():
    """API endpoint to trigger a scan"""
    data = request.get_json()
    host = data.get('host')
    
    success, stdout, stderr = manager.trigger_scan(host)
    return jsonify({'success': success, 'stdout': stdout, 'stderr': stderr})

@app.route('/config', methods=['GET', 'POST'])
def config_page():
    """Configuration page for viewing and updating vault variables and managing servers"""
    vault_vars = {}
    message = None
    # Load current vault variables
    try:
        with open(VAULT_FILE, 'r') as f:
            vault_vars = yaml.safe_load(f) or {}
    except Exception as e:
        message = f"Error loading vault: {e}"

    # Load current servers from inventory
    servers = manager.load_servers()

    if request.method == 'POST':
        form_data = request.form.to_dict()
        # Add server
        if 'add_server' in form_data:
            new_name = form_data.get('new_server_name')
            new_host = form_data.get('new_server_host')
            new_user = form_data.get('new_server_user', 'root')
            if new_name and new_host:
                try:
                    # Read inventory
                    with open(INVENTORY_FILE, 'r') as f:
                        lines = f.readlines()
                    # Find [runner-hosts] section
                    idx = None
                    for i, line in enumerate(lines):
                        if line.strip() == '[runner-hosts]':
                            idx = i
                            break
                    if idx is not None:
                        # Insert after [runner-hosts] and any comments/blank lines
                        insert_at = idx + 1
                        while insert_at < len(lines) and (lines[insert_at].strip().startswith('#') or not lines[insert_at].strip()):
                            insert_at += 1
                        new_entry = f"{new_name} ansible_host={new_host} ansible_user={new_user}\n"
                        lines.insert(insert_at, new_entry)
                        with open(INVENTORY_FILE, 'w') as f:
                            f.writelines(lines)
                        message = f"Server {new_name} added."
                        servers = manager.load_servers()
                    else:
                        message = "[runner-hosts] section not found in inventory."
                except Exception as e:
                    message = f"Error adding server: {e}"
        # Remove server
        elif 'remove_server' in form_data:
            remove_name = form_data.get('remove_server')
            try:
                # Find server host
                server = next((s for s in servers if s['name'] == remove_name), None)
                if server:
                    host = server['host']
                    # Stop and delete all runners on that server
                    runners = manager.get_runners(host)
                    for runner in runners:
                        manager.stop_runner(host, runner['service'])
                        # Optionally, disable or remove the service file if needed
                        manager.run_ansible_command(f'systemctl disable {runner["service"]}', become=True, become_user='github-runner')
                        manager.run_ansible_command(f'rm /etc/systemd/system/{runner["service"]}', become=True, become_user='root')
                    manager.run_ansible_command('systemctl daemon-reload', become=True, become_user='root')
                # Remove from inventory
                with open(INVENTORY_FILE, 'r') as f:
                    lines = f.readlines()
                new_lines = [line for line in lines if not (line.strip().startswith(remove_name + ' ') or line.strip() == remove_name)]
                with open(INVENTORY_FILE, 'w') as f:
                    f.writelines(new_lines)
                message = f"Server {remove_name} and its runners removed."
                servers = manager.load_servers()
            except Exception as e:
                message = f"Error removing server: {e}"
        # Update vault variables
        else:
            try:
                for key in form_data:
                    vault_vars[key] = form_data[key]
                with open(VAULT_FILE, 'w') as f:
                    yaml.safe_dump(vault_vars, f, default_flow_style=False, allow_unicode=True)
                message = "Configuration updated successfully."
            except Exception as e:
                message = f"Error updating vault: {e}"
    return render_template('config.html', vault_vars=vault_vars, message=message, servers=servers)

@app.route('/logs')
def logs_page():
    """Logs page"""
    try:
        stdout, stderr, code = manager.run_ansible_command('tail -50 /var/log/github-runner-auto-register.log')
        logs = stdout if code == 0 else "No logs available"
    except:
        logs = "Error loading logs"
    
    return render_template('logs.html', logs=logs)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False) 