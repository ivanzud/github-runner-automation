# GitHub Runner Auto-Registration Scripts

This directory contains scripts to automatically register GitHub Actions runners for repositories that have self-hosted runner configurations.

## 🚀 Overview

The auto-registration system automatically:

- Scans your GitHub repositories for self-hosted runner configurations
- Registers runners for repositories that need them
- Manages runner lifecycle with systemd services
- Runs periodically to ensure all repositories have runners

## 📁 Files

- **`auto-register-runners.sh`**: Main script that detects and registers runners
- **`github-runner-auto-register.service`**: Systemd service file
- **`github-runner-auto-register.timer`**: Systemd timer for periodic execution
- **`install-auto-register.sh`**: Installation script
- **`README.md`**: This documentation

## 🔧 Installation

### Prerequisites

1. **GitHub Personal Access Token** with the following permissions:

   - `repo` (Full control of private repositories)
   - `admin:org` (Full control of organizations and teams)

2. **Root access** on the runner host

3. **Supported OS**: Ubuntu, Debian, CentOS, RHEL, Fedora

### Quick Installation

1. **Download the scripts** to your runner host:

   ```bash
   # Create a temporary directory
   mkdir -p /tmp/github-runner-auto-register
   cd /tmp/github-runner-auto-register

   # Copy the scripts from this repository
   # (You'll need to copy them manually or download from GitHub)
   ```

2. **Run the installation script**:

   ```bash
   sudo bash install-auto-register.sh
   ```

3. **Follow the prompts** to enter your GitHub token

### Manual Installation

If you prefer manual installation:

1. **Install dependencies**:

   ```bash
   # Ubuntu/Debian
   sudo apt-get update && sudo apt-get install -y jq curl git systemd

   # CentOS/RHEL
   sudo yum install -y jq curl git systemd

   # Fedora
   sudo dnf install -y jq curl git systemd
   ```

2. **Copy files**:

   ```bash
   sudo mkdir -p /opt/scripts
   sudo cp auto-register-runners.sh /opt/scripts/
   sudo chmod +x /opt/scripts/auto-register-runners.sh

   sudo cp github-runner-auto-register.service /etc/systemd/system/
   sudo cp github-runner-auto-register.timer /etc/systemd/system/
   ```

3. **Configure GitHub token**:

   ```bash
   echo "your-github-token-here" | sudo tee /etc/github-runner-token
   sudo chmod 600 /etc/github-runner-token
   ```

4. **Enable services**:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable github-runner-auto-register.timer
   sudo systemctl start github-runner-auto-register.timer
   ```

## 🎯 How It Works

### Detection Process

1. **Repository Scanning**: The script fetches all your repositories via GitHub API
2. **Workflow Analysis**: For each repository, it checks `.github/workflows/` directory
3. **Self-Hosted Detection**: Looks for `runs-on: self-hosted` in workflow files
4. **Runner Registration**: Registers runners for repositories that need them

### Runner Management

- **Naming Convention**: `{prefix}-{repo-name}-{hostname}`
- **Directory Structure**: `/opt/github-runners/{repo}/{runner-name}/`
- **Systemd Services**: Each runner gets its own systemd service
- **Automatic Restart**: Runners restart automatically if they fail

### Configuration

Environment variables can be customized:

```bash
# Runner configuration
RUNNER_LABELS="self-hosted,linux,x64,ansible"
RUNNER_NAME_PREFIX="auto-runner"
RUNNER_WORK_DIR="/opt/github-runners"
RUNNER_USER="github-runner"

# GitHub configuration
GITHUB_TOKEN="your-token"
GITHUB_USERNAME="your-username"
```

## 📊 Usage

### Manual Execution

Run the registration manually:

```bash
sudo /usr/local/bin/register-github-runners
```

### Check Status

View service status:

```bash
sudo systemctl status github-runner-auto-register.timer
sudo systemctl list-timers github-runner-auto-register.timer
```

### View Logs

Check logs:

```bash
# Service logs
sudo journalctl -u github-runner-auto-register.service

# Script logs
sudo tail -f /var/log/github-runner-auto-register.log
```

### List Registered Runners

Check which runners are registered:

```bash
sudo systemctl list-units --type=service | grep github-runner
```

## 🔧 Customization

### Modify Timer Frequency

Edit `/etc/systemd/system/github-runner-auto-register.timer`:

```ini
[Timer]
OnBootSec=5min
OnUnitActiveSec=15min  # Change from 30min to 15min
Unit=github-runner-auto-register.service
```

### Add Custom Labels

Edit the service file to add custom labels:

```ini
[Service]
Environment=RUNNER_LABELS=self-hosted,linux,x64,ansible,custom-label
```

### Change Runner Directory

Modify the work directory:

```ini
[Service]
Environment=RUNNER_WORK_DIR=/custom/path/to/runners
```

## 🛠️ Troubleshooting

### Common Issues

1. **Token Permission Denied**

   - Ensure the token has the required permissions
   - Check if the token is valid and not expired

2. **Runner Registration Fails**

   - Check network connectivity to GitHub
   - Verify the repository exists and is accessible
   - Check logs for specific error messages

3. **Service Won't Start**
   - Verify all dependencies are installed
   - Check systemd service file syntax
   - Ensure the script has execute permissions

### Debug Mode

Run the script with debug output:

```bash
sudo bash -x /opt/scripts/auto-register-runners.sh
```

### Reset Installation

To completely reset the installation:

```bash
# Stop and disable services
sudo systemctl stop github-runner-auto-register.timer
sudo systemctl disable github-runner-auto-register.timer

# Remove files
sudo rm -rf /opt/scripts/auto-register-runners.sh
sudo rm -f /etc/systemd/system/github-runner-auto-register.service
sudo rm -f /etc/systemd/system/github-runner-auto-register.timer
sudo rm -f /usr/local/bin/register-github-runners
sudo rm -f /etc/github-runner-token

# Reload systemd
sudo systemctl daemon-reload
```

## 🔒 Security Considerations

- **Token Storage**: GitHub tokens are stored in `/etc/github-runner-token` with 600 permissions
- **User Isolation**: Runners run under a dedicated `github-runner` user
- **Directory Permissions**: Runner directories are owned by the runner user
- **Network Access**: Only HTTPS connections to GitHub API are made

## 📈 Monitoring

### Health Checks

Monitor runner health:

```bash
# Check all runner services
sudo systemctl status github-runner@*

# Check specific runner
sudo systemctl status github-runner@repo-name-runner-name
```

### Metrics

Track registration activity:

```bash
# View recent registrations
sudo journalctl -u github-runner-auto-register.service --since "1 hour ago"

# Count registered runners
sudo systemctl list-units --type=service | grep github-runner | wc -l
```

## 🤝 Contributing

To contribute to these scripts:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.
