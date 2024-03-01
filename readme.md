# Fedora

###### fix for no sound in fedora39

add this line `options snd-intel-dspcfg dsp_driver=1` to `/etc/modprobe.d/alsa.conf`.
