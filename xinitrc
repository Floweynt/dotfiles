#!/bin/sh


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

# start some nice programs

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
 for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
  [ -x "$f" ] && . "$f"
 done
 unset f
fi

#xrandr --listproviders
xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --auto
#exec i3 &>> "/var/log/i3.log"

xrandr --auto --output HDMI-0 --mode 1920x1080 --left-of eDP-1-1
picom --backend glx & #--experimental-backends &
dmenu &
slstatus &
feh --bg-center /home/flowey/.dotfiles/wallpaper.jpeg &
#./.startup-launch-apps.sh
dwm
