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



# Environmental variables
export EDITOR="vim"

# Aliases
alias src="source ~/.zshrc"
alias ls="ls -m --color=auto"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

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

