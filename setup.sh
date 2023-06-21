
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

cd &&

# Sync pacman && Install bins
sudo pacman -Syyy &&

# Tilling window/desktop manager
# Recommended to install with option 1 ( the rest may install with default options and it should be ok for most systems )
sudo pacman -S i3 &&

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

# Text editors
sudo pacman -S vim &&
sudo pacman -S neovim && 

#l App launcher and more
sudo pacman -S rofi &&

# Status bar for desktop
sudo pacman -S polybar &&

# Notification bins
sudo pacman -S dunst &&
sudo pacman -S libnotify &&

# To better use cron jobs
# To activate cron jobs on mycron file
# ================================== OI there is a systemctl thing to enable cron stuff prob will have to put in here ...
sudo pacman -S cronie &&
crontab $CRON &&

# Battery info getter
sudo pacman -S acpi &&

# Icon theme for apps in graphical env
sudo pacman -S papirus-icon-theme &&

# Browser
sudo pacman -S firefox &&

# Wallpaper manager
sudo pacman -S nitrogen &&

# Audio manager 
sudo pacman -S pamixer &&

# .dotfiles manager
sudo pacman -S stow &&

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
rm ~/.dotfiles/README.md &&

# Stow ( automatically place all links into their belonging path )
cd ~/.dotfiles &&
stow */ &&

# Make Xauthority file
cd ~ &&
touch .Xauthority &&

# Home dir cleanup
rm ~/.bashrc &&
rm ~/.bash_profile &&
rm ~/.bash_history &&
rm ~/.bash_logout &&
rm -rf ~/Documents &&
mkdir Media && mv Pictures/ Media/ && mv Videos/ Media/ && mv Music/ Media/ &&

# Get rid of setup.sh file ( this file )
rm ~/.dotfiles/setup.sh 

# To already apply changes
&& reboot








