#!/usr/bin/env bash
# Setup pós-instalação: Fedora KDE
# Apps: Chrome, Discord, VS Code, PostgreSQL, Docker, Git, Spotify
# Uso: chmod +x setup-fedora.sh && ./setup-fedora.sh

set -euo pipefail

if [ "$EUID" -eq 0 ]; then
  echo "Não rode como root. Rode como usuário normal que o script usa sudo quando precisar."
  exit 1
fi

log() { echo -e "\n\033[1;34m==> $*\033[0m"; }

# ---------------------------------------------------------------
# Idioma e fuso horário
# ---------------------------------------------------------------
log "Configurando idioma (en_US.UTF-8) e fuso horário (America/Cuiaba)"
sudo localectl set-locale LANG=en_US.UTF-8
sudo timedatectl set-timezone America/Cuiaba

# ---------------------------------------------------------------
# Base: atualização + RPM Fusion + Flathub
# ---------------------------------------------------------------
log "Atualizando o sistema"
sudo dnf upgrade -y --refresh

log "Habilitando RPM Fusion (free + nonfree)"
sudo dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" \
  || echo "RPM Fusion já instalado ou indisponível pra essa versão, seguindo."

log "Garantindo o Flathub"
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

log "Instalando dnf-plugins-core"
sudo dnf install -y dnf-plugins-core

log "Instalando codecs multimídia (via RPM Fusion)"
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
sudo dnf groupupdate -y multimedia sound-and-video

log "Instalando driver NVIDIA (akmod-nvidia, via RPM Fusion)"
sudo dnf install -y akmod-nvidia

# ---------------------------------------------------------------
# Git
# ---------------------------------------------------------------
log "Instalando Git"
sudo dnf install -y git

# ---------------------------------------------------------------
# Google Chrome (o .rpm oficial já adiciona o repo pra atualizar depois)
# ---------------------------------------------------------------
log "Instalando Google Chrome"
sudo dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm

# ---------------------------------------------------------------
# Visual Studio Code (repo da Microsoft)
# ---------------------------------------------------------------
log "Instalando Visual Studio Code"
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

# ---------------------------------------------------------------
# PostgreSQL (repo do Fedora)
# ---------------------------------------------------------------
log "Instalando PostgreSQL"
sudo dnf install -y postgresql-server postgresql-contrib
if [ ! -f /var/lib/pgsql/data/PG_VERSION ]; then
  sudo postgresql-setup --initdb
fi
sudo systemctl enable --now postgresql

# ---------------------------------------------------------------
# Docker (repo oficial Docker CE, com fallback pro moby-engine do Fedora)
# ---------------------------------------------------------------
log "Instalando Docker"
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

# ---------------------------------------------------------------
# Discord e Spotify (Flatpak)
# ---------------------------------------------------------------
log "Instalando Discord e Spotify (Flatpak)"
flatpak install -y flathub com.discordapp.Discord com.spotify.Client

# ---------------------------------------------------------------
log "Pronto! Faça logout/login (ou reinicie) pra aplicar o grupo docker."
