#!/bin/sh
xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --auto
xrandr --dpi 75

userresources=$HOME/.Xresources
usermodmap=$HOME/.Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap

# merge in defaults and keymaps

if [ -f $sysresources ]; then
    xrdb -merge $sysresources
fi

if [ -f $sysmodmap ]; then
    xmodmap $sysmodmap
fi

if [ -f "$userresources" ]; then
    xrdb -merge "$userresources"
fi

if [ -f "$usermodmap" ]; then
    xmodmap "$usermodmap"
fi

[[ -f ~/.Xmodmap ]] && xmodmap ~/.Xmodmap

picom --backend glx --config ~/.dotfiles/picom.conf & 
xbindkeys 

xmonad &
xmonad_pid=$!
dunst &
xrandr --auto --output HDMI-0 --mode 1920x1080 --left-of eDP-1-1
feh --bg-scale 1081218.png
xsetroot -cursor_name left_ptr

wait $xmonad_pid
