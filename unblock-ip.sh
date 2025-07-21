#!/bin/bash
# This script permanently whitelists your IP address in CrowdSec and Fail2ban
# Use this if you are locked out of your server due to security bans

set -e

YOUR_IP=${1:-$(curl -s https://api.ipify.org)}
if [[ -z "$YOUR_IP" ]]; then
  echo "Could not determine your public IP. Please provide it as an argument."
  exit 1
fi

log() {
  echo -e "[INFO] $1"
}

warning() {
  echo -e "[WARNING] $1"
}

log "Unblocking IP: $YOUR_IP"

# 1. Remove IP from CrowdSec blocks
log "Removing IP from CrowdSec blocks..."
if command -v cscli &> /dev/null; then
  cscli decisions delete --ip "$YOUR_IP" || true
  cscli decisions add --ip "$YOUR_IP" --duration 8760h --type whitelist || true
  log "✅ IP whitelisted in CrowdSec for 1 year"
else
  warning "CrowdSec not found, skipping..."
fi

# 2. Remove IP from Fail2ban blocks
log "Removing IP from Fail2ban blocks..."
if command -v fail2ban-client &> /dev/null; then
  for jail in $(fail2ban-client status | grep "Jail list" | cut -d: -f2 | tr ',' ' '); do
    fail2ban-client set "$jail" unbanip "$YOUR_IP" 2>/dev/null || true
    log "✅ Unbanned from Fail2ban jail: $jail"
  done
  # Add to ignoreip in jail.local
  if [ -f /etc/fail2ban/jail.local ]; then
    if ! grep -q "$YOUR_IP" /etc/fail2ban/jail.local; then
      echo "ignoreip = $YOUR_IP" >> /etc/fail2ban/jail.local
      log "✅ Added IP to Fail2ban whitelist"
    else
      log "✅ IP already in Fail2ban whitelist"
    fi
  else
    echo "[DEFAULT]" > /etc/fail2ban/jail.local
    echo "ignoreip = $YOUR_IP" >> /etc/fail2ban/jail.local
    log "✅ Created Fail2ban config with IP whitelist"
  fi
  # Restart Fail2ban
  systemctl restart fail2ban
  log "✅ Restarted Fail2ban"
else
  warning "Fail2ban not found, skipping..."
fi

log "Unblock complete." 