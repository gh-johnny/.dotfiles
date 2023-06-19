###                                                                 ###
#####################################################################
#####################################################################
#                                                                   #
#                                                                   #
#           Read this file carefuly and make desired changes        #
#           Thank you                                               #
#           --   gh-johnny                                          #
#                                                                   #
#                                                                   #
#                                                                   #
#####################################################################
#####################################################################
###                                                                 ###
                                                                   

while( true ) do
    read -p "Running this program will make noticible changes in your machine. It is advised to check the file's content before running it and encounter any problem. Are you sure you would like to continue? [yes/no]" ANSWER 
    if [ $ANSWER == "yes" ]; then
        break
    elif [ $ANSWER == "no" ]; then
        echo "You cancelled this operation..."
        exit 1
    else
        continue
    fi
done


cd &&



# Sync pacman && Install bins
sudo pacman -Syyy &&

# Recommended to install with option 1 ( the rest may install with default options and it should be ok for most systems )
sudo pacman -S i3 &&

# Installing aur helper (yay) 
 git clone https://aur.archlinux.org/yay-git.git &&
 cd yay-git/ &&
 makepkg -si && 
 cd &&
 rm -rf yay-git &&


yay -S --noconfirm zsh-theme-powerlevel10k-git &&


sudo pacman -S xorg &&
sudo pacman -S alacritty &&
sudo pacman -S vim &&
sudo pacman -S neovim && 
sudo pacman -S zsh &&
sudo pacman -S rofi &&
sudo pacman -S polybar &&
sudo pacman -S dunst &&
sudo pacman -S libnotify &&
sudo pacman -S cronie &&
sudo pacman -S acpi &&
sudo pacman -S papirus-icon-theme &&
sudo pacman -S firefox &&
sudo pacman -S nitrogen &&
sudo pacman -S pamixer &&
sudo pacman -S stow &&


yay -S picom-git &&
yay -S brillo &&


sudo pacman -S ly &&
systemctl enable ly.service &&
systemctl disable getty@tty2.service &&
rm -rf ly &&


# Make custom log dir ( still in development )
 mkdir -p ~/.logs/polybar_logs && mkdir -p ~/.logs/cron_logs &&


# Get rid of README.md file (docs)
 rm ~/.dotfiles/README.md &&


# Stow (automatically place all links into their belonging path)
 cd &&
 stow ~/.dotfiles/* &&


# Get rid of setup.sh file (this file)
 cd &&
 rm ~/.dotfiles/setup.sh &&

# Comment both last '&&' and 'reboot' if you do not wish to already reboot your system
 reboot






















