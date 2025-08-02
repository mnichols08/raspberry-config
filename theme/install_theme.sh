#!/bin/bash

# Interactive Theme Installation Script
# This script allows users to select background images and wallpaper modes
# Usage: ./install_theme.sh [--non-interactive|-y]


# Check for non-interactive mode
NON_INTERACTIVE=false

# Set the display environment variable
# This is necessary for GUI applications to run correctly
export DISPLAY=:0

if [[ "$1" == "--non-interactive" ]] || [[ "$1" == "-y" ]]; then
    NON_INTERACTIVE=true
    echo "=== Raspberry Pi Theme Installation (Non-Interactive Mode) ==="
else
    echo "=== Raspberry Pi Theme Installation ==="
fi
echo

# Function to display available wallpaper modes
show_wallpaper_modes() {
    echo "Available wallpaper modes:"
    echo "1) center    - Center the image"
    echo "2) tile      - Tile the image"
    echo "3) stretch   - Stretch to fit screen"
    echo "4) fit       - Fit to screen (maintain aspect ratio)"
    echo "5) fill      - Fill screen (may crop image)"
    echo "6) zoom      - Zoom to fit"
}

# Function to get wallpaper mode selection
get_wallpaper_mode() {
    local mode_choice
    while true; do
        show_wallpaper_modes
        echo
        read -p "Select wallpaper mode (1-6): " mode_choice
        
        case $mode_choice in
            1) echo "center"; break ;;
            2) echo "tile"; break ;;
            3) echo "stretch"; break ;;
            4) echo "fit"; break ;;
            5) echo "fill"; break ;;
            6) echo "zoom"; break ;;
            *) echo "Invalid selection. Please choose 1-6." ;;
        esac
    done
}

# Function to get video selection
get_video_selection() {
    local video_files=("$@")
    local video_choice
    
    echo "Available startup videos:"
    for i in "${!video_files[@]}"; do
        filename=$(basename "${video_files[$i]}")
        echo "$((i+1))) $filename"
    done
    
    while true; do
        echo
        read -p "Select a video (1-${#video_files[@]}): " video_choice
        
        if [[ $video_choice =~ ^[0-9]+$ ]] && [ $video_choice -ge 1 ] && [ $video_choice -le ${#video_files[@]} ]; then
            echo "${video_files[$((video_choice-1))]}"
            break
        else
            echo "Invalid selection. Please choose a number between 1 and ${#video_files[@]}."
        fi
    done
}

# Check if background images directory exists
BACKGROUND_SOURCE="/var/tmp/raspberry-config/theme/background"
BACKGROUND_DEST="/usr/share/background"

# Video configuration
VIDEO_SOURCE="/var/tmp/raspberry-config/theme/background"
VIDEO_DEST="/usr/share/openautopro"
SERVICE_SOURCE="/var/tmp/raspberry-config/theme/openautopro.splash.service"
SERVICE_DEST="/etc/systemd/system/openautopro.splash.service"

if [ ! -d "$BACKGROUND_SOURCE" ]; then
    echo "Error: Background source directory not found at $BACKGROUND_SOURCE"
    echo "Please ensure the raspberry-config repository is properly extracted to /var/tmp/"
    
    if [ "$NON_INTERACTIVE" = true ]; then
        echo "Non-interactive mode: Cannot proceed without source directory. Exiting."
        exit 1
    fi
    
    read -p "Would you like to clone the raspberry-config repository now? (y/n): " clone_choice
    if [[ $clone_choice =~ ^[Yy]$ ]]; then
        echo "Cloning raspberry-config repository..."
        sudo rm -rf /var/tmp/raspberry-config 2>/dev/null
        if git clone https://github.com/mnichols08/raspberry-config.git /var/tmp/raspberry-config; then
            echo "Repository cloned successfully!"
            echo "Please run this script again."
            exit 0
        else
            echo "Failed to clone repository. Please check your internet connection and try again."
            exit 1
        fi
    else
        echo "Please manually clone the repository to /var/tmp/raspberry-config and run this script again."
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
    # Interactive mode: get wallpaper mode selection
    echo
    selected_mode=$(get_wallpaper_mode)
fi

# Set the wallpaper
echo
echo "Setting wallpaper..."
echo "Image: $(basename "$selected_image")"
echo "Mode: $selected_mode"

if pcmanfm --set-wallpaper="$selected_image" --wallpaper-mode="$selected_mode"; then
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
        # Interactive mode: get video selection
        echo
        selected_video=$(get_video_selection "${VIDEO_FILES[@]}")
    fi
    
    # Update the service file with selected video
    echo "Updating OpenAuto Pro splash service configuration..."
    echo "Selected video: $(basename "$selected_video")"
    
    # Create a temporary service file with the selected video
    temp_service="/tmp/openautopro.splash.service"
    cp "$SERVICE_SOURCE" "$temp_service"
    
    # Update the video path in the service file
    sed -i "s|Environment=\"OPENAUTO_SPLASH_VIDEOS=.*\"|Environment=\"OPENAUTO_SPLASH_VIDEOS=$selected_video\"|" "$temp_service"
    
    # Comment out any other video environment lines
    sed -i 's|^Environment="OPENAUTO_SPLASH_VIDEOS=|#Environment="OPENAUTO_SPLASH_VIDEOS=|' "$temp_service"
    sed -i "s|#Environment=\"OPENAUTO_SPLASH_VIDEOS=$selected_video\"|Environment=\"OPENAUTO_SPLASH_VIDEOS=$selected_video\"|" "$temp_service"
    
    # Copy the updated service file to the system location
    sudo cp "$temp_service" "$SERVICE_DEST"
    
    # Reload systemd and restart the service
    sudo systemctl daemon-reload
    sudo systemctl enable openautopro.splash.service
    
    echo "✓ Startup video configured successfully!"
    
    # Clean up temp file
    rm -f "$temp_service"
fi

echo
echo "Theme installation completed!"
echo "✓ Wallpaper configuration applied"
echo "✓ Startup video configuration applied"
echo
echo "Note: You may need to reboot for the startup video changes to take effect."