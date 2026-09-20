export XDG_CONFIG_HOME="$HOME/.config"

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# fzf configs
export FZF_DEFAULT_COMMAND="fd --exclude obj --exclude Library"
export FZF_CTRL_T_COMMAND="fd --type f --exclude obj --exclude Library"
export FZF_DEFAULT_OPTS=" \
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#fab387 \
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
    --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#fab387 \
    --layout=reverse \
    --cycle \
    --bind '[:preview-down' \
    --bind ']:preview-up' \
    --bind 'ctrl-\:toggle-preview'"

# omz configs
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Don't block new shells on the update check; update quietly in the background, less often
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 30

# plugins
plugins=(git z colored-man-pages zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh
source <(fzf --zsh)
[[ -r ~/.config/sh/unity_search.sh ]] && source ~/.config/sh/unity_search.sh

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

alias lz=lazygit
alias nv=nvim
alias bu="brew upgrade"
alias cc=claude
alias ocs="~/.claude/skills/codex-implementor/scripts/opencode-sessions --attach"
bindkey "^U" backward-kill-line
# bindkey '^I' autosuggest-accept

# Unity CLI
[[ -r "$HOME/.unity/env" ]] && . "$HOME/.unity/env"

case ":${PATH}:" in
  *:"$HOME/.local/bin":*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
