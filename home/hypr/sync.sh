#!/usr/bin/env bash
# ==============================================================================
# Dotfiles Sync Script — run this whenever you want to save current state
# Updates package lists and pushes all tracked dotfile changes to GitHub.
# ==============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cfg() { /usr/bin/git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME" "$@"; }

echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}         Dotfiles Sync — Viscous Setup           ${NC}"
echo -e "${BLUE}=================================================${NC}"

# ── 1. Update package lists ───────────────────────────────────────────────────
echo -e "${BLUE}[*] Updating package lists...${NC}"
pacman -Qqen > "$HOME/.config/hypr/pkglist.txt"
pacman -Qqem > "$HOME/.config/hypr/aurlist.txt"
PKGCOUNT=$(wc -l < "$HOME/.config/hypr/pkglist.txt")
AURCOUNT=$(wc -l < "$HOME/.config/hypr/aurlist.txt")
echo -e "${GREEN}[+] $PKGCOUNT official packages, $AURCOUNT AUR packages saved.${NC}"

# ── 2. Stage changed tracked files ───────────────────────────────────────────
echo -e "${BLUE}[*] Staging changes...${NC}"
cfg add -u

# Also stage the package lists explicitly (in case they weren't tracked yet)
cfg add "$HOME/.config/hypr/pkglist.txt" "$HOME/.config/hypr/aurlist.txt" 2>/dev/null || true

# ── 3. Check if there's anything to commit ───────────────────────────────────
if cfg diff --cached --quiet; then
    echo -e "${YELLOW}[!] Nothing changed. Already up to date.${NC}"
else
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
    cfg commit -m "[sync] $TIMESTAMP — pkg:$PKGCOUNT aur:$AURCOUNT"
    echo -e "${GREEN}[+] Committed.${NC}"

    # ── 4. Push ───────────────────────────────────────────────────────────────
    echo -e "${BLUE}[*] Pushing to GitHub...${NC}"
    cfg push
    echo -e "${GREEN}[+] Pushed to origin/main.${NC}"
fi

echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}[DONE] Dotfiles are up to date on GitHub.${NC}"
echo -e "${BLUE}=================================================${NC}"
