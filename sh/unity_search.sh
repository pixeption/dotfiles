script_path=$0

fd_opts_file=(
    --type file
    --exclude obj
    --exclude Library
)

rg_opts_file=(
    --column
    --line-number
    --no-heading
    --color=always
    --smart-case
)

fzf_opts_open_file=(
    --bind 'alt-enter:become(nvim {})'
    --bind 'enter:become(code {})'
    --bind 'tab:execute-silent(code {})'
)

fzf_opts_open_file_line=(
    --bind 'alt-enter:become(nvim {1} +{2})'
    --bind 'enter:become(code -g {1}:{2})'
    --bind 'tab:execute-silent(code -g {1}:{2})'
)

fzf_opts_preview=(
    --preview 'bat -n --color=always --line-range :300 {}'
)

fzf_opts_preview_line=(
    --preview 'bat --color=always {1} --highlight-line {2}' \
    --preview-window 'hidden,right,50%,+{2}+3/3' \
)

fzf_opts_rg=(
    --ansi
    --delimiter :
    $fzf_opts_preview_line
    $fzf_opts_open_file_line
)

fd_filter_exts() {
    extra_args=()
    for arg in $@; do
        extra_args+=(--extension)
        extra_args+=($arg)
    done
    echo $extra_args
}

rg_filter_exts() {
    extra_args=()
    for arg in $@; do
        extra_args+=("-g \"*.$arg\"")
    done
    echo $extra_args
}

rg_guid_from_meta() {
    echo $(rg --no-line-number --max-count=1 "guid: ([0-9a-z].+)" --only-matching --replace='$1' $1)
}

ff() {
    exts=($(fd_filter_exts $@))
    fd $fd_opts_file $exts | fzf $fzf_opts_open_file $fzf_opts_preview
}

ffpkg() {
    exts=($(fd_filter_exts $@) --search-path Library/PackageCache)
    fd $fd_opts_file $exts | fzf $fzf_opts_open_file $fzf_opts_preview
}


sf() {
    exts=($(rg_filter_exts $@))
    rg_prefix="rg $rg_opts_file $exts"
    fzf $fzf_opts_rg --disabled \
        --bind "start:reload:$rg_prefix {q}" \
        --bind "change:reload:sleep 0.02;$rg_prefix {q} || true"
}

sfpkg() {
    exts=($(rg_filter_exts $@))
    rg_prefix="rg $rg_opts_file $exts"
    fzf $fzf_opts_rg --disabled \
        --bind "start:reload:$rg_prefix {q}" \
        --bind "change:reload:sleep 0.02;$rg_prefix {q} Library/PackageCache || true"
}

fref_unity()
{
    meta="$1.meta"
    if [ ! -f $meta ]; then
        return
    fi

    guid="$(rg --no-line-number --max-count=1 "guid: ([0-9a-z].+)" --only-matching --replace='$1' $meta)"
    refs=$(rg $rg_opts_file -g '*.{asset,unity,prefab}' $guid)

    if [[ ! -z "$refs" ]]; then
        echo "$refs"
    fi
}

fref() {
    fd_prefix="fd $fd_opts_file --exclude '*.meta'"
    f_fref_unity="source $script_path; fref_unity"
    fzf --ansi \
        --delimiter : \
        --prompt "1. Choose File> " \
        --bind "ctrl-space:reload($fd_prefix)+change-prompt(1. Choose File> )+clear-query" \
        --bind "start:reload($fd_prefix)" \
        --bind "tab:execute-silent(code -g {1}:{2})" \
        --bind "enter:transform-prompt(echo \"2. \$(basename {1})> \")+reload($f_fref_unity {1})+clear-query" \
        --preview "$f_fref_unity {1}"
}

alias ffasset="ff asset unity prefab"
alias sfasset="sf asset unity prefab"
