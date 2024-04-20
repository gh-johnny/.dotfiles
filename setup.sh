 ###                                                                 ###
 #####################################################################
 #####################################################################
 #                                                                   #
 #                                                                   #
 #            Read this file carefuly and make desired changes       #
 #            Thank you                                              #
 #             --   gh-johnny                                        #
 #                                                                   #
 #                                                                   #
 #                                                                   #
 #####################################################################
 #####################################################################
 ###                                                                 ###
                                                                   
while( true ) do
    read -rp "Running this program will make noticible changes in your machine. It is advised to check the file's content before running it and encounter any problem. Are you sure you would like to continue? [Y/n]" ANSWER 
    case "$ANSWER" in
        [Yy]|"")
            echo "Confirmed, proceeding."
            break
        ;;
        [Nn])
            echo "Aborting"
            exit 1 
        ;;
        *)
            echo "Invalid option"
        ;;
    esac
done

# Reboot to apply changes

cd &&

# Sync pacman 
sudo pacman -Syyy &&

# .dotfiles manager
sudo pacman -S stow &&

# Stow ( automatically place all lns into their belonging path )
cd ~/.dotfiles &&
stow */ &&

# Tilling window/desktop manager
# Recommended to install with OPTION 1 ( the rest may install with default options and it should be ok for most systems )
sudo pacman -S i3 &&
sudo pacman -S i3lock &&

# Installing aur helper ( yay ) 
git clone https://aur.archlinux.org/yay-git.git &&
cd yay-git/ &&
makepkg -si && 
cd &&
rm -rf yay-git &&

# Shell ( zsh )
# And setting it as default shell
sudo pacman -S zsh &&
chsh -s /usr/bin/zsh &&

# Zsh theme ( Install only check --> https://github.com/romtav/powerlevel10k#manual )
yay -S --noconfirm zsh-theme-powerlevel10k-git &&

# Server for hardware --> graphical environment
sudo pacman -S xorg &&

# Terminal
sudo pacman -S alacritty &&
sudo pacman -S wezterm &&

## Tmux ( terminal multiplexer )
sudo pacman -S tmux &&
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm &&

# Text editors 
sudo pacman -S vim &&
sudo pacman -S neovim && 

# For fzf
sudo pacman -S fzf && 
sudo pacman -S ripgrep && 
sudo pacman -S fd && 

# Hide mouse bin
sudo pamcan -S unclutter &&

# App launcher and more
sudo pacman -S rofi &&

# Status bar for desktop
sudo pacman -S polybar &&

# Notification bins
sudo pacman -S dunst &&
sudo pacman -S libnotify &&

# To customize and acitvate your cron jobs ( source the file later on with: crontab mycron )
# To activate cron job system
sudo pacman -S cronie &&
sudo systemctl enable cronie &&
sudo systemctl start cronie &&

# Battery info getter
sudo pacman -S acpi &&

# Hotkeys manager ( independent from wm )
sudo pacman -S sxhkd &&

# Icon theme for apps in graphical env
sudo pacman -S papirus-icon-theme &&

# Browsers
sudo pacman -S firefox &&
yay -S google-chrome &&

# Wallpaper manager
sudo pacman -S nitrogen &&

# Audio manager 
sudo pacman -S pamixer &&
sudo pacman -S alsamixer &&
sudo pacman -S alsa-utils &&
sudo pacman -S pavucontrol &&
sudo usermod -aG audio $USER &&

# Screenshot software
sudo pacman -S flameshot &&

# Music player
sudo pacman -S spotify &&

# Business app
yay -S slack

# Screen brightness manager
yay -S brillo &&

# Compositor 
yay -S picom-git &&

# Display manager 
sudo pacman -S ly &&
systemctl enable ly.service &&
systemctl disable getty@tty2.service &&

# Make custom log dir ( still in development )
# mkdir -p ~/.logs/polybar_logs && mkdir -p ~/.logs/cron_logs &&

# Get rid of README.md file 
# rm ~/.dotfiles/README.md &&

# Make Xauthority file
cd ~ &&
touch .Xauthority &&

# Home dir cleanup
# rm ~/.bashrc &&
# rm ~/.bash_profile &&
# rm ~/.bash_history &&
# rm ~/.bash_logout &&
rm -rf ~/Documents &&
mkdir Media && mv Pictures/ Media/ && mv Videos/ Media/ && mv Music/ Media/ 

chmod +x ~/.local/bin/*
chmod +x ~/.config/autostart/*
# Get rid of setup.sh file ( this file )
# rm ~/.dotfiles/setup.sh 






