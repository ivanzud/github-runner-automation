# GitHub Runner Automation

**Self-hosted GitHub Actions runners, provisioned automatically for every repository that needs them.**

---

> **Warning**
>
> This project is **beta software**. It is not production-ready. Use at your own risk and do not rely on it for critical infrastructure without thorough testing and review.

---

## About

**GitHub Runner Automation** is a toolkit for teams and organizations who want to automate the management of self-hosted GitHub Actions runners across many repositories and servers. If you use `runs-on: self-hosted` in your workflows, this project will:

- Detect which repositories need self-hosted runners
- Automatically provision and register a runner for each repo
- Manage runners across multiple servers using Ansible
- Provide a web dashboard for monitoring and control

> **Note:**
> This project is for **self-hosted runners** only. It does not manage GitHub-hosted (cloud) runners.

---

## Features

| Feature                | Description                                                                   |
| ---------------------- | ----------------------------------------------------------------------------- |
| Automatic Provisioning | Detects repos with `runs-on: self-hosted` and registers runners automatically |
| Multi-Server Support   | Manage runners across any number of servers via Ansible                       |
| Web Dashboard          | Monitor servers, runners, and logs in your browser                            |
| Easy Scaling           | Add/remove servers in your inventory, automation handles the rest             |
| Secure by Default      | Uses SSH keys, stores secrets in vault files                                  |
| Manual Control         | Start/stop/restart runners from the web UI                                    |

---

## How It Works

1. **Scan**: The system scans your GitHub organization/user for repositories with workflows that use `runs-on: self-hosted`.
2. **Provision**: For each repo, it provisions a runner on one of your servers (using Ansible and systemd).
3. **Monitor**: The web dashboard shows the status of all servers and runners.
4. **Manage**: You can add/remove servers, update configuration, and control runners from the web UI.

> **Important:**
> This automation will **add** runners for new repos that need them. However, if you delete a repo or remove its workflow, you may need to manually clean up the corresponding runner. Automatic cleanup of orphaned runners is not guaranteed in this beta version.

---

## Quick Start

### Prerequisites

- Ansible installed on your management machine
- Python 3 (for the web UI)
- SSH access to your runner servers (root or sudo)
- GitHub Personal Access Token
  - Classic PAT: `repo` (and `admin:org` if you manage org repos)
  - Fine-grained PAT: repository access + Actions/Administration read-write

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/github-runner-automation.git
cd github-runner-automation
```

### 2. Configure Your Servers and GitHub Token

- Copy the example files:
  ```bash
  cp inventory/hosts.example inventory/hosts
  cp group_vars/runner-hosts/vault.yml.example group_vars/runner-hosts/vault.yml
  ```
- Edit `inventory/hosts` and add your servers:

  ```ini
  [runner-hosts]
  runner-01 ansible_host=YOUR_SERVER_IP ansible_user=root

  [runner-hosts:vars]
  ansible_python_interpreter=/usr/bin/python3
  ```

- Edit `group_vars/runner-hosts/vault.yml`:
  ```yaml
  github_token: "ghp_your_github_token_here"
  github_username: "your-github-username"
  scan_interval_minutes: 15
  ```

Optional settings you can add to the same file:

```yaml
vault_runner_labels: "self-hosted,linux,x64"
vault_runner_name_prefix: "runner"
vault_runner_work_dir: "/home/github-runner/actions-runner"
vault_runner_user: "github-runner"
```

### 3. Deploy Everything

```bash
./install.sh
```

This runs the production playbook (`deploy-production.yml`) and installs a systemd timer.

### 4. Start the Web Management Interface

```bash
cd web-gui
./start.sh
```

Open your browser to: [http://localhost:8080](http://localhost:8080)

---

## Web Interface

- **Dashboard**: See all servers, runners, and their status
- **Server Management**: Add/remove servers, view details
- **Runner Control**: Start/stop/restart runners
- **Configuration**: Edit GitHub token and settings
- **Logs**: View recent automation activity

---

## Useful Commands

Check automation status (recommended):

```bash
./scripts/check-status.sh
```

Check automation status (manual):

```bash
ansible -i inventory/hosts runner-hosts -m shell -a "systemctl status github-runner-auto-register.timer"
```

Check active runners:

```bash
ansible -i inventory/hosts runner-hosts -m shell -a "systemctl list-units --type=service | grep github-runner"
```

Trigger manual scan:

```bash
ansible -i inventory/hosts runner-hosts -m shell -a "/usr/local/bin/register-github-runners"
```

Note: `github-runner-auto-register.service` is a oneshot service. It will show
as `inactive` between runs; the timer controls scheduling.

---

## Project Structure

```
github-runner-automation/
├── install.sh                # One-command installer
├── inventory/hosts           # Server inventory
├── group_vars/runner-hosts/vault.yml  # GitHub/runner config
├── scripts/                  # Automation scripts
├── templates/                # Jinja2 templates for Ansible
├── web-gui/                  # Web management interface
```

---

## Troubleshooting

- **Web UI not starting?**
  - Check Python version (3.7+ recommended)
  - Run `pip install -r web-gui/requirements.txt`
- **SSH errors?**
  - Ensure your SSH key is on all servers
  - Check `ansible_user` and `ansible_host` in inventory
- **Runners not registering?**
  - Check your GitHub token permissions
  - View logs in `/var/log/github-runner-auto-register.log`
  - The log is rotated daily (keeps 14 days)

---

## Security

- GitHub token is stored securely in the vault file
- Uses SSH key authentication for all server access
- Runners run as a dedicated system user

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

**GitHub Runner Automation is for anyone who wants to automate and scale self-hosted GitHub Actions runners. Still in beta—test, contribute, and help make it better!**
