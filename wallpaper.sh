#!/bin/bash
# HexClock Wallpaper for Hyprland
# Usage: ./wallpaper.sh [--auto|--daemon|--text]

TEXT_OVERLAY=false
AUTO_MODE=false
TEMP_IMG="/tmp/hexclock_wallpaper.png"

# Text overlay settings
FONT="Adwaita-Mono"
POINTSIZE=90
TEXT_COLOR="white"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --auto|-a|--daemon|-d)
            AUTO_MODE=true
            ;;
        --text|-t)
            TEXT_OVERLAY=true
            ;;
        --help|-h)
            echo "Usage: $0 [--auto|--daemon|--text]"
            echo "  --auto, -a  : Run continuously, updating every second"
            echo "  --daemon,-d : Run as daemon (same as --auto but no output)"
            echo "  --text, -t  : Show hex code as text overlay"
            exit 0
            ;;
    esac
done

# Create wallpaper image
create_wallpaper() {
    if [ "$TEXT_OVERLAY" = true ]; then
        magick -size 1920x1080 "xc:$1" -fill "$TEXT_COLOR" -font "$FONT" \
            -gravity center -pointsize "$POINTSIZE" -annotate +0-20 "$1" "$TEMP_IMG"
    else
        magick -size 1920x1080 "xc:$1" "$TEMP_IMG"
    fi
}

# Set wallpaper
set_wallpaper() {
    create_wallpaper "$1"
    pgrep -x "swww-daemon" > /dev/null || { swww-daemon & sleep 1; }
    swww img "$TEMP_IMG" --transition-type none &
}

# Main
if [ "$AUTO_MODE" = true ]; then
    # Check if already running
    if pgrep -f "wallpaper.sh" | grep -qv "^$$$"; then
        echo "Already running!" >&2
        exit 1
    fi
    
    while true; do
        COLOR="#$(date +%H%M%S)"
        set_wallpaper "$COLOR"
        sleep 1
    done
else
    COLOR="#$(date +%H%M%S)"
    echo "$COLOR"
    set_wallpaper "$COLOR"
fi
