# GitHub Runner Web Management Interface

A modern web-based GUI for managing your GitHub Runner Automation system. Monitor servers, control runners, and manage your automation from a beautiful web interface.

---

## 🚀 Quick Start

### 1. Prerequisites

- Complete the main setup in the project root (see main README)
- Python 3.7+
- All dependencies installed (see below)

### 2. Start the Web Interface

```bash
cd web-gui
./start.sh
```

### 3. Access the Interface

Open your browser and go to: **http://localhost:8080**

---

## 🌟 Features

- **Dashboard**: Real-time overview of all servers and runners
- **Server Management**: Add/remove servers, view details
- **Runner Control**: Start, stop, and restart runners
- **Configuration**: Edit GitHub token and settings
- **Logs**: View recent automation activity

---

## 🛠️ How to Use

1. **Dashboard**: See all servers, runners, and their status at a glance
2. **Manage Servers**: Add or remove servers from the config page
3. **Control Runners**: Start/stop/restart runners from the server detail page
4. **Edit Configuration**: Update GitHub token and settings in the config area
5. **View Logs**: Check recent automation activity in the logs section

---

## ⚙️ Configuration Files

- `../inventory/hosts` — Server inventory (edit to add/remove servers)
- `../group_vars/runner-hosts/vault.yml` — GitHub and runner configuration

---

## 🐞 Troubleshooting

- **Web UI not starting?**
  - Check Python version (3.7+ recommended)
  - Run `pip install -r requirements.txt` in `web-gui/`
- **SSH errors?**
  - Ensure your SSH key is on all servers
  - Check `ansible_user` and `ansible_host` in inventory
- **No servers found?**
  - Make sure `../inventory/hosts` is configured and readable
- **Runners not registering?**
  - Check your GitHub token permissions
  - View logs in `/var/log/github-runner-auto-register.log` on your servers

---

## 🧩 Project Structure (Web UI)

```
web-gui/
├── app.py           # Flask application
├── templates/       # HTML templates
├── requirements.txt # Python dependencies
├── start.sh         # Startup script
```

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

**Enjoy managing your GitHub Runners visually! 🚀**
