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
alias la="ls -a"
alias lla="ls -la"

alias docker-c-clean='docker stop $(docker ps -aq) && docker rm $(docker ps -aq)'  # single quotes: run when called, not at every shell start

export ANTIGRAVITY_CONFIG_DIR="$HOME/config"

alias ..="cd .."
alias ...="cd ../../"
alias ....="cd ../../../"
alias .....="cd ../../../../"

alias v="nvim ."

alias src="source ~/.zshrc"

alias grep="grep --color=always"

alias ssh-session='eval "$(ssh-agent -s)" && ssh-add $HOME/.ssh/gh'

# ai-agents — LLM-agnostic launcher. Usage: ai <key> [--llm claude|codex] [--rc] [--session <s>] [tool flags] [prompt]
#   ai uni                              # foreground, claude (default), uni's default_flags
#   ai uni --model opus --effort high   # flags pass through to the tool
#   ai uni --llm codex -m gpt-5 "fix"   # launch codex instead (needs agents/uni/codex/)
#   ai uni --rc [--session dev-uni]     # tmux window + remote control (claude only)
# Agent keys + per-LLM config live in config/agent-registry.json (run `ai` with no args to list).
# bifrost ready: let what the other host already sent arrive before the agent starts (instant when synced)
unalias ai 2>/dev/null
ai() { command -v bifrost >/dev/null && bifrost ready; "$HOME/.local/bin/ai" "$@"; }

export TERMINAL=alacritty

PS1='%n@%m:%${(#):-%~}%# '

fpath=(~/projects/ai-agents/scripts/completions $fpath)  # ai launcher completion
autoload -Uz compinit
compinit
# End of lines added by compinstall
[[ -r ~/powerlevel10k/powerlevel10k.zsh-theme ]] && source ~/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

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

alias dbeaver='JAVA_HOME="$JAVA_21_HOME" PATH="$JAVA_21_HOME/bin:$PATH" /usr/bin/dbeaver'

# Show current Java version and home
alias jv='echo "JAVA_HOME: $JAVA_HOME" && java -version'

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
export PATH="$HOME/.local/bin:$PATH"

export ANDROID_HOME=$HOME/Android/Sdk
unset ANDROID_SDK_ROOT  # /etc/profile.d sets this to /opt/android-sdk; ANDROID_HOME takes precedence

[[ -d $ANDROID_HOME ]] && export PATH=$PATH:$ANDROID_HOME/platform-tools

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"  # uv

alias claude-mem='$HOME/.bun/bin/bun "$HOME/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

command -v keychain >/dev/null && [[ -f ~/.ssh/gh ]] && eval $(DISPLAY="" WAYLAND_DISPLAY="" SSH_ASKPASS="" keychain --eval --quiet --nogui ~/.ssh/gh)


# packages dot installed with nix (dot/lib/pkg/nix.sh keeps its own profile)
[[ -d ~/.local/state/dot/nix-profile/bin ]] && export PATH="$HOME/.local/state/dot/nix-profile/bin:$PATH"
# mise tools on hosts without the ~/.local/bin symlinks (last: never shadows anything)
[[ -d ~/.local/share/mise/shims ]] && export PATH="$PATH:$HOME/.local/share/mise/shims"

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
