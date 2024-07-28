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
)

fzf_opts_open_file_line=(
    --bind 'alt-enter:become(nvim {1} +{2})'
    --bind 'enter:become(code -g {1}:{2})'
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
    ${fzf_opts_preview_line[@]}
    ${fzf_opts_open_file_line[@]}
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
    fd ${fd_opts_file[@]} ${exts[@]} | fzf ${fzf_opts_open_file[@]} ${fzf_opts_preview[@]}
}

ffpkg() {
    exts=($(fd_filter_exts $@) --search-path Library/PackageCache)
    fd ${fd_opts_file[@]} ${exts[@]} | fzf ${fzf_opts_open_file[@]} ${fzf_opts_preview[@]}
}


sf() {
    exts=($(rg_filter_exts $@))
    rg_prefix="rg ${rg_opts_file[@]} ${exts[@]}"
    fzf ${fzf_opts_rg[@]} --disabled \
        --bind "start:reload:$1 {q}" \
        --bind "change:reload:sleep 0.02;$1 {q} || true"
}

sfpkg() {
    exts=($(rg_filter_exts $@))
    rg_prefix="rg ${rg_opts_file[@]} ${exts[@]}"
    fzf ${fzf_opts_rg[@]} --disabled \
        --bind "start:reload:$1 {q}" \
        --bind "change:reload:sleep 0.02;$1 {q} Library/PackageCache || true"
}

fref() {
    meta_path=$(fd ${fd_opts_file[@]} -e meta | fzf ${fzf_opts_preview[@]})

    # cancel
    if [[ -z $meta_path ]]; then
        return
    fi

    meta_guid=$(rg_guid_from_meta $meta_path)
    ref_files=$(rg ${rg_opts_file[@]} $meta_guid)

    if [[ -z $ref_files ]]; then
        echo "No references"
        return
    fi

    echo "$ref_files" | fzf ${fzf_opts_rg}
}

alias ffasset="ff asset unity prefab"
alias sfasset="sf asset unity prefab"
