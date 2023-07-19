# Create the script
echo '#!/bin/bash' > ~/.config/autostart/touchpad-config.sh
echo 'xinput set-prop 12 "libinput Tapping Enabled" 1' >> ~/.config/autostart/touchpad-config.sh
echo 'xinput set-prop 12 "libinput Natural Scrolling Enabled" 1' >> ~/.config/autostart/touchpad-config.sh

# Make the script executable
chmod +x ~/.config/autostart/touchpad-config.sh

