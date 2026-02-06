#!/bin/bash
# HexClock Wallpaper for Hyprland
# Usage: ./wallpaper.sh [--auto|--daemon|--text]

# Configuration
AUTO_UPDATE=false
DAEMON_MODE=false
TEXT_OVERLAY=false
TEMP_IMG="/tmp/hexclock_wallpaper.png"

# Text overlay settings
FONT="Adwaita-Mono"
POINTSIZE=90
TEXT_COLOR="white"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --auto|-a)
            AUTO_UPDATE=true
            ;;
        --daemon|-d)
            DAEMON_MODE=true
            ;;
        --text|-t)
            TEXT_OVERLAY=true
            ;;
        --help|-h)
            echo "Usage: $0 [--auto|--daemon|--text]"
            echo "  --auto, -a     : Run continuously, updating wallpaper every second"
            echo "  --daemon, -d   : Run as daemon (no output), auto-updates"
            echo "  --text, -t     : Show hex code as text overlay on wallpaper"
            exit 0
            ;;
    esac
done

# Get hex color from current time
get_hex_color() {
    echo "#$(date +%H%M%S)"
}

# Create wallpaper image with optional text
create_wallpaper() {
    local color="$1"
    
    if [ "$TEXT_OVERLAY" = true ]; then
        magick -size 1920x1080 "xc:$color" \
            -fill "$TEXT_COLOR" -font "$FONT" -gravity center \
            -pointsize "$POINTSIZE" \
            -annotate +0-20 "$color" \
            "$TEMP_IMG"
    else
        magick -size 1920x1080 "xc:$color" "$TEMP_IMG"
    fi
}

# Set wallpaper using swww
set_wallpaper() {
    local color="$1"
    
    create_wallpaper "$color"
    
    # Start swww daemon if not running
    if ! pgrep -x "swww-daemon" > /dev/null; then
        swww-daemon &
        sleep 1
    fi
    
    # Set wallpaper
    swww img "$TEMP_IMG" --transition-type none &
}

# Main execution
if [ "$AUTO_UPDATE" = true ] || [ "$DAEMON_MODE" = true ]; then
    # Check if already running
    CURRENT_PID=$$
    PARENT_PID=$PPID
    RUNNING_PIDS=$(pgrep -f "wallpaper.sh.*--daemon\|wallpaper.sh.*--auto" | grep -v "^${CURRENT_PID}$" | grep -v "^${PARENT_PID}$" | wc -l)
    
    if [ "$RUNNING_PIDS" -gt 0 ]; then
        [ "$DAEMON_MODE" = false ] && echo "Wallpaper script is already running!"
        exit 1
    fi
    
    # Run continuously
    while true; do
        HEX_COLOR=$(get_hex_color)
        [ "$DAEMON_MODE" = false ] && echo "Setting wallpaper: $HEX_COLOR"
        set_wallpaper "$HEX_COLOR"
        sleep 1
    done
else
    # Run once
    HEX_COLOR=$(get_hex_color)
    echo "Setting wallpaper: $HEX_COLOR"
    set_wallpaper "$HEX_COLOR"
fi
