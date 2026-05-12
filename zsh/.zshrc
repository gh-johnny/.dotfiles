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

alias ..="cd .."
alias ...="cd ../../"
alias ....="cd ../../../"
alias .....="cd ../../../../"

alias v="nvim ."

alias src="source ~/.zshrc"

alias grep="grep --color=always"

# claude-profiles
alias claude-p-basic="CLAUDE_CONFIG_DIR=~/.config/claude-profiles/basic claude --dangerously-skip-permissions"
alias claude="claude-p-basic"
alias claude-p-uni="CLAUDE_CONFIG_DIR=~/.config/claude-profiles/uni claude --dangerously-skip-permissions"
alias claude-p-beo="CLAUDE_CONFIG_DIR=~/.config/claude-profiles/beo claude --dangerously-skip-permissions"
alias claude-p-care="CLAUDE_CONFIG_DIR=~/.config/claude-profiles/care claude --dangerously-skip-permissions"
alias claude-p-obsessia="CLAUDE_CONFIG_DIR=~/.config/claude-profiles/obsessia claude --dangerously-skip-permissions"


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

