#!/usr/bin/env bash
# Setup pós-instalação: Fedora KDE
# Apps: Chrome, Discord, VS Code, PostgreSQL, Docker, Git, Spotify
# Uso: chmod +x setup-fedora.sh && ./setup-fedora.sh
#
# O script é dividido em etapas. Cada etapa concluída é registrada em
# STATE_FILE, então se algo falhar no meio do caminho, basta rodar o
# script de novo: as etapas já feitas são puladas e ele retoma do ponto
# da falha, sem repetir trabalho nem deixar passos pela metade.

set -euo pipefail

if [ "$EUID" -eq 0 ]; then
  echo "Não rode como root. Rode como usuário normal que o script usa sudo quando precisar."
  exit 1
fi

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/setup-fedora.done"
mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

log() { echo -e "\n\033[1;34m==> $*\033[0m"; }

step_done() { grep -qxF "$1" "$STATE_FILE"; }
mark_done() { echo "$1" >> "$STATE_FILE"; }

run_step() {
  local name="$1"; shift
  if step_done "$name"; then
    echo "Pulando etapa já concluída: $name"
    return 0
  fi
  log "$name"
  "$@"
  mark_done "$name"
}

on_error() {
  echo -e "\n\033[1;31mFalhou na etapa atual (veja acima). Corrija o problema e rode o script de novo: ele retoma daqui.\033[0m"
}
trap on_error ERR

# ---------------------------------------------------------------
# Idioma e fuso horário
# ---------------------------------------------------------------
step_locale() {
  sudo localectl set-locale LANG=en_US.UTF-8
  sudo timedatectl set-timezone America/Cuiaba
}
run_step "locale-timezone" step_locale

# ---------------------------------------------------------------
# Base: atualização + RPM Fusion + Flathub
# ---------------------------------------------------------------
step_update() { sudo dnf upgrade -y --refresh; }
run_step "system-upgrade" step_update

step_rpmfusion() {
  sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
}
run_step "rpmfusion" step_rpmfusion

step_flathub() {
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}
run_step "flathub" step_flathub

step_plugins_core() { sudo dnf install -y dnf-plugins-core; }
run_step "dnf-plugins-core" step_plugins_core

step_codecs() {
  sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
  sudo dnf groupupdate -y multimedia sound-and-video
}
run_step "codecs-multimidia" step_codecs

step_nvidia() { sudo dnf install -y akmod-nvidia; }
run_step "driver-nvidia" step_nvidia

# ---------------------------------------------------------------
# Git
# ---------------------------------------------------------------
step_git() { sudo dnf install -y git; }
run_step "git" step_git

# ---------------------------------------------------------------
# Google Chrome (o .rpm oficial já adiciona o repo pra atualizar depois)
# ---------------------------------------------------------------
step_chrome() {
  sudo dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
}
run_step "chrome" step_chrome

# ---------------------------------------------------------------
# Visual Studio Code (repo da Microsoft)
# ---------------------------------------------------------------
step_vscode() {
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
  sudo dnf install -y code
}
run_step "vscode" step_vscode

# ---------------------------------------------------------------
# PostgreSQL (repo do Fedora)
# ---------------------------------------------------------------
step_postgresql() {
  sudo dnf install -y postgresql-server postgresql-contrib
  if [ ! -f /var/lib/pgsql/data/PG_VERSION ]; then
    sudo postgresql-setup --initdb
  fi
  sudo systemctl enable --now postgresql
}
run_step "postgresql" step_postgresql

# ---------------------------------------------------------------
# Docker (repo oficial Docker CE, com fallback pro moby-engine do Fedora)
# ---------------------------------------------------------------
step_docker() {
  if sudo dnf config-manager addrepo \
       --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo --overwrite \
     && sudo dnf install -y docker-ce docker-ce-cli containerd.io \
          docker-buildx-plugin docker-compose-plugin; then
    echo "Docker CE instalado."
  else
    echo "Repo do Docker CE ainda não suporta essa versão do Fedora, usando moby-engine."
    sudo dnf install -y moby-engine docker-compose
  fi
  sudo systemctl enable --now docker
  sudo usermod -aG docker "$USER"
}
run_step "docker" step_docker

# ---------------------------------------------------------------
# Discord e Spotify (Flatpak)
# ---------------------------------------------------------------
step_flatpak_apps() {
  flatpak install -y flathub com.discordapp.Discord com.spotify.Client
}
run_step "flatpak-apps" step_flatpak_apps

log "Pronto! Faça logout/login (ou reinicie) pra aplicar o grupo docker."
