# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Lines configured by zsh-newuser-install
HISTFILE=~/.zshhistfile
HISTSIZE=3000
SAVEHIST=5000
unsetopt beep
bindkey -v
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/jo/.zshrc'

alias ll="ls -l"
alias lla="ls -a"
alias llla="ls -la"

alias docker-c-clean="docker stop $(docker ps -aq) && docker rm $(docker ps -aq)"

alias ..="cd .."
alias ...="cd ../../"
alias ....="cd ../../../"
alias .....="cd ../../../../"

alias v="nvim ."

alias src="source ~/.zshrc"

alias grep="grep --color=always"

alias ssh-session='eval "$(ssh-agent -s)" && ssh-add $HOME/.ssh/gh'

# claude-profiles
alias claude-profiles="CLAUDE_CONFIG_DIR=~/projects/claude-profiles/profiles/claude-profiles claude --dangerously-skip-permissions"
alias claude-base="CLAUDE_CONFIG_DIR=~/projects/claude-profiles/profiles/base claude --dangerously-skip-permissions"
alias claude-uni="CLAUDE_CONFIG_DIR=~/projects/claude-profiles/profiles/uni claude --dangerously-skip-permissions"
alias claude-beo="CLAUDE_CONFIG_DIR=~/projects/claude-profiles/profiles/beo claude --dangerously-skip-permissions"
alias claude-care="CLAUDE_CONFIG_DIR=~/projects/claude-profiles/profiles/care claude --dangerously-skip-permissions"
alias claude-obsessia="CLAUDE_CONFIG_DIR=~/projects/claude-profiles/profiles/obsessia claude --dangerously-skip-permissions"
alias claude-beo-dashboard="CLAUDE_CONFIG_DIR=~/projects/claude-profiles/profiles/beo-dashboard claude --dangerously-skip-permissions"
alias claude-beo-mobile="CLAUDE_CONFIG_DIR=~/projects/claude-profiles/profiles/beo-mobile claude --dangerously-skip-permissions"
alias claude-care-backend="CLAUDE_CONFIG_DIR=~/projects/claude-profiles/profiles/care-backend claude --dangerously-skip-permissions"
alias claude-care-frontend="CLAUDE_CONFIG_DIR=~/projects/claude-profiles/profiles/care-frontend claude --dangerously-skip-permissions"
alias claude-linux="CLAUDE_CONFIG_DIR=~/projects/claude-profiles/profiles/claude-linux claude --dangerously-skip-permissions"


export TERMINAL=alacritty

PS1='%n@%m:%${(#):-%~}%# '

autoload -Uz compinit
compinit
# End of lines added by compinstall
source ~/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export TERMINAL=alacritty

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

# Java version management
export JAVA_17_HOME="/usr/lib/jvm/java-17-openjdk"
export JAVA_21_HOME="/usr/lib/jvm/java-21-openjdk"
export JAVA_25_HOME="/usr/lib/jvm/java-25-openjdk"

# Set default Java (17 currently set as system default)
export JAVA_HOME="$JAVA_17_HOME"
export PATH="$JAVA_HOME/bin:$PATH"

# Switch Java version in current shell
java17() { export JAVA_HOME="$JAVA_17_HOME" && export PATH="$JAVA_HOME/bin:${PATH//*jvm\/java-*\/bin:/}" && java -version; }
java21() { export JAVA_HOME="$JAVA_21_HOME" && export PATH="$JAVA_HOME/bin:${PATH//*jvm\/java-*\/bin:/}" && java -version; }
java25() { export JAVA_HOME="$JAVA_25_HOME" && export PATH="$JAVA_HOME/bin:${PATH//*jvm\/java-*\/bin:/}" && java -version; }

# Short aliases
alias j17='java17'
alias j21='java21'
alias j25='java25'

# Show current Java version and home
alias jv='echo "JAVA_HOME: $JAVA_HOME" && java -version'

# pnpm
export PNPM_HOME="/home/jo/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
export PATH="$HOME/.local/bin:$PATH"

export ANDROID_HOME=$HOME/Android/Sdk
unset ANDROID_SDK_ROOT  # /etc/profile.d sets this to /opt/android-sdk; ANDROID_HOME takes precedence

export PATH=$PATH:$ANDROID_HOME/platform-tools

# bun completions
[ -s "/home/jo/.bun/_bun" ] && source "/home/jo/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

. "$HOME/.local/share/../bin/env"

alias claude-mem='/home/jo/.bun/bin/bun "/home/jo/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

eval $(DISPLAY="" WAYLAND_DISPLAY="" SSH_ASKPASS="" keychain --eval --quiet --nogui ~/.ssh/gh)
