#!/bin/bash

#Copyright (c) 2012
#James Bennet <github@james-bennet.com>, Klaus M Pfeiffer <klaus.m.pfeiffer@kmp.or.at>, "Super" Nathan Weber <supernathansunshine@gmail.com>

#Permission to use, copy, modify, and/or distribute this software for
#any purpose with or without fee is hereby granted, provided that the
#above copyright notice and this permission notice appear in all copies.

#THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
#WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES
#OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE
#FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY
#DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER
#IN AN CTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT
#OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

#******** GENERAL NOTES ********
# pistrap.sh - Builds your own minimal (i.e. no GUI) RaspberryPi SD-card image. Images will fit in 1gb and take about 15m (on my crummy connection)
# The root password on the created image will be "raspberry".

# I take the "QEMU/debootstrap approach". See: http://wiki.debian.org/EmDebian/CrossDebootstrap and http://wiki.debian.org/EmDebian/DeBootstrap
# Based on work by Klaus M Pfeiffer at http://blog.kmp.or.at/2012/05/build-your-own-raspberry-pi-image/

# Report any issues using github.

# To test your image on x86, follow http://xecdesign.com/qemu-emulating-raspberry-pi-the-easy-way/

#******** PACKAGING NOTES ********
# I package for debian, but any dist that has debootstrap should work, as the apt-get's are done inside the debian chroots.

function main
{
init
checkRequirements
sayHello
getDevice
getBuildroot
getType
getHostname
getPassword
pickPackages
sayFinalWarning
checkDevice
partitionDevice
mountDevice
formatDevice
bootstrapDevice
configureBoot
configureSystem
networking
thirdStage
cleanUp
if [ "${device}" == "" ]; then
	ddImage
fi
sayDone
}

function init
{
bootsize="64M" # Boot partition size on RPI.
size=1000 # Size of image to create in MB. You will need to set this higher if you want a larger selection.
mydate=`date +%Y%m%d`
mytime=`date +%H%M`
image=""
password="raspberry"
choices=""
echo "
***************************
 Starting build at $mytime on $mydate.
***************************
" > /var/log/pistrap.log
}

function sayHello
{
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

whiptail --title "RaspberryPi Card Builder v0.2" \
--msgbox "\n Please answer a few questions!" 0 0
}

# Let the user type in the chosen block device to work with
function getDevice
{
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

whiptail --title "Enter path to block device to format, or CANCEL to make an image." --clear \
        --inputbox "Device path:" 0 0 2> $tempfile

retval=$?
device=`cat $tempfile`

case $retval in
  0)
     whiptail --infobox "Setting device: ${device}..." 0 0; sleep 1;;
  1)
    device=""
	whiptail --infobox "WARNING: No block device given, creating image instead..." 0 0; sleep 2;;  # You can dd this to a block device yourself later.
  255)
      exit 1;;
esac
}

# Let the user type in the location to use as a buildroot. This should be an (empty) directory where you want the new system to be populated. This directory will reflect the root filesystem of the new system. Note that the host system is not affected in any way, and all modifications are restricted to the directory you have chosen.
function getBuildroot
{
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

whiptail --title "Enter path to use as the buildroot (Working directory)" --clear \
        --inputbox "Buildroot path:" 0 0 2> $tempfile

retval=$?

buildenv=`cat $tempfile`
rootfs="${buildenv}/rootfs"
bootfs="${rootfs}/boot"

case $retval in
  0)
     whiptail --infobox "Working in build root: ${buildenv}..." 0 0; sleep 1;;
  1)
    getDevice;;
  255)
      exit 1;;
esac
}


# It doesnt make any sence to select things in the old order. Raspbian doesnt have a sid or a squeeze. Debian doesnt have armhf. This is reworked for a logical flow.
function getType
{
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

whiptail --clear --title "RaspberryPi Card Builder v0.2" \
        --menu "Please choose an Architecture:" 0 0 0 \
        "armel"  "Debian" \
        "armhf" "Raspbian" 2> $tempfile

retval=$?
arch=`cat $tempfile`

if [ "${arch}" = "armhf" ] ; then
suite="wheezy"
deb_mirror="http://archive.raspbian.org/raspbian"
else
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15
whiptail --clear --title "RaspberryPi Card Builder v0.2" \
        --menu "Please choose your Suite: " 0 0 0 \
        "squeeze"  "squeeze" \
        "wheezy" "wheezy" \
        "sid" "sid" 2> $tempfile

retval=$?
suite=`cat $tempfile`
deb_mirror="http://http.debian.net/debian"
fi

case $retval in
  0)
     whiptail --infobox "Setting up for ${arch}...." 0 0; sleep 1;;
  1)
   getBuildroot;;
  255)
      exit 1;;
esac

}


# Let the user type in the chosen target hostname
function getHostname
{
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

whiptail --title "Enter Hostname" --clear \
        --inputbox "Target Hostname:" 0 0 2> $tempfile

retval=$?
hostname=`cat $tempfile`

case $retval in
  0)
     whiptail --infobox "Setting hostname: ${hostname}..." 0 0; sleep 1;;
  1)
    getMirror;;
  255)
      exit 1;;
esac
}

# Let the user type in the chosen root password
function getPassword
{
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

whiptail --title "Enter root password:" --clear \
        --inputbox "Root password:" 0 0 2> $tempfile

retval=$?
password=`cat $tempfile`

case $retval in
  0)
     whiptail --infobox "Setting root password: ${password}..." 0 0; sleep 1;;
  1)
    password="raspberry"
	whiptail --infobox "WARNING: No root password given! - Setting default of 'raspberry'.." 0 0; sleep 2;; 
  255)
      exit 1;;
esac
}

function pickPackages
{
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15
	
whiptail --title "Choose yer packages" --checklist \
"Do you want any of these packages installed?" 20 60 12 \
"less" "A pager, you prolly want this" ON \
"vim" "An editor, not as cool as Nano" OFF \
"screen" "Runs lots of stuff, inone terminal" OFF \
"minicom" "Does.........Something" OFF \
"zsh" "Probably the best shell ever" OFF \
"htop" "A better system monitor" OFF 2> $tempfile

retval=$?
choices=`cat $tempfile`

case $retval in
  0)
     whiptail --infobox "Selections Set..." 0 0; sleep 1;;
  1)
   getPassword;;
  255)
      exit 1;;
esac

}

function sayFinalWarning
{
whiptail --yesno "This utility is beta software and may go horribly wrong.\n\nYou are bootstrapping ${hostname} with ${suite} (${arch}), from ${deb_mirror} into ${buildenv}\n\nAre you SURE you want to Continue?" 0 0
rc=$?
if [ "${rc}" != "0" ]; then
  exit 1
fi
}

function checkRequirements
{
if [ $EUID -ne 0 ]; then
whiptail --title "RaspberryPi Card Builder v0.2" \
--msgbox "\n ERROR: This tool must be run with superuser rights!" 0 0 # Because debootstrap will create device nodes (using mknod) as well as chroot into the newly created system
  exit 1
fi
}

function checkDevice
{
if ! [ -b $device ]; then
whiptail --title "RaspberryPi Card Builder v0.2" \
--msgbox "\n ERROR: Device: ${device} is not a block device!" 0 0
  getDevice
else
whiptail --infobox "Device: ${device} OK..." 0 0; sleep 2;
fi
}

function partitionDevice
{

echo "
*****************
    Partitioning
*****************
" >> /var/log/pistrap.log

if [ "$device" == "" ]; then
  whiptail --infobox "WARNING: No block device given, creating image instead." 0 0; sleep 2;
  mkdir -p $buildenv  &>> /var/log/pistrap.log
  image="${buildenv}/pistrap_${suite}_${arch}_${mydate}.img"
  dd if=/dev/zero of=$image bs=1MB count=$size  &>> /var/log/pistrap.log
  device=`losetup -f --show $image`
  whiptail --infobox "Image: ${image} created and mounted as: ${device}" 0 0; sleep 2;
else
  whiptail --infobox "Partitioning Device ${device}" 0 0; sleep 1;
  dd if=/dev/zero of=$device bs=512 count=1 &>> /var/log/pistrap.log
fi

fdisk $device << EOF
n
p
1

+$bootsize
t
c
n
p
2


w
EOF
}

function mountDevice
{
whiptail --infobox "Mounting Partitions..." 0 0; sleep 2;

echo "
*****************
      Mounting
*****************
" >> /var/log/pistrap.log

if [ "$image" != "" ]; then
  losetup -d $device &>> /var/log/pistrap.log
  device=`kpartx -va $image | sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1`
  device="/dev/mapper/${device}"
  bootp=${device}p1
  rootp=${device}p2
else
  if ! [ -b ${device}1 ]; then
    bootp=${device}p1
    rootp=${device}p2
    if ! [ -b ${bootp} ]; then
whiptail --title "RaspberryPi Card Builder v0.2" \
--msgbox "\n ERROR: Can't find boot partition, neither as: ${device}1, nor as: ${device}p1. Exiting!" 0 0
      exit 1
    fi
  else
    bootp=${device}1
    rootp=${device}2
  fi
fi
}

function formatDevice
{
whiptail --infobox "Formatting Partitions ${bootp} and ${rootp}..." 0 0; sleep 3;

echo "
*****************
      Formatting
*****************
" >> /var/log/pistrap.log

mkfs.vfat $bootp &>> /var/log/pistrap.log # Boot partition
mkfs.ext4 $rootp &>> /var/log/pistrap.log # Partition that will hold rootfs.

mkdir -p $rootfs &>> /var/log/pistrap.log
}

function bootstrapDevice
{
whiptail --infobox "Entering new filesystem at ${rootfs}..." 0 0; sleep 1;

echo "
*****************
   Bootstrapping
*****************
" >> /var/log/pistrap.log

mount $rootp $rootfs  &>> /var/log/pistrap.log
cd $rootfs  &>> /var/log/pistrap.log

whiptail --infobox "Bootstrapping into ${rootfs}..." 0 0; sleep 2;
# To bootstrap our new system, we run debootstrap, passing it the target arch and suite, as well as a directory to work in.
# FIXME: We do --no-check-certificate and --no-check-gpg to make raspbian work.
debootstrap --no-check-certificate --no-check-gpg --foreign --arch $arch $suite $rootfs $deb_mirror  2>&1 | tee -a /var/log/pistrap.log

whiptail --infobox "Second stage. Chrooting into ${rootfs}..." 0 0; sleep 2;
# To be able to chroot into a target file system, the qemu emulator for the target CPU needs to be accessible from inside the chroot jail.
cp /usr/bin/qemu-arm-static usr/bin/  &>> /var/log/pistrap.log
# Second stage - Run Post-install scripts.
LANG=C chroot $rootfs /debootstrap/debootstrap --no-check-certificate --no-check-gpg --second-stage  2>&1 | tee -a /var/log/pistrap.log
}

function configureBoot
{
whiptail --infobox "Configuring boot partition ${bootp} on ${bootfs}..." 0 0; sleep 1;

echo "
*****************
Configuring Boot
*****************
" >> /var/log/pistrap.log

mount $bootp $bootfs  &>> /var/log/pistrap.log

whiptail --infobox "Configuring bootloader..." 0 0; sleep 1;
echo "dwc_otg.lpm_enable=0 console=ttyUSB0,115200 kgdboc=ttyUSB0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait" > boot/cmdline.txt

#The system you have just created needs a few tweaks so you can use it.
whiptail --infobox "Configuring fstab..." 0 0; sleep 1;
echo "proc            /proc           proc    defaults        0       0
/dev/mmcblk0p1  /boot           vfat    defaults        0       0
" > etc/fstab
}

function networking
{

echo "
*****************
Configuring Net
*****************
" >> /var/log/pistrap.log

#Configure networking for DHCP
whiptail --infobox "Setting hostname to ${hostname}..." 0 0; sleep 2;
echo $hostname > etc/hostname
echo "127.0.1.1\t$hostname\n" >> etc/hosts

whiptail --infobox "Configuring network adapters..." 0 0; sleep 2;
echo "auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
" > etc/network/interfaces
}

function configureSystem
{

echo "
*****************
    Configuring
*****************
" >> /var/log/pistrap.log

# By default, debootstrap creates a very minimal system, so we will want to extend it by installing more packages.
whiptail --infobox "Configuring sources.list..." 0 0; sleep 1;
echo "deb $deb_mirror $suite main contrib non-free
" > etc/apt/sources.list

# The (buggyish) analog audio driver for the SoC.
whiptail --infobox "Configuring kernel modules..." 0 0; sleep 1;
echo "vchiq
snd_bcm2835
" >> etc/modules


echo "pcm.mmap0 {
    type mmap_emul;
    slave {
      pcm \"hw:0,0\";
    }
}

pcm.!default {
  type plug;
  slave {
    pcm mmap0;
  }
}
" > etc/asound.conf

# Will spawn consoles on USB serial adapter for headless use.
whiptail --infobox "Configuring USB serial console..." 0 0; sleep 1;
echo "T0:23:respawn:/sbin/getty -L ttyUSB0 115200 vt100" >> etc/inittab

whiptail --infobox "Configuring locales..." 0 0; sleep 1;
echo "console-common	console-data/keymap/policy	select	Select keymap from full list
console-common	console-data/keymap/full	select	de-latin1-nodeadkeys
" > debconf.set
}

function thirdStage
{
whiptail --infobox "Third stage. Installing packages..." 0 0; sleep 2;

echo "
*****************
    Stage 3
*****************
" >> /var/log/pistrap.log

# Install things we need in order to grab and build firmware from github, and to work with the target remotely. Also, NTP as the date and time will be wrong, due to no RTC being on the board. This is important, as if you get errors relating to certificates, then the problem is likely due to one of two things. Either the time is set incorrectly on your Raspberry Pi, which you can fix by simply setting the time using NTP. The other possible issue is that you might not have the ca-certificates package installed, and so GitHub's SSL certificate isn't trusted.

echo "#!/bin/bash
debconf-set-selections /debconf.set
rm -f /debconf.set
apt-get -qq update
apt-get -qq -y install git-core binutils ca-certificates locales console-common ntp ntpdate openssh-server wget module-init-tools $choices
wget  -q http://raw.github.com/Hexxeh/rpi-update/master/rpi-update -O /usr/bin/rpi-update
chmod +x /usr/bin/rpi-update
mkdir -p /lib/modules/3.1.9+
mkdir -p /lib/modules/3.6.11+
touch /boot/start.elf
rpi-update
echo \"root:$password\" | chpasswd
sed -i -e 's/KERNEL\!=\"eth\*|/KERNEL\!=\"/' /lib/udev/rules.d/75-persistent-net-generator.rules
apt-get update && yes | apt-get upgrade
rm -f /etc/udev/rules.d/70-persistent-net.rules
rm -f third-stage
" > third-stage
chmod +x third-stage  &>> /var/log/pistrap.log
LANG=C chroot $rootfs /third-stage  2>&1 | tee -a /var/log/pistrap.log

# Is this redundant?
echo "deb $deb_mirror $suite main contrib non-free
" > etc/apt/sources.list
}

function cleanUp
{
whiptail --infobox "Cleaning up..." 0 0; sleep 2;

echo "
*****************
     Cleaning Up
*****************
" >> /var/log/pistrap.log

# Tidy up afterward
echo "#!/bin/bash
apt-get -qq clean
rm -f cleanup
" > cleanup
chmod +x cleanup &>> /var/log/pistrap.log
LANG=C chroot $rootfs /cleanup &>> /var/log/pistrap.log

cd

umount $bootp 2>&1 | tee -a /var/log/pistrap.log
umount $rootp 2>&1 | tee -a /var/log/pistrap.log

if [ "$image" != "" ]; then
  kpartx -d $image &>> /var/log/pistrap.log
  whiptail --infobox "Created Image: ${image}." 0 0; sleep 2;
fi
}

function sayDone
{
whiptail --title "RaspberryPi Card Builder v0.2" \
--msgbox "\n Done!" 0 0

echo "
*****************
      Done
*****************
" >> /var/log/pistrap.log

cd $buildenv

}

function ddImage
{
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

whiptail --title "Enter path to block device to write image to, if you wish." --clear \
        --inputbox "Device path:" 0 0 2> $tempfile

retval=$?
device=`cat $tempfile`

case $retval in
  0)
     whiptail --infobox "Writing image to: ${device}..." 0 0; sleep 1;
	dd bs=1M if=$image of=$device;;
  1)
      sayDone;;
  255)
      exit 1;;
esac
}

#RUN
main
