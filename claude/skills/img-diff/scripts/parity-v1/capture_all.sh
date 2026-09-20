#!/bin/bash
U="${UNITY:-unity}"
P="${PROJECT_PATH:-Game}"
SP="${PARITY_SCRATCH:?set PARITY_SCRATCH to a working directory}"
RAW="$SP/gcap2"
LIVE="${PARITY_LIVE:-$P/.agent/ui/live/live.png}"
MEAS="$SP/gcap2/measures.tsv"
mkdir -p "$RAW"
: > "$MEAS"

declare -A DEV
DEV[9x16]="Xiaomi Redmi Note 3"
DEV[9x20]="iOS Notch Device Small"
DEV[3x4]="Apple iPad Air"

for theme in paper midnight zen; do
  for ratio in 9x16 9x20 3x4; do
    dev="${DEV[$ratio]}"
    $U command ui_device --device "$dev" --project-path $P >/dev/null 2>&1
    $U command eval --code 'return Core.ConsoleCommands.Execute("g.level.mockupParity");' --project-path $P --timeout 60 >/dev/null 2>&1
    $U command eval --code "Game.GameThemes.Apply(\"$theme\"); return true;" --project-path $P >/dev/null 2>&1
    sleep 1.2
    m=$($U command eval_file --file "$(dirname "$0")/measure_crop.cs" --project-path $P 2>&1 | grep -o 'render=[^"]*')
    $U command ui_live_render --current --project-path $P >/dev/null 2>&1
    cp "$LIVE" "$RAW/${theme}__${ratio}__raw.png"
    echo -e "${theme}\t${ratio}\t${m}" | tee -a "$MEAS"
  done
done
echo "CAPTURE DONE"
