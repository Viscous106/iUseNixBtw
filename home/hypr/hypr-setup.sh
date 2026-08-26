#!/usr/bin/env bash
# ==============================================================================
# Arch Linux Automated Setup Script — Viscous Hyprland Environment
# Run this on a fresh Arch install (after base + network setup).
# It will install all packages, restore your dotfiles, set up your shell,
# and enable all required system services in one go.
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DOTFILES_REPO="git@github.com:Viscous106/i_use_arch_btw.git"

echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}    Viscous Arch Linux Automated Setup Script    ${NC}"
echo -e "${BLUE}=================================================${NC}"

# ── Step 0: Sanity checks ─────────────────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}[X] Do NOT run this script as root. Run it as your normal user.${NC}"
    exit 1
fi

# ── Step 1: Install an AUR helper (paru) ─────────────────────────────────────
echo -e "${BLUE}[*] Installing paru (AUR helper)...${NC}"
if ! command -v paru &>/dev/null; then
    sudo pacman -S --noconfirm --needed base-devel git
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    (cd /tmp/paru && makepkg -si --noconfirm)
    rm -rf /tmp/paru
    echo -e "${GREEN}[+] paru installed.${NC}"
else
    echo -e "${GREEN}[+] paru already installed. Skipping.${NC}"
fi

# ── Step 2: Restore Dotfiles (early — so pkglist.txt / aurlist.txt are available) ──
echo -e "${BLUE}[*] Restoring dotfiles from bare repo...${NC}"
if [ ! -d "$HOME/.dotfiles" ]; then
    git clone --bare "$DOTFILES_REPO" "$HOME/.dotfiles"
    # Back up any files that would conflict with checkout
    /usr/bin/git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME" checkout 2>&1 \
        | grep "^\s" | awk '{print $1}' \
        | xargs -I{} sh -c 'mkdir -p "$HOME/.dotfiles-backup/$(dirname "{}")" && mv "$HOME/{}" "$HOME/.dotfiles-backup/{}"' 2>/dev/null || true
    /usr/bin/git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME" checkout -f
    /usr/bin/git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME" config --local status.showUntrackedFiles no
    echo -e "${GREEN}[+] Dotfiles restored.${NC}"
else
    echo -e "${YELLOW}[!] ~/.dotfiles already exists. Pulling latest changes...${NC}"
    /usr/bin/git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME" pull
fi

PKGLIST="$HOME/.config/hypr/pkglist.txt"
AURLIST="$HOME/.config/hypr/aurlist.txt"

# ── Step 3: Install official repo packages ───────────────────────────────────
echo -e "${BLUE}[*] Installing official packages...${NC}"
if [ -f "$PKGLIST" ]; then
    echo -e "${BLUE}    Using saved package list ($PKGLIST)...${NC}"
    sudo pacman -S --noconfirm --needed - < "$PKGLIST" || {
        echo -e "${YELLOW}[!] Some packages may have failed (renamed/dropped). Continuing...${NC}"
        true
    }
else
    echo -e "${YELLOW}[!] pkglist.txt not found, installing minimal Hyprland set...${NC}"
    sudo pacman -S --noconfirm --needed \
        hyprland hyprlock hypridle hyprpicker \
        xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
        waybar \
        swaynotificationcenter \
        wl-clipboard cliphist \
        swappy grim slurp \
        rofi-wayland \
        nwg-displays nwg-look \
        kitty tmux zsh \
        lsd fastfetch bat btop ripgrep fd fzf zoxide \
        pavucontrol pamixer playerctl \
        blueman bluez bluez-utils \
        networkmanager network-manager-applet \
        brightnessctl mpv ffmpeg \
        qt5ct qt6ct kvantum gtk3 \
        git github-cli gnupg pinentry \
        go nodejs python python-pip rustup \
        docker \
        thunar gvfs tumbler thunar-archive-plugin thunar-volman \
        pipewire wireplumber pipewire-pulse pipewire-alsa \
        polkit-kde-agent xdg-user-dirs \
        imagemagick inotify-tools socat jq libnotify
fi
echo -e "${GREEN}[+] Official packages installed.${NC}"

# ── Step 4: Install AUR packages ─────────────────────────────────────────────
echo -e "${BLUE}[*] Installing AUR packages...${NC}"
if [ -f "$AURLIST" ]; then
    echo -e "${BLUE}    Using saved AUR list ($AURLIST)...${NC}"
    paru -S --noconfirm --needed - < "$AURLIST" || {
        echo -e "${YELLOW}[!] Some AUR packages may have failed. Continuing...${NC}"
        true
    }
else
    echo -e "${YELLOW}[!] aurlist.txt not found, installing minimal AUR set...${NC}"
    paru -S --noconfirm --needed \
        swaylock-effects zen-browser-bin wallust \
        oh-my-zsh-git zsh-theme-powerlevel10k-git \
        wlogout swww wl-kbptr
fi
echo -e "${GREEN}[+] AUR packages installed.${NC}"

# ── Step 5: Set Zsh as default shell ─────────────────────────────────────────
echo -e "${BLUE}[*] Setting Zsh as default shell...${NC}"
if [ "$SHELL" != "/usr/bin/zsh" ]; then
    chsh -s /usr/bin/zsh "$USER"
    echo -e "${GREEN}[+] Default shell changed to Zsh. Will apply on next login.${NC}"
else
    echo -e "${GREEN}[+] Zsh is already the default shell.${NC}"
fi

# ── Step 6: Install TPM (Tmux Plugin Manager) ────────────────────────────────
echo -e "${BLUE}[*] Installing TPM...${NC}"
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    echo -e "${GREEN}[+] TPM installed. Run 'prefix + I' inside tmux to install plugins.${NC}"
else
    echo -e "${GREEN}[+] TPM already installed.${NC}"
fi

# ── Step 7: Rustup default toolchain ─────────────────────────────────────────
echo -e "${BLUE}[*] Setting up Rust toolchain...${NC}"
rustup default stable 2>/dev/null || true

# ── Step 8: Enable system services ───────────────────────────────────────────
echo -e "${BLUE}[*] Enabling system services...${NC}"
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now docker.service
sudo systemctl enable --now asusd.service 2>/dev/null || true   # ASUS ROG only
echo -e "${GREEN}[+] Services enabled.${NC}"

# ── Step 9: User systemd services ────────────────────────────────────────────
echo -e "${BLUE}[*] Enabling user systemd services...${NC}"
systemctl --user enable --now pipewire.service pipewire-pulse.socket wireplumber.service 2>/dev/null || true
systemctl --user enable --now rclone-drive.service 2>/dev/null || true
systemctl --user enable --now tmux.service 2>/dev/null || true
systemctl --user enable --now battery-notify.timer 2>/dev/null || true

# ── Step 10: Add user to required groups ─────────────────────────────────────
echo -e "${BLUE}[*] Adding $USER to required groups...${NC}"
sudo usermod -aG wheel,video,audio,input,storage,plugdev,docker,networkmanager "$USER"
echo -e "${GREEN}[+] Groups updated. Re-login required for group changes to take effect.${NC}"

# ── Step 11: XDG user directories ────────────────────────────────────────────
xdg-user-dirs-update

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}[SUCCESS] Arch Linux environment setup complete!${NC}"
echo -e "${BLUE}=================================================${NC}"
echo -e "${YELLOW}Next Steps (do these manually):${NC}"
echo -e "1. ${YELLOW}Reboot${NC} to apply all driver, shell, and group changes."
echo -e "2. Start Hyprland from TTY: ${YELLOW}Hyprland${NC}"
echo -e "3. Inside tmux, press ${YELLOW}prefix + I${NC} to install tmux plugins."
echo -e "4. Launch nvim once — Lazy.nvim will auto-bootstrap plugins."
echo -e "5. Run ${YELLOW}p10k configure${NC} if prompt isn't set up yet."
echo -e "${BLUE}=================================================${NC}"
