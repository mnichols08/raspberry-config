# Fresh Installation of PiLink Open Auto Pro
# This is not a script, but a history of commands used to set up the system.
# This file is a record of commands executed during the setup process.
# It is intended for reference and should not be executed as a script.
# Commands are listed in the order they were run.
# Each command is prefixed with a comment for clarity.
# To view the history, you can use `cat my-history.sh`.
# Display the current date and time

# Set up the hostname
sudo hostnamectl set-hostname Sapphire

# Change the default password for the pi user
echo "pi:Sapphire" | sudo chpasswd

# Log into Local Wifi
#sudo iwconfig wlan0 essid "xxxxxxxff" key "fxfxfxfxfxfxfxfxfxfx"

# Set the display environment variable
# This is necessary for GUI applications to run correctly

# Wait for the network to connect
sleep 10
# Check the network connection
ifconfig wlan0
# Get the IP address if connection is established
ip_address=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
if [ -n "$ip_address" ]; then
    echo "Pi IP address: $ip_address"
else
    echo "No network connection found"
fi

# Createa a temporary directory for the installation files
mkdir temp_install
# Configure the custom template
# Download the custom images and videos
sudo rm /var/tmp/raspberry-config -rf
git clone https://github.com/mnichols08/raspberry-config.git temp_install # Still Needs to be created first
# Copy the custom videos to the Open Auto Pro directory
sudo cp  -r ./temp_install/raspberry-config/videos/* /usr/share/openautopro/
sudo cp -r ./temp_install/raspberry-config/images/background* /usr/share/background/
# set the background image to the custom image
pcmanfm --set-wallpaper="/usr/share/background/rix_background.jpg" --wallpaper-mode=stretch

# Install GeekWorm X735 Power Management Board
# Add the required overlays for the X735 board
sudo sed -i '/^\[all\]/a dtoverlay=pwm-2chan,pin2=13,func2=4' /boot/config.txt

# Install gpiod for the X735 board
sudo apt install -y gpiod
# Install the required Python packages
sudo apt-get install -y python3-rpi.gpio
# Create a tempory install directory and clone the X735 script repository
mkdir git clone https://github.com/geekworm-com/x735-script temp_install
# Give execute permissions to the install scripts
chmod +x ./temp_install/x735-script/*.sh
# Create the x735-fan service
sudo ./temp_install/x735-script/install-fan-service.sh
# Create the x735-pwr service
sudo ./temp_install/x735-script/install-pwr-service.sh
# Move the scripts to the local bin directory
sudo cp -f ./temp_install/x735-script/xSoft.sh /usr/local/bin/
# Create a symlink for the xSoft command
sudo ln -s /usr/local/bin/xSoft.sh /usr/local/bin/xSoft
# Create a new script to power the X735 board on the Raspberry Pi 4 default GPIO pin
sudo tee /usr/local/bin/x735off << 'EOF'
#!/bin/bash
xSoft 0 20
EOF
sudo chmod +x /usr/local/bin/x735off
# This script will turn off the X735 board when executed and can be used to safely power down the Raspberry Pi.

# Install GPSBerry
# Update software and OS
sudo apt update && sudo apt upgrade -y
# Install required packages
sudo apt-get install gpsd-clients gpsd -y
# Disable serial console but enable serial port hardware
sudo raspi-config nonint do_serial 2

# Reboot the system
echo "Rebooting the system to apply changes..."

# Move post-reboot script to a temporary location
sudo cp ./rasbperry-config/gpsberry/post-reboot.sh /tmp/post-reboot-gps.sh
# Make the post-reboot script executable
sudo chmod +x /tmp/post-reboot-gps.sh

# Add to crontab to run once after reboot
echo "@reboot /tmp/post-reboot-gps.sh" | sudo crontab -
echo "Post-reboot script created to configure GPS."

# Clean up the temporary install directory
rm -rf temp_install

sleep 10
# Then reboot
sudo reboot
