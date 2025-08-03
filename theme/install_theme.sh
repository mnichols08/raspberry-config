#!/bin/bash

# Interactive Theme Installation Script
# This script allows users to select background images and wallpaper modes
# Usage: ./install_theme.sh [--non-interactive|-y] [--config|-c CONFIG_FILE]


# Default values
NON_INTERACTIVE=false
CONFIG_FILE=""
BASE_DIR="/var/tmp/raspberry-config"

# Set the display environment variable
# This is necessary for GUI applications to run correctly
# Check if DISPLAY is already set, otherwise default to :0
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:0
fi

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --non-interactive, -y     Run in non-interactive mode"
    echo "  --config, -c CONFIG_FILE  Use specified configuration file"
    echo "  --help, -h               Show this help message"
    echo
    echo "Example:"
    echo "  $0 --config /path/to/pi-config.conf --non-interactive"
}

# Function to parse configuration file
parse_config_file() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        echo "Error: Configuration file not found: $config_file"
        exit 1
    fi
    
    echo "Reading configuration from: $config_file"
    
    # Parse temp_dir from config file
    local temp_dir_value
    temp_dir_value=$(grep -E "^[[:space:]]*temp_dir[[:space:]]*=" "$config_file" | head -1 | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"//;s/"$//')
    
    if [ -n "$temp_dir_value" ]; then
        BASE_DIR="$temp_dir_value"
        echo "Using temp_dir from config: $BASE_DIR"
    else
        echo "Warning: temp_dir not found in config file, using default: $BASE_DIR"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --non-interactive|-y)
            NON_INTERACTIVE=true
            shift
            ;;
        --config|-c)
            CONFIG_FILE="$2"
            if [ -z "$CONFIG_FILE" ]; then
                echo "Error: --config requires a configuration file path"
                show_usage
                exit 1
            fi
            shift 2
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            show_usage
            exit 1
            ;;
    esac
done

# Parse configuration file if provided
if [ -n "$CONFIG_FILE" ]; then
    parse_config_file "$CONFIG_FILE"
fi

if [ "$NON_INTERACTIVE" = true ]; then
    echo "=== Raspberry Pi Theme Installation (Non-Interactive Mode) ==="
else
    echo "=== Raspberry Pi Theme Installation ==="
fi
echo

# Function to configure compositing manager
configure_compositing() {
    local effects_level="$1"
    
    echo "Configuring desktop compositing..."
    
    # Check if compton/picom is available
    local compositor=""
    if command -v picom &> /dev/null; then
        compositor="picom"
    elif command -v compton &> /dev/null; then
        compositor="compton"
    else
        echo "Installing picom compositor..."
        sudo apt update && sudo apt install -y picom
        compositor="picom"
    fi
    
    # Create compositor config directory
    mkdir -p "$HOME/.config/picom"
    
    case $effects_level in
        "none")
            configure_no_effects
            ;;
        "minimal")
            configure_minimal_effects "$compositor"
            ;;
        "standard")
            configure_standard_effects "$compositor"
            ;;
        "enhanced")
            configure_enhanced_effects "$compositor"
            ;;
        "custom")
            configure_custom_effects "$compositor"
            ;;
    esac
}

# Function to disable all effects
configure_no_effects() {
    echo "Disabling desktop compositing..."
    
    # Stop any running compositor
    pkill -f "picom\|compton" 2>/dev/null || true
    
    # Remove autostart entries
    local autostart_dir="$HOME/.config/autostart"
    mkdir -p "$autostart_dir"
    rm -f "$autostart_dir/picom.desktop" "$autostart_dir/compton.desktop"
    
    echo "✓ Desktop effects disabled"
}

# Function to configure minimal effects
configure_minimal_effects() {
    local compositor="$1"
    
    cat > "$HOME/.config/picom/picom.conf" << 'EOF'
# Minimal Desktop Effects Configuration
# Basic window animations only

# Backend
backend = "glx";
glx-no-stencil = true;
glx-copy-from-front = false;

# Shadows (disabled for performance)
shadow = false;

# Opacity (minimal)
inactive-opacity = 1.0;
active-opacity = 1.0;
frame-opacity = 1.0;
inactive-opacity-override = false;

# Fading
fading = true;
fade-delta = 4;
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-exclude = [];

# Window type settings
wintypes:
{
    tooltip = { fade = true; shadow = false; opacity = 0.95; focus = true; };
    dock = { shadow = false; };
    dnd = { shadow = false; };
    popup_menu = { opacity = 0.95; };
    dropdown_menu = { opacity = 0.95; };
};

# Performance optimizations
vsync = true;
mark-wmwin-focused = true;
mark-ovredir-focused = true;
detect-rounded-corners = true;
detect-client-opacity = true;
refresh-rate = 0;
detect-transient = true;
detect-client-leader = true;
EOF
    
    create_compositor_autostart "$compositor"
    start_compositor "$compositor"
    echo "✓ Minimal desktop effects configured"
}

# Function to configure standard effects
configure_standard_effects() {
    local compositor="$1"
    
    cat > "$HOME/.config/picom/picom.conf" << 'EOF'
# Standard Desktop Effects Configuration
# Window animations + basic transparency

# Backend
backend = "glx";
glx-no-stencil = true;
glx-copy-from-front = false;

# Shadows
shadow = true;
shadow-radius = 8;
shadow-offset-x = -8;
shadow-offset-y = -8;
shadow-opacity = 0.3;
shadow-exclude = [
    "name = 'Notification'",
    "class_g = 'Conky'",
    "class_g ?= 'Notify-osd'",
    "class_g = 'Cairo-clock'",
    "_GTK_FRAME_EXTENTS@:c"
];

# Opacity
inactive-opacity = 0.9;
active-opacity = 1.0;
frame-opacity = 0.9;
inactive-opacity-override = false;

# Opacity rules
opacity-rule = [
    "90:class_g = 'LXTerminal'",
    "95:class_g = 'PCManFM'",
    "100:class_g = 'firefox'",
    "100:class_g = 'chromium'"
];

# Fading
fading = true;
fade-delta = 5;
fade-in-step = 0.05;
fade-out-step = 0.05;

# Window type settings
wintypes:
{
    tooltip = { fade = true; shadow = true; opacity = 0.95; focus = true; };
    dock = { shadow = false; };
    dnd = { shadow = false; };
    popup_menu = { opacity = 0.95; shadow = true; };
    dropdown_menu = { opacity = 0.95; shadow = true; };
};

# Performance settings
vsync = true;
mark-wmwin-focused = true;
mark-ovredir-focused = true;
detect-rounded-corners = true;
detect-client-opacity = true;
refresh-rate = 0;
detect-transient = true;
detect-client-leader = true;
EOF
    
    create_compositor_autostart "$compositor"
    start_compositor "$compositor"
    echo "✓ Standard desktop effects configured"
}

# Function to configure enhanced effects
configure_enhanced_effects() {
    local compositor="$1"
    
    cat > "$HOME/.config/picom/picom.conf" << 'EOF'
# Enhanced Desktop Effects Configuration
# Full effects with shadows, blur, and animations

# Backend
backend = "glx";
glx-no-stencil = true;
glx-copy-from-front = false;

# Shadows
shadow = true;
shadow-radius = 12;
shadow-offset-x = -10;
shadow-offset-y = -10;
shadow-opacity = 0.4;
shadow-exclude = [
    "name = 'Notification'",
    "class_g = 'Conky'",
    "class_g ?= 'Notify-osd'",
    "class_g = 'Cairo-clock'",
    "_GTK_FRAME_EXTENTS@:c"
];

# Blur
blur-background = true;
blur-background-frame = true;
blur-method = "dual_kawase";
blur-strength = 3;
blur-background-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'",
    "_GTK_FRAME_EXTENTS@:c"
];

# Opacity
inactive-opacity = 0.85;
active-opacity = 1.0;
frame-opacity = 0.8;
inactive-opacity-override = false;

# Opacity rules
opacity-rule = [
    "85:class_g = 'LXTerminal'",
    "90:class_g = 'PCManFM'",
    "100:class_g = 'firefox'",
    "100:class_g = 'chromium'",
    "80:class_g = 'lxpanel'",
    "95:class_g = 'Menu'"
];

# Fading
fading = true;
fade-delta = 7;
fade-in-step = 0.07;
fade-out-step = 0.07;

# Corners (if supported)
corner-radius = 8;
rounded-corners-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'"
];

# Window type settings
wintypes:
{
    tooltip = { fade = true; shadow = true; opacity = 0.95; focus = true; full-shadow = false; };
    dock = { shadow = false; clip-shadow-above = true; };
    dnd = { shadow = false; };
    popup_menu = { opacity = 0.9; shadow = true; blur-background = false; };
    dropdown_menu = { opacity = 0.9; shadow = true; blur-background = false; };
};

# Performance settings
vsync = true;
mark-wmwin-focused = true;
mark-ovredir-focused = true;
detect-rounded-corners = true;
detect-client-opacity = true;
refresh-rate = 60;
detect-transient = true;
detect-client-leader = true;
EOF
    
    create_compositor_autostart "$compositor"
    start_compositor "$compositor"
    echo "✓ Enhanced desktop effects configured"
}

# Function to configure custom effects
configure_custom_effects() {
    local compositor="$1"
    
    echo "Custom effects configuration:"
    echo
    
    # Get user preferences for each effect
    read -p "Enable window shadows? (y/n): " enable_shadows
    read -p "Enable window transparency? (y/n): " enable_transparency
    read -p "Enable window blur? (y/n): " enable_blur
    read -p "Enable fading animations? (y/n): " enable_fading
    read -p "Enable rounded corners? (y/n): " enable_corners
    
    # Shadow settings
    local shadow_config=""
    if [[ $enable_shadows =~ ^[Yy]$ ]]; then
        echo
        read -p "Shadow radius (1-20, default 10): " shadow_radius
        read -p "Shadow opacity (0.1-1.0, default 0.3): " shadow_opacity
        shadow_radius=${shadow_radius:-10}
        shadow_opacity=${shadow_opacity:-0.3}
        
        shadow_config="shadow = true;
shadow-radius = ${shadow_radius};
shadow-offset-x = -${shadow_radius};
shadow-offset-y = -${shadow_radius};
shadow-opacity = ${shadow_opacity};"
    else
        shadow_config="shadow = false;"
    fi
    
    # Transparency settings
    local opacity_config=""
    if [[ $enable_transparency =~ ^[Yy]$ ]]; then
        echo
        read -p "Inactive window opacity (0.1-1.0, default 0.9): " inactive_opacity
        inactive_opacity=${inactive_opacity:-0.9}
        
        opacity_config="inactive-opacity = ${inactive_opacity};
active-opacity = 1.0;
frame-opacity = 0.9;"
    else
        opacity_config="inactive-opacity = 1.0;
active-opacity = 1.0;
frame-opacity = 1.0;"
    fi
    
    # Blur settings
    local blur_config=""
    if [[ $enable_blur =~ ^[Yy]$ ]]; then
        echo
        read -p "Blur strength (1-10, default 3): " blur_strength
        blur_strength=${blur_strength:-3}
        
        blur_config="blur-background = true;
blur-background-frame = true;
blur-method = \"dual_kawase\";
blur-strength = ${blur_strength};"
    else
        blur_config="blur-background = false;"
    fi
    
    # Fading settings
    local fading_config=""
    if [[ $enable_fading =~ ^[Yy]$ ]]; then
        echo
        read -p "Fade speed (1-10, default 5): " fade_speed
        fade_speed=${fade_speed:-5}
        
        fading_config="fading = true;
fade-delta = ${fade_speed};
fade-in-step = 0.0$(printf "%02d" $((fade_speed * 10)));
fade-out-step = 0.0$(printf "%02d" $((fade_speed * 10)));"
    else
        fading_config="fading = false;"
    fi
    
    # Corner settings
    local corner_config=""
    if [[ $enable_corners =~ ^[Yy]$ ]]; then
        echo
        read -p "Corner radius (1-20, default 8): " corner_radius
        corner_radius=${corner_radius:-8}
        
        corner_config="corner-radius = ${corner_radius};
rounded-corners-exclude = [
    \"window_type = 'dock'\",
    \"window_type = 'desktop'\"
];"
    fi
    
    # Generate custom config file
    cat > "$HOME/.config/picom/picom.conf" << EOF
# Custom Desktop Effects Configuration

# Backend
backend = "glx";
glx-no-stencil = true;
glx-copy-from-front = false;

# Shadows
${shadow_config}

# Opacity
${opacity_config}

# Blur
${blur_config}

# Fading
${fading_config}

# Corners
${corner_config}

# Window type settings
wintypes:
{
    tooltip = { fade = true; shadow = false; opacity = 0.95; focus = true; };
    dock = { shadow = false; };
    dnd = { shadow = false; };
    popup_menu = { opacity = 0.95; };
    dropdown_menu = { opacity = 0.95; };
};

# Performance settings
vsync = true;
mark-wmwin-focused = true;
mark-ovredir-focused = true;
detect-rounded-corners = true;
detect-client-opacity = true;
refresh-rate = 0;
detect-transient = true;
detect-client-leader = true;
EOF
    
    create_compositor_autostart "$compositor"
    start_compositor "$compositor"
    echo "✓ Custom desktop effects configured"
}

# Function to create compositor autostart entry
create_compositor_autostart() {
    local compositor="$1"
    local autostart_dir="$HOME/.config/autostart"
    
    mkdir -p "$autostart_dir"
    
    cat > "$autostart_dir/picom.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Picom Compositor
Comment=Desktop compositing manager
Exec=env DISPLAY=:0 ${compositor} --config ~/.config/picom/picom.conf
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
    
    echo "✓ Compositor autostart configured"
}

# Function to start compositor
start_compositor() {
    local compositor="$1"
    
    # Stop any running compositor first
    pkill -f "picom\|compton" 2>/dev/null || true
    sleep 1
    
    # Ensure DISPLAY is set for GUI applications
    export DISPLAY=:0
    
    # Start new compositor in background
    DISPLAY=:0 "$compositor" --config "$HOME/.config/picom/picom.conf" --daemon
    
    echo "✓ Compositor started"
}

# Check if background images directory exists
BACKGROUND_SOURCE="$BASE_DIR/theme/background"
BACKGROUND_DEST="/usr/share/background"

# Video configuration
VIDEO_SOURCE="$BASE_DIR/theme/videos"
VIDEO_DEST="/usr/share/openautopro"
SERVICE_SOURCE="$BASE_DIR/theme/openautopro.splash.service"
SERVICE_DEST="/etc/systemd/system/openautopro.splash.service"

if [ ! -d "$BACKGROUND_SOURCE" ]; then
    echo "Error: Background source directory not found at $BACKGROUND_SOURCE"
    echo "Please ensure the raspberry-config repository is properly extracted to $BASE_DIR/"
    
    if [ "$NON_INTERACTIVE" = true ]; then
        echo "Non-interactive mode: Cannot proceed without source directory. Exiting."
        exit 1
    fi
    
    read -p "Would you like to clone the raspberry-config repository now? (y/n): " clone_choice
    if [[ $clone_choice =~ ^[Yy]$ ]]; then
        echo "Cloning raspberry-config repository..."
        sudo rm -rf "$BASE_DIR" 2>/dev/null
        if git clone https://github.com/mnichols08/raspberry-config.git "$BASE_DIR"; then
            echo "Repository cloned successfully!"
            echo "Please run this script again."
            exit 0
        else
            echo "Failed to clone repository. Please check your internet connection and try again."
            exit 1
        fi
    else
        echo "Please manually clone the repository to $BASE_DIR and run this script again."
    fi
    exit 1
fi

# Create destination directory if it doesn't exist
echo "Creating background directory..."
sudo mkdir -p "$BACKGROUND_DEST"

# Copy background files
echo "Copying background files..."
sudo cp -r "$BACKGROUND_SOURCE"/* "$BACKGROUND_DEST/"

# Find available image files (common image formats)
echo "Scanning for available background images..."
IMAGE_FILES=($(find "$BACKGROUND_DEST" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" -o -iname "*.gif" \) 2>/dev/null))

if [ ${#IMAGE_FILES[@]} -eq 0 ]; then
    echo "No image files found in the background directory."
    echo "Available files:"
    ls -la "$BACKGROUND_DEST"
    echo
    echo "Note: pcmanfm supports jpg, jpeg, png, bmp, and gif formats."
    
    if [ "$NON_INTERACTIVE" = true ]; then
        echo "Non-interactive mode: No image files found. Exiting."
        exit 1
    fi
    
    # Ask if user wants to manually specify a file
    read -p "Would you like to manually specify an image file path? (y/n): " manual_choice
    if [[ $manual_choice =~ ^[Yy]$ ]]; then
        read -p "Enter the full path to your image file: " manual_image
        if [ -f "$manual_image" ]; then
            IMAGE_FILES=("$manual_image")
        else
            echo "File not found: $manual_image"
            exit 1
        fi
    else
        echo "Exiting without setting wallpaper."
        exit 0
    fi
fi

# Handle image selection based on mode
if [ "$NON_INTERACTIVE" = true ]; then
    # Non-interactive mode: select first image
    selected_image="${IMAGE_FILES[0]}"
    echo "Auto-selected image: $(basename "$selected_image")"
else
    # Interactive mode: display available images
    echo
    echo "Available background images:"
    for i in "${!IMAGE_FILES[@]}"; do
        filename=$(basename "${IMAGE_FILES[$i]}")
        echo "$((i+1))) $filename"
    done

    # Get user's image selection
    while true; do
        echo
        read -p "Select an image (1-${#IMAGE_FILES[@]}): " img_choice
        
        if [[ $img_choice =~ ^[0-9]+$ ]] && [ $img_choice -ge 1 ] && [ $img_choice -le ${#IMAGE_FILES[@]} ]; then
            selected_image="${IMAGE_FILES[$((img_choice-1))]}"
            break
        else
            echo "Invalid selection. Please choose a number between 1 and ${#IMAGE_FILES[@]}."
        fi
    done
fi

# Handle wallpaper mode selection based on mode
if [ "$NON_INTERACTIVE" = true ]; then
    # Non-interactive mode: use default stretch mode
    selected_mode="stretch"
    echo "Auto-selected wallpaper mode: $selected_mode"
else
    # Interactive mode: display wallpaper mode choices and get selection
    echo
    echo "Available wallpaper modes:"
    echo "1) center    - Center the image"
    echo "2) tile      - Tile the image"
    echo "3) stretch   - Stretch to fit screen"
    echo "4) fit       - Fit to screen (maintain aspect ratio)"
    echo "5) fill      - Fill screen (may crop image)"
    echo "6) zoom      - Zoom to fit"
    
    # Get user's mode selection
    while true; do
        echo
        read -p "Select wallpaper mode (1-6): " mode_choice
        
        case $mode_choice in
            1) selected_mode="center"; break ;;
            2) selected_mode="tile"; break ;;
            3) selected_mode="stretch"; break ;;
            4) selected_mode="fit"; break ;;
            5) selected_mode="fill"; break ;;
            6) selected_mode="zoom"; break ;;
            *) echo "Invalid selection. Please choose 1-6." ;;
        esac
    done
fi

# Set the wallpaper
echo
echo "Setting wallpaper..."
echo "Image: $(basename "$selected_image")"
echo "Mode: $selected_mode"

# Ensure DISPLAY is set for GUI applications
export DISPLAY=:0

if DISPLAY=:0 pcmanfm --set-wallpaper="$selected_image" --wallpaper-mode="$selected_mode"; then
    echo "✓ Wallpaper set successfully!"
else
    echo "✗ Failed to set wallpaper. Please check if pcmanfm is installed and the image file is valid."
    exit 1
fi

# Handle startup video configuration
echo
echo "Configuring startup video..."

# Create video destination directory if it doesn't exist
sudo mkdir -p "$VIDEO_DEST"

# Copy video files
echo "Copying video files..."
sudo cp -r "$VIDEO_SOURCE"/* "$VIDEO_DEST/"

# Find available video files (h264 format for splash screen)
echo "Scanning for available startup videos..."
VIDEO_FILES=($(find "$VIDEO_DEST" -type f -iname "*.h264" 2>/dev/null))

if [ ${#VIDEO_FILES[@]} -eq 0 ]; then
    echo "No h264 video files found in the video directory."
    echo "Available files:"
    ls -la "$VIDEO_DEST"
    echo
    echo "Note: OpenAuto Pro splash service supports h264 format videos."
    
    if [ "$NON_INTERACTIVE" = true ]; then
        echo "Non-interactive mode: No video files found. Skipping video configuration."
    else
        echo "Skipping video configuration due to no compatible files."
    fi
else
    # Handle video selection based on mode
    if [ "$NON_INTERACTIVE" = true ]; then
        # Non-interactive mode: select first video
        selected_video="${VIDEO_FILES[0]}"
        echo "Auto-selected video: $(basename "$selected_video")"
    else
        # Interactive mode: display video choices and get selection
        echo
        echo "Available startup videos:"
        for i in "${!VIDEO_FILES[@]}"; do
            filename=$(basename "${VIDEO_FILES[$i]}")
            echo "$((i+1))) $filename"
        done
        
        # Get user's video selection
        while true; do
            echo
            read -p "Select a video (1-${#VIDEO_FILES[@]}): " video_choice
            
            if [[ $video_choice =~ ^[0-9]+$ ]] && [ $video_choice -ge 1 ] && [ $video_choice -le ${#VIDEO_FILES[@]} ]; then
                selected_video="${VIDEO_FILES[$((video_choice-1))]}"
                break
            else
                echo "Invalid selection. Please choose a number between 1 and ${#VIDEO_FILES[@]}."
            fi
        done
    fi
    
    # Update the service file with selected video
    echo "Updating OpenAuto Pro splash service configuration..."
    echo "Selected video: $(basename "$selected_video")"
    
    # Create a temporary service file with the selected video
    temp_service="/tmp/openautopro.splash.service"
    cp "$SERVICE_SOURCE" "$temp_service"
    
    # Update the video path in the service file
    sed -i "s|Environment=\"OPENAUTO_SPLASH_VIDEOS=.*\"|Environment=\"OPENAUTO_SPLASH_VIDEOS=$selected_video\"|" "$temp_service"
    
    # Copy the updated service file to the system location
    sudo cp "$temp_service" "$SERVICE_DEST"
    
    # Reload systemd and restart the service
    sudo systemctl daemon-reload
    sudo systemctl enable openautopro.splash.service
    
    echo "✓ Startup video configured successfully!"
    
    # Clean up temp file
    rm -f "$temp_service"
fi

# Handle desktop effects configuration
echo
echo "Configuring desktop effects..."

# Handle desktop effects selection based on mode
if [ "$NON_INTERACTIVE" = true ]; then
    # Non-interactive mode: use minimal effects for best performance
    selected_effects="minimal"
    echo "Auto-selected desktop effects: $selected_effects"
else
    # Interactive mode: display effects choices and get selection
    echo
    echo "Available desktop effects:"
    echo "1) none      - Disable all effects (best performance)"
    echo "2) minimal   - Basic window animations only"
    echo "3) standard  - Window animations + transparency"
    echo "4) enhanced  - Full effects with shadows and blur"
    echo "5) custom    - Configure individual effects"
    
    # Get user's effects selection
    while true; do
        echo
        read -p "Select desktop effects level (1-5): " effects_choice
        
        case $effects_choice in
            1) selected_effects="none"; break ;;
            2) selected_effects="minimal"; break ;;
            3) selected_effects="standard"; break ;;
            4) selected_effects="enhanced"; break ;;
            5) selected_effects="custom"; break ;;
            *) echo "Invalid selection. Please choose 1-5." ;;
        esac
    done
fi

# Configure the selected effects
configure_compositing "$selected_effects"

echo
echo "Theme installation completed!"
echo "✓ Wallpaper configuration applied"
echo "✓ Startup video configuration applied"
echo "✓ Desktop effects configuration applied"
echo
echo "Note: You may need to reboot for the startup video changes to take effect."