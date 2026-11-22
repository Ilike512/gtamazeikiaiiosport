#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/.."
bundle=assets/bundled_audio
while IFS= read -r -d '' path; do
    case "$path" in
        'Radio Music/03 NICHE UNDERGROUNDS/3SUNC, VARNAS - MAMA MANE RODYS PER FARUS.mp3'|\
        'Radio Music/03 NICHE UNDERGROUNDS/Conkretus, OG Version - GTA.mp3'|\
        'Radio Music/03 NICHE UNDERGROUNDS/Flying Saucer Gang - Tuk Tuk.mp3'|\
        'Radio Music/03 NICHE UNDERGROUNDS/Mad Money - Namai.mp3') continue ;;
    esac
    mkdir -p "$bundle/$(dirname "$path")"
    cp "$path" "$bundle/$path.audio"
done < <(find 'Radio Music' -type f \( -iname '*.mp3' -o -iname '*.ogg' -o -iname '*.wav' \) -print0)
for name in studio_start loading; do
    for ext in mp3 wav ogg; do
        path="Custom Assets/sound/$name.$ext"
        if [[ -f "$path" ]]; then
            mkdir -p "$bundle/Custom Assets/sound"
            cp "$path" "$bundle/$path.audio"
        fi
    done
done
