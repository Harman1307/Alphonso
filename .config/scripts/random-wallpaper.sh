#!/bin/bash

DIR="$HOME/wallpapers"
CURRENT=$(readlink -f "$DIR/current")

WALL=$(find "$DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) ! -name ".*" | shuf -n 1)

[ "$WALL" = "$CURRENT" ] && WALL=$(find "$DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) ! -name ".*" | shuf -n 1)

[ -z "$WALL" ] && exit 1

ln -sf "$WALL" "$DIR/current"
awww img "$WALL" --transition-type grow --transition-pos center --transition-duration 1 --transition-fps 60