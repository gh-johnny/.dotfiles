#!/usr/bin/env bash

# Terminate already running bar instances
# If all your bars have ipc enabled, you can use 
polybar-msg cmd quit
# Otherwise you can use the nuclear option:
# killall -q polybar

# Launch bar1 
polybar bar1 2>&1 | tee $HOME/.logs/polybar_logs/bar1.log & disown

echo "Bars launched..."
