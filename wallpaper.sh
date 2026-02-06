#!/bin/bash

# HexClock Wallpaper Script for Linux
# Sets wallpaper color based on current time (#HHMMSS)
# Usage: ./wallpaper.sh [--auto|--daemon]

# Configuration
AUTO_UPDATE=false
DAEMON_MODE=false
TEMP_IMG="/tmp/hexclock_wallpaper.png"
HYPR_CONFIG="$HOME/.config/hypr/hyprland.conf"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --auto|-a)
            AUTO_UPDATE=true
            ;;
        --daemon|-d)
            DAEMON_MODE=true
            ;;
        --help|-h)
            echo "Usage: $0 [--auto|--daemon]"
            echo "  --auto, -a     : Run continuously, updating wallpaper every second"
            echo "  --daemon, -d   : Run as daemon (no output), auto-updates"
            exit 0
            ;;
    esac
done

# Get current time components
get_hex_color() {
    local HOURS=$(date +%H)
    local MINUTES=$(date +%M)
    local SECONDS=$(date +%S)
    echo "#${HOURS}${MINUTES}${SECONDS}"
}

# Create wallpaper image
create_wallpaper() {
    local color="$1"
    
    # Use ImageMagick v7 syntax if available
    if command -v magick &> /dev/null; then
        magick -size 1920x1080 "xc:$color" "$TEMP_IMG" 2>/dev/null
    elif command -v convert &> /dev/null; then
        convert -size 1920x1080 "xc:$color" "$TEMP_IMG" 2>/dev/null
    elif command -v ffmpeg &> /dev/null; then
        ffmpeg -f lavfi -i "color=c=$color:s=1920x1080" -frames:v 1 -y "$TEMP_IMG" 2>/dev/null
    else
        echo "Error: Need ImageMagick or ffmpeg to create wallpaper"
        exit 1
    fi
}

# Detect desktop environment
detect_de() {
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        echo "$XDG_CURRENT_DESKTOP"
    elif [ -n "$DESKTOP_SESSION" ]; then
        echo "$DESKTOP_SESSION"
    else
        echo "unknown"
    fi
}

# Set wallpaper for Hyprland
set_hyprland_wallpaper() {
    local color="$1"
    
    # Create the wallpaper image
    create_wallpaper "$color"
    
    # Check if swww daemon is running, start if not
    if ! pgrep -x "swww-daemon" > /dev/null; then
        swww-daemon &
        sleep 1
    fi
    
    # Set wallpaper using swww (run in background to not block)
    swww img "$TEMP_IMG" --transition-type none &
    
    # Make persistent by updating hyprland config
    make_hyprland_persistent "$color"
}

# Make wallpaper persistent in hyprland config
make_hyprland_persistent() {
    local color="$1"
    
    # Check if we already added our exec-once line
    if ! grep -q "hexclock wallpaper" "$HYPR_CONFIG" 2>/dev/null; then
        echo "" >> "$HYPR_CONFIG"
        echo "# HexClock wallpaper - auto-generated" >> "$HYPR_CONFIG"
        echo "exec-once = swww-daemon" >> "$HYPR_CONFIG"
        echo "exec-once = sleep 1 && swww img $TEMP_IMG --transition-type none" >> "$HYPR_CONFIG"
    else
        # Update existing line
        sed -i "s|exec-once = sleep 1 && swww img .*|exec-once = sleep 1 && swww img $TEMP_IMG --transition-type none|" "$HYPR_CONFIG"
    fi
}

# Set wallpaper based on DE
set_wallpaper() {
    local HEX_COLOR=$(get_hex_color)
    local DE=$(detect_de)
    local DE_LOWER=$(echo "$DE" | tr '[:upper:]' '[:lower:]')
    
    [ "$DAEMON_MODE" = false ] && echo "Setting wallpaper color: $HEX_COLOR"
    
    case "$DE_LOWER" in
        *gnome*|*ubuntu*)
            gsettings set org.gnome.desktop.background primary-color "$HEX_COLOR"
            gsettings set org.gnome.desktop.background picture-uri ""
            gsettings set org.gnome.desktop.background picture-uri-dark ""
            ;;
        
        *kde*|*plasma*)
            if command -v qdbus &> /dev/null; then
                qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
                    var allDesktops = desktops();
                    for (i=0; i<allDesktops.length; i++) {
                        d = allDesktops[i];
                        d.wallpaperPlugin = 'org.kde.color';
                        d.currentConfigGroup = Array('Wallpaper', 'org.kde.color', 'General');
                        d.writeConfig('Color', '$HEX_COLOR');
                    }
                "
            elif command -v kwriteconfig5 &> /dev/null; then
                kwriteconfig5 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 1 --group Wallpaper --group org.kde.color --group General --key Color "$HEX_COLOR"
            fi
            ;;
        
        *xfce*)
            if command -v xfconf-query &> /dev/null; then
                xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/color-style -s 0
                xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/color1 -s "$HEX_COLOR"
                xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/image-style -s 0
            fi
            ;;
        
        *mate*)
            gsettings set org.mate.desktop.background primary-color "$HEX_COLOR"
            gsettings set org.mate.desktop.background picture-filename ""
            ;;
        
        *cinnamon*)
            gsettings set org.cinnamon.desktop.background primary-color "$HEX_COLOR"
            gsettings set org.cinnamon.desktop.background picture-uri ""
            ;;
        
        *hyprland*)
            set_hyprland_wallpaper "$HEX_COLOR"
            ;;
        
        *sway*)
            create_wallpaper "$HEX_COLOR"
            pkill swaybg 2>/dev/null
            swaybg -i "$TEMP_IMG" -m fill &
            ;;
        
        *i3*|*bspwm*|*dwm*|*awesome*|*xmonad*)
            create_wallpaper "$HEX_COLOR"
            if command -v feh &> /dev/null; then
                feh --bg-fill "$TEMP_IMG"
            elif command -v nitrogen &> /dev/null; then
                nitrogen --set-zoom-fill "$TEMP_IMG"
            elif command -v xsetroot &> /dev/null; then
                local HOURS=$(date +%H)
                local MINUTES=$(date +%M)
                local SECONDS=$(date +%S)
                xsetroot -solid "rgb:$HOURS/$MINUTES/$SECONDS"
            fi
            ;;
        
        *)
            [ "$DAEMON_MODE" = false ] && echo "Desktop environment '$DE' not specifically supported, trying fallback methods..."
            create_wallpaper "$HEX_COLOR"
            if command -v gsettings &> /dev/null; then
                gsettings set org.gnome.desktop.background primary-color "$HEX_COLOR" 2>/dev/null
            elif command -v feh &> /dev/null; then
                feh --bg-fill "$TEMP_IMG"
            elif command -v xsetroot &> /dev/null; then
                local HOURS=$(date +%H)
                local MINUTES=$(date +%M)
                local SECONDS=$(date +%S)
                xsetroot -solid "rgb:$HOURS/$MINUTES/$SECONDS"
            else
                echo "Could not set wallpaper. Please install feh, ImageMagick, or use a supported DE."
                exit 1
            fi
            ;;
    esac
    
    [ "$DAEMON_MODE" = false ] && echo "Wallpaper set to $HEX_COLOR"
}

# Main execution
if [ "$AUTO_UPDATE" = true ] || [ "$DAEMON_MODE" = true ]; then
    # Check if already running (exclude current process and its parent)
    CURRENT_PID=$$
    PARENT_PID=$PPID
    RUNNING_PIDS=$(pgrep -f "wallpaper.sh.*--daemon\|wallpaper.sh.*--auto" | grep -v "^${CURRENT_PID}$" | grep -v "^${PARENT_PID}$" | wc -l)
    if [ "$RUNNING_PIDS" -gt 0 ]; then
        if [ "$DAEMON_MODE" = false ]; then
            echo "Wallpaper script is already running!"
            exit 1
        fi
        exit 0
    fi
    
    # Run continuously
    while true; do
        set_wallpaper
        sleep 1
    done
else
    # Run once
    set_wallpaper
fi