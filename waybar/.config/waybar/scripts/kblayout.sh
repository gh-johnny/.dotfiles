#!/bin/bash

layout=$(hyprctl devices -j | jq -r '.keyboards[0].active_keymap')

case "$layout" in
    *English*) echo "us" ;;
    *Portuguese*) echo "br" ;;
    *) echo "$layout" ;;
esac
