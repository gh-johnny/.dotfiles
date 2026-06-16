# X11 / i3 ONLY — this script does nothing under Hyprland/Wayland.
# Hyprland equivalents:
#   natural scrolling  → hypr/looknfeel.conf  (touchpad.natural_scroll)
#   cursor hiding      → not needed; Hyprland hides the cursor automatically

xinput set-prop 10 "libinput Natural Scrolling Enabled" 1

# Pointer disappear
unclutter &
unclutter --start-hidden
