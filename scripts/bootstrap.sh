#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================
# Cloud Server Baseline
# Bootstrap Script
# ==============================

PROJECT_NAME="cloud-server-baseline"
LOG_DIR="/var/log/${PROJECT_NAME}"
LOG_FILE="${LOG_DIR}/bootstrap.log"

# --- Trap for errors ---
trap 'echo "[ERROR] Script failed at line $LINENO" | tee -a "$LOG_FILE"' ERR

# --- Functions ---

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" | tee -a "$LOG_FILE"
}

check_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    exit 1
  fi
}

check_package_manager() {
  if ! command -v apt &>/dev/null; then
    log "ERROR: apt package manager not found"
    exit 1
  fi
}

create_log_dir() {
  mkdir -p "$LOG_DIR"
  touch "$LOG_FILE"
  chmod 750 "$LOG_DIR"
}

system_info() {
  log "System information:"
  log "Hostname: $(hostname)"
  log "OS: $(lsb_release -ds || cat /etc/os-release | grep PRETTY_NAME)"
  log "Kernel: $(uname -r)"
}

update_system() {
  log "Updating system packages"
  apt update -y
  apt upgrade -y
}

install_base_packages() {
  log "Installing base packages"
  apt install -y \
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    git \
    unzip
}

# --- Main Execution ---

check_root
create_log_dir

# Redirect all output to log
exec > >(tee -a "$LOG_FILE") 2>&1

log "Starting bootstrap process"
system_info
check_package_manager
update_system
install_base_packages
log "Bootstrap completed successfully"
