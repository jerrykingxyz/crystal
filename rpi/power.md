# disable wifi and bluetooth
# add follow lines to /boot/config.txt and reboot
dtoverlay=disable-wifi
dtoverlay=disable-bt

# enable smb
pacman -S samba
# config smb
systemctl enable smb

# mount disk
# add follow line to /etc/fstab
/dev/sda1 /home/jerry/share_xiaoyi ext4 defaults 0 0
/dev/sda2 /home/jerry/share_jerry ext4 defaults 0 0

# config /boot/cmdline.txt
# more info see https://forums.raspberrypi.com/viewtopic.php?f=28&t=245931
# usb-storage.quirks=aaaa:bbbb:u

# config /boot/config.txt
# more info see https://forums.raspberrypi.com/viewtopic.php?t=257144
##turn on/ off bluetooth
dtoverlay=disable-bt
##turn on/off wifi
dtoverlay=disable-wifi
# [pi4]
##turn off ethernet port LEDs
dtparam=eth_led0=4
dtparam=eth_led1=4

##turn off mainboard LEDs
dtoverlay=act-led

##disable ACT LED
dtparam=act_led_trigger=none
dtparam=act_led_activelow=off
  
##disable PWR LED
dtparam=pwr_led_trigger=none
dtparam=pwr_led_activelow=off

# install cpupower
pacman -S cpupower
# set g
