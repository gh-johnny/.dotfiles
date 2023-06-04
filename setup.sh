

# Double checking 
while( true ) do
    read -p "Running this program will make noticible changes in your machine. It is advised to check the file before running it and encounter any problem. Are you sure you would like to continue? [YES/NO]" ANSWER 
    if [ $ANSWER -eq "YES" ]; then
        break
    elif [ $ANSWER -eq "NO" ]; then
        echo "You cancelled this operation..."
        exit 1
    else
        continue
    fi
done






# Sync pacman && Install bins
sudo pacman -Syyy

# vim, i3, neovim, zsh, p10k, rofi, polybar, picom, dunst, cronie
sudo pacman -S

# ly
yay


git clone










# Make custom log dir
# mkdir - p ~/.logs/polybar_logs && ~/.logs/cron_logs


# Get rid of README.md file (docs)
# rm ~/.dotfiles/README.md


# Stow (automatically place all links into their belonging path)
stow $PWD/.dotfiles/*


# Get rid of setup.sh file (this file)
rm ~/.dotfiles/setup.sh
