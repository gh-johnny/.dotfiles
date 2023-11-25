# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Created by newuser for 5.9

source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

PS1='%n@%m:%${(#):-%~}%# '

# ex - arquive extractor
# ex <file>
ex()
{
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)    tar xvjf $1    ;;
            *.tar.gz)    tar xvzf $1    ;;
            *.tar.xz)    tar xf $1      ;;
            *.bz2)        bunzip2 $1     ;;
            *.rar)        unrar x $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)        tar xvf $1     ;;
            *.tbz2)        tar xvjf $1    ;;
            *.tgz)        tar xvzf $1    ;;
            *.zip)        unzip $1       ;;
            *.Z)        uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)        echo "don't know how to extract, sorry brotha '$1'..." ;;
        esac
    else
        echo "'$1' is not a valid file! Fool!"
    fi
}


# Environmental variables
export EDITOR="nvim"
export TERMINAL="alacritty"
export BROWSER="firefox"
export CRON=~/.dotfiles/cron/.config/.cron/mycron
export LESSHISTFILE=
# export LOGS="~./dotfiles/logs"
export XDG_PICTURES_DIR="~/Media/Pictures/"
export XDG_VIDEOS_DIR="~/Media/Videos/"
export XDG_MUSIC_DIR="~/Media/Music/"
export MOZILLA_HOME=~/.config/.mozilla


# Aliases
alias src="source ~/.zshrc"
alias nv="nvim"
alias v="nvim ."
alias git-flow="git log --all --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit" 
alias kill="kill -9"
alias ls="ls -m --color=auto"
alias ll="ls -l"
alias la="ls -a"
alias grep="grep --color=always"
alias mv="mv -i"
alias ssh="TERM=xterm-256color $(which ssh)"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias screenshot="flameshot"
alias .....="cd ../../../.."
alias brightness=~/.dotfiles/local/.local/bin/changebrightness
alias blh=~/.dotfiles/local/.local/bin/bluetoothheadphones
alias wifimenu=~/.dotfiles/local/.local/bin/wifimenu
alias screenadd=~/.dotfiles/local/.local/bin/screenadd
alias changekeyboardlayout=~/.dotfiles/local/.local/bin/changekeyboardlayout
alias cat="bat"
alias dot="cd ~/.dotfiles"
alias server='xdotool key --clearmodifiers Super+t && exit'

# Set to vi mode in cli
set -o vi

