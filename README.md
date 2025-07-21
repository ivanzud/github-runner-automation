# 🚀 GitHub Runner Automation

**Easily deploy and manage GitHub Actions self-hosted runners across multiple servers with Ansible and a modern web interface.**

---

## ⚠️ Protect Your Secrets! (Important for All Users)

- **Never commit your real inventory or vault files to git.**
- This repo includes:
  - `inventory/hosts.example` — Example inventory file
  - `group_vars/runner-hosts/vault.yml.example` — Example vault file
- **To get started:**
  1. Copy these example files to their real locations:
     - `cp inventory/hosts.example inventory/hosts`
     - `cp group_vars/runner-hosts/vault.yml.example group_vars/runner-hosts/vault.yml`
  2. Edit them with your real server info and secrets.
- Your real files are ignored by git and will never be uploaded.

---

## 📝 Step-by-Step Quick Start

### 1. Prerequisites

- **Ansible** installed on your management machine
- **Python 3** (for the web UI)
- **SSH access** to your runner servers (root or sudo)
- **GitHub Personal Access Token** with `repo` and `admin:org` permissions

### 2. Clone the Repository

```bash
git clone https://github.com/your-username/github-runner-automation.git
cd github-runner-automation
```

### 3. Configure Your Servers and GitHub Token

#### a. Edit the Inventory File

Edit `inventory/hosts` and add your servers:

```ini
[runner-hosts]
runner-01 ansible_host=YOUR_SERVER_IP ansible_user=root

[runner-hosts:vars]
ansible_python_interpreter=/usr/bin/python3
```

#### b. Edit the Vault File

Edit `group_vars/runner-hosts/vault.yml`:

```yaml
github_token: "ghp_your_github_token_here"
github_username: "your-github-username"
scan_interval_minutes: 5
```

### 4. Deploy Everything with Ansible

```bash
./install.sh
```

This will:

- Install all dependencies
- Set up systemd services and timers
- Register runners on all servers

### 5. Start the Web Management Interface

```bash
cd web-gui
./start.sh
```

Open your browser to: **http://localhost:8080**

---

## 🌟 Features

- **Automatic Detection**: Finds repos needing self-hosted runners
- **Parallel Processing**: Fast scanning and registration
- **Web Management**: Modern UI for monitoring and control
- **Auto-Scaling**: Registers runners for new repos automatically
- **Production Ready**: Systemd, logging, error handling
- **Real-time Monitoring**: Live status and logs

---

## 🖥️ Web Interface Usage

- **Dashboard**: See all servers, runners, and their status
- **Server Management**: Add/remove servers, view details
- **Runner Control**: Start/stop/restart runners
- **Configuration**: Edit GitHub token and settings
- **Logs**: View recent automation activity

---

## 🛠️ Common Management Commands

Check automation status:

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

---

## 🧩 Project Structure

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

## 🆘 Troubleshooting

- **Web UI not starting?**
  - Check Python version (3.7+ recommended)
  - Run `pip install -r web-gui/requirements.txt`
- **SSH errors?**
  - Ensure your SSH key is on all servers
  - Check `ansible_user` and `ansible_host` in inventory
- **Runners not registering?**
  - Check your GitHub token permissions
  - View logs in `/var/log/github-runner-auto-register.log`

---

## 🔒 Security

- GitHub token is stored securely in the vault file
- Uses SSH key authentication for all server access
- Runners run as a dedicated system user

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

**Enjoy managing your GitHub Runners with ease! 🚀**
