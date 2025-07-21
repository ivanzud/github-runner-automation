# GitHub Runner Auto-Registration Scripts

Scripts to automatically register and manage GitHub Actions runners for repositories that use self-hosted runners.

---

## 🚀 Quick Start

### 1. Prerequisites

- Complete the main setup in the project root (see main README)
- Root or sudo access on your runner hosts
- GitHub Personal Access Token with `repo` and `admin:org` permissions

### 2. Install on Your Runner Host

Run the main installer from the project root:

```bash
./install.sh
```

This will:

- Copy scripts to the correct locations
- Set up systemd services and timers
- Register runners automatically

---

## 🛠️ Script Files

- `auto-register-runners.sh` — Main script for detecting and registering runners
- `github-runner-auto-register.service` — Systemd service file
- `github-runner-auto-register.timer` — Systemd timer for periodic execution
- `install-auto-register.sh` — Installation script

---

## ⚙️ How It Works

- Scans your GitHub repositories for workflows using `runs-on: self-hosted`
- Registers runners for repositories that need them
- Manages runner lifecycle with systemd services
- Runs periodically to ensure all repositories have runners

---

## 🐞 Troubleshooting

- **Token Permission Denied**
  - Ensure the token has the required permissions
  - Check if the token is valid and not expired
- **Runner Registration Fails**
  - Check network connectivity to GitHub
  - Verify the repository exists and is accessible
  - Check logs for specific error messages
- **Service Won't Start**
  - Verify all dependencies are installed
  - Check systemd service file syntax
  - Ensure the script has execute permissions
- **Debug Mode**
  - Run the script with debug output:
    ```bash
    sudo bash -x /opt/scripts/auto-register-runners.sh
    ```

---

## 🧩 Project Structure (Scripts)

```
scripts/
├── auto-register-runners.sh
├── github-runner-auto-register.service
├── github-runner-auto-register.timer
├── install-auto-register.sh
├── check-status.sh
├── README.md
```

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

**Automate your GitHub runner management with ease! 🚀**
