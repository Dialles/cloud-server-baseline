#!/usr/bin/env bash
set -Eeuo pipefail

############################################
# Global configuration
############################################
SCRIPT_NAME="$(basename "$0")"
LOG_FILE="/var/log/cloud-baseline-users.log"
USERNAME="${BASELINE_USER:-admin}"
SHELL="/bin/bash"
SUDO_GROUP="sudo"
PASSWORDLESS_SUDO=true

############################################
# Logging
############################################
timestamp() { date "+%Y-%m-%d %H:%M:%S"; }

log() {
  local level="$1"; shift
  echo "$(timestamp) [$level] $SCRIPT_NAME: $*" | tee -a "$LOG_FILE"
}

############################################
# Error handling
############################################
trap 'log ERROR "Failed at line $LINENO"; exit 1' ERR

############################################
# Pre-flight checks
############################################
require_root() {
  if [[ $EUID -ne 0 ]]; then
    log ERROR "This script must be run as root"
    exit 1
  fi
}

require_root

log INFO "Starting user baseline configuration"

############################################
# Ensure sudo group exists
############################################
if ! getent group "$SUDO_GROUP" >/dev/null; then
  log INFO "Creating group $SUDO_GROUP"
  groupadd "$SUDO_GROUP"
fi

############################################
# Create user if missing
############################################
if ! id "$USERNAME" &>/dev/null; then
  log INFO "Creating user $USERNAME"
  useradd \
    --create-home \
    --shell "$SHELL" \
    --groups "$SUDO_GROUP" \
    "$USERNAME"
else
  log INFO "User $USERNAME already exists"
fi

############################################
# Ensure sudo group membership
############################################
if ! id -nG "$USERNAME" | grep -qw "$SUDO_GROUP"; then
  log INFO "Adding $USERNAME to $SUDO_GROUP group"
  usermod -aG "$SUDO_GROUP" "$USERNAME"
fi

############################################
# Configure sudoers safely
############################################
SUDOERS_FILE="/etc/sudoers.d/$USERNAME"

if [[ "$PASSWORDLESS_SUDO" == true ]]; then
  if [[ ! -f "$SUDOERS_FILE" ]]; then
    log INFO "Configuring passwordless sudo"
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
    chmod 0440 "$SUDOERS_FILE"
  else
    log INFO "Sudoers file already exists"
  fi
fi

############################################
# Home permissions
############################################
HOME_DIR="/home/$USERNAME"
if [[ -d "$HOME_DIR" ]]; then
  log INFO "Fixing home permissions"
  chown -R "$USERNAME:$USERNAME" "$HOME_DIR"
  chmod 0750 "$HOME_DIR"
fi

############################################
# Validation
############################################
log INFO "Validating configuration"

sudo -l -U "$USERNAME" &>/dev/null && \
  log INFO "Sudo access validated" || \
  log ERROR "Sudo validation failed"

log INFO "User baseline configuration completed successfully"
