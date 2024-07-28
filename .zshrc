export XDG_CONFIG_HOME="$HOME/.config"

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
source <(fzf --zsh)

# fzf configs
export FZF_DEFAULT_OPTS=" \
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
    --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
    --layout=reverse \
    --cycle \
    --bind '[:preview-down' \
    --bind ']:preview-up' \
    --bind 'ctrl-\:toggle-preview'"

# omz configs
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# plugins
plugins=(git z zsh-autosuggestions zsh-syntax-highlighting colored-man-pages)

source $ZSH/oh-my-zsh.sh
source ~/.config/sh/unity_search.sh

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
