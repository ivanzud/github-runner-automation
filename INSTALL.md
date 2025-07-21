# GitHub Runner Automation - Quick Install

Automatically register GitHub Actions self-hosted runners for repositories that need them. **Setup in 3 simple steps!**

## 🚀 Quick Start (3 Steps)

### Step 1: Clone and Setup

```bash
# Clone the repository
git clone https://github.com/your-username/github-runner-automation.git
cd github-runner-automation

# Create your configuration
cp group_vars/test-servers/vault.yml.example group_vars/test-servers/vault.yml
```

### Step 2: Configure Your Settings

Edit `group_vars/test-servers/vault.yml` with your GitHub details:

```yaml
# Your GitHub Personal Access Token (required)
vault_github_token: "ghp_your_token_here"

# Your GitHub username
vault_github_username: "your-github-username"

# Optional: Customize these settings
vault_runner_labels: "self-hosted,linux,x64"
vault_runner_name_prefix: "auto-runner"
vault_scan_interval_minutes: 5
```

**Get your GitHub token**: Go to [GitHub Settings > Tokens](https://github.com/settings/tokens) and create a new token with `repo` and `admin:org` permissions.

### Step 3: Deploy to Your Server

```bash
# Add your server to the inventory
echo "your-server-ip" > inventory/test-hosts

# Deploy (replace 'your-server-ip' with your actual server IP)
ansible-playbook -i inventory/test-hosts deploy-auto-register-test.yml
```

**That's it!** Your automation will start scanning repositories every 5 minutes and automatically register runners where needed.

## 📋 Prerequisites

- **Server**: Ubuntu/Debian/CentOS/RHEL/Fedora
- **GitHub Token**: Personal Access Token with `repo` and `admin:org` permissions
- **SSH Access**: Root or sudo access to your server
- **Ansible**: Installed on your local machine

### Install Ansible (if needed)

```bash
# macOS
brew install ansible

# Ubuntu/Debian
sudo apt update && sudo apt install ansible

# CentOS/RHEL
sudo yum install ansible
```

## 🔧 Configuration Options

### Scan Frequency

```yaml
vault_scan_interval_minutes: 5 # Check every 5 minutes
```

### Runner Labels

```yaml
vault_runner_labels: "self-hosted,linux,x64,custom-label"
```

### Runner Naming

```yaml
vault_runner_name_prefix: "my-runner" # Runners will be named: my-runner-repo-name-hostname
```

## 📊 What It Does

✅ **Automatically scans** your GitHub repositories every 5 minutes  
✅ **Detects repositories** with `runs-on: self-hosted` in workflows  
✅ **Registers runners** only where needed  
✅ **Manages runner lifecycle** with systemd services  
✅ **Parallel processing** for faster execution

## 🛠️ Management Commands

### Quick Status Check

```bash
# Check everything at once
./scripts/check-status.sh
```

### Individual Commands

```bash
# Check timer status
ssh root@your-server "systemctl status github-runner-auto-register.timer"

# View logs
ssh root@your-server "tail -f /var/log/github-runner-auto-register.log"

# Manual trigger
ssh root@your-server "/usr/local/bin/register-github-runners"

# List registered runners
ssh root@your-server "systemctl list-units --type=service | grep github-runner"
```

## 🔍 Troubleshooting

### Common Issues

**"Invalid GitHub token"**

- Check your token has `repo` and `admin:org` permissions
- Verify the token is not expired

**"Connection refused"**

- Ensure your server is accessible via SSH
- Check firewall settings

**"Permission denied"**

- Make sure you have root/sudo access to the server

### Get Help

- Check the logs: `ssh root@your-server "tail -20 /var/log/github-runner-auto-register.log"`
- View detailed documentation in the [README.md](README.md)
- Open an issue on GitHub

## 🎯 Example Workflow

1. **Create a repository** with a workflow file:

```yaml
# .github/workflows/test.yml
name: Test
on: [push]
jobs:
  test:
    runs-on: self-hosted # This will trigger runner registration
    steps:
      - run: echo "Hello from self-hosted runner!"
```

2. **Deploy this automation** to your server
3. **Wait 5 minutes** - a runner will be automatically registered!
4. **Push to your repo** - the workflow will run on your self-hosted runner

## 📈 Performance

- **Detection Speed**: New repositories detected within 5 minutes
- **Processing**: Up to 4 repositories processed simultaneously
- **Resource Usage**: ~1GB RAM per active runner
- **API Usage**: ~100-200 requests per scan (well within GitHub limits)

---

**Need help?** Check the [full documentation](README.md) or [open an issue](https://github.com/your-username/github-runner-automation/issues)!
