#!/bin/bash

#Copyright (c) 2012
#James Bennet <github@james-bennet.com>, Klaus M Pfeiffer <klaus.m.pfeiffer@kmp.or.at>

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

#******** PACKAGING NOTES ********
# I package for debian, but any dist that has debootstrap should work, as the apt-get's are done inside the debian chroots.

# Ubuntu doesnt have Xdialog :( - By the way, we supply size 0 so they autosize. May not be right for some text entry fields but meh.

#On the host, you need to get some build dependencies first:
#sudo apt-get -y install binfmt-support qemu qemu-user-static debootstrap kpartx lvm2 dosfstools git-core binutils ca-certificates ntp ntpdate openssh-server less vim screen multistrap schroot fakechroot cdebootstrap minicom bash dialog

function main
{
# 20 simple steps
init
checkRequirements
sayHello
getDevice
getBuildroot
getSuite
getArch
getMirror
getHostname
sayFinalWarning
checkDevice
partitionDevice
mountDevice
formatDevice
bootstrapDevice
configureBoot
configureSystem
thirdStatge
cleanUp
sayDone
}

function init
{
bootsize="64M" # Boot partition size on RPI.
mydate=`date +%Y%m%d`
image=""
}

function sayHello
{
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

dialog --title "RaspberryPi Card Builder v0.2" \
--msgbox "\n Please answer a few questions!" 0 0
}

# Let the user type in the chosen block device to work with
function getDevice
{
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

dialog --title "Enter path to block device to format, or CANCEL to make an image." --clear \
        --inputbox "Device path:" 0 0 2> $tempfile

retval=$?
device=`cat $tempfile`

case $retval in
  0)
     dialog --infobox "Setting device: ${device}..." 0 0; sleep 1;;
  1)
    $device=""
	dialog --infobox "WARNING: No block device given, creating image instead..." 0 0; sleep 2;;  # You can dd this to a block device yourself later.
  255)
      exit 1;;
esac
}

# Let the user type in the location to use as a buildroot. This should be an (empty) directory where you want the new system to be populated. This directory will reflect the root filesystem of the new system. Note that the host system is not affected in any way, and all modifications are restricted to the directory you have chosen.
function getBuildroot
{
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

dialog --title "Enter path to use as the buildroot (Working directory)" --clear \
        --inputbox "Buildroot path:" 0 0 2> $tempfile

retval=$?

buildenv=`cat $tempfile`
rootfs="${buildenv}/rootfs"
bootfs="${rootfs}/boot"

case $retval in
  0)
     dialog --infobox "Working in build root: ${buildenv}..." 0 0; sleep 1;;
  1)
    getDevice;;
  255)
    getDevice;;
esac
}

# Choose the target's Debian suite (Release e.g. stable, testing, sid), that you want to bootstrap.
function getSuite
{
dialog --clear --title "RaspberryPi Card Builder v0.2" \
        --menu "Please choose your Suite: " 0 0 0 \
        "squeeze"  "squeeze" \
        "wheezy" "wheezy" \
        "sid" "sid" 2> $tempfile

retval=$?
suite=`cat $tempfile`

case $retval in
  0)
    dialog --infobox "Setting Suite: ${suite}..." 0 0; sleep 1;;
  1)
    getBuildroot;;
  255)
    getBuildroot;;
esac
}

# Choose the target architecture (i.e. armel, armhf), that you want to bootstrap.
function getArch
{
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

dialog --clear --title "RaspberryPi Card Builder v0.2" \
        --menu "Please choose an Architecture:" 0 0 0 \
        "armel"  "armel" \
        "armhf" "armhf" 2> $tempfile

retval=$?
arch=`cat $tempfile`

case $retval in
  0)
     dialog --infobox "Setting Architecture: ${arch}..." 0 0; sleep 1;;
  1)
    getSuite;;
  255)
    getSuite;;
esac
}

# Mirror from which the necessary .deb packages will be downloaded. Choose any mirror, as long as it has the architecture you are trying to bootstrap. See http://www.debian.org/mirror/list for the list of available Debian mirrors.

# I have only currently tested debian (wheezy/armel) from http://http.debian.net/debian.
# Raspbian (wheezy/armhf) from  should work too. I could not get emdebian (squeeze/armel) from http://ftp.uk.debian.org/emdebian/grip to work.

function getMirror
{
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

dialog --clear --title "RaspberryPi Card Builder v0.2" \
        --menu "Please choose a mirror: " 0 0 0 \
        "http://http.debian.net/debian"  "http://http.debian.net/debian" \
        "http://archive.raspbian.org/raspbian" "http://archive.raspbian.org/raspbian" 2> $tempfile

retval=$?
deb_mirror=`cat $tempfile`

case $retval in
  0)
     dialog --infobox "Configuring mirror: ${deb_mirror}..." 0 0; sleep 1;;
  1)
   getArch;;
  255)
    getArch;;
esac
}

# Let the user type in the chosen target hostname
function getHostname
{
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

dialog --title "Enter Hostname" --clear \
        --inputbox "Target Hostname:" 0 0 2> $tempfile

retval=$?
hostname=`cat $tempfile`

case $retval in
  0)
     dialog --infobox "Setting hostname: ${hostname}..." 0 0; sleep 1;;
  1)
    getMirror;;
  255)
    getMirror;;
esac
}

function sayFinalWarning
{
dialog --yesno "This utility is beta software and may go horribly wrong.\n\nYou are bootstrapping ${hostname} with ${suite} (${arch}), from ${deb_mirror} into ${buildenv}\n\nAre you SURE you want to Continue?" 0 0
rc=$?
if [ "${rc}" != "0" ]; then
  exit 1
fi
}

function checkRequirements
{
if [ $EUID -ne 0 ]; then
dialog --title "RaspberryPi Card Builder v0.2" \
--msgbox "\n ERROR: This tool must be run with superuser rights!" 0 0 # Because debootstrap will create device nodes (using mknod) as well as chroot into the newly created system
  exit 1
fi
}

function checkDevice
{
if ! [ -b $device ]; then
dialog --title "RaspberryPi Card Builder v0.2" \
--msgbox "\n ERROR: Device: ${device} is not a block device!" 0 0
  getDevice
else
dialog --infobox "Device: ${device} OK..." 0 0; sleep 2;
fi
}

function partitionDevice
{
if [ "$device" == "" ]; then
  dialog --infobox "WARNING: No block device given, creating image instead." 0 0; sleep 2;
  mkdir -p $buildenv
  image="${buildenv}/pistrap_${suite}_{$arch}_${mydate}.img"
  dd if=/dev/zero of=$image bs=1MB count=1000 > /dev/null 2>&1
  device=`losetup -f --show $image`
  dialog --infobox "Image: ${image} created and mounted as: ${device}" 0 0; sleep 2;
else
  dialog --infobox "Partitioning Device ${device}" 0 0; sleep 1;
  dd if=/dev/zero of=$device bs=512 count=1
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
dialog --infobox "Mounting Partitions..." 0 0; sleep 2;

if [ "$image" != "" ]; then
  losetup -d $device
  device=`kpartx -va $image | sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1`
  device="/dev/mapper/${device}"
  bootp=${device}p1
  rootp=${device}p2
else
  if ! [ -b ${device}1 ]; then
    bootp=${device}p1
    rootp=${device}p2
    if ! [ -b ${bootp} ]; then
dialog --title "RaspberryPi Card Builder v0.2" \
--msgbox "\n ERROR: Can't find boot partition, neither as: ${device}1, nor as: ${device}p1. Exiting!" 0 0
      exit 1 # TODO: retry?
    fi
  else
    bootp=${device}1
    rootp=${device}2
  fi
fi
}

function formatDevice
{
dialog --infobox "Formatting Partitions ${bootp} and ${rootp}..." 0 0; sleep 1;

mkfs.vfat $bootp > /dev/null 2>&1 # Boot partition
mkfs.ext4 $rootp > /dev/null 2>&1 # Partition that will hold rootfs.

mkdir -p $rootfs
}

function bootstrapDevice
{
dialog --infobox "Entering new filesystem at ${rootfs}..." 0 0; sleep 1;
mount $rootp $rootfs
cd $rootfs

dialog --infobox "Bootstrapping into ${rootfs}..." 0 0; sleep 2;
# To bootstrap our new system, we run debootstrap, passing it the target arch and suite, as well as a directory to work in.
# FIXME: We do --no-check-certificate and --no-check-gpg to make raspbian work.
debootstrap --no-check-certificate --no-check-gpg --foreign --arch $arch $suite $rootfs $deb_mirror

dialog --infobox "Second stage. Chrooting into ${rootfs}..." 0 0; sleep 2;
# To be able to chroot into a target file system, the qemu emulator for the target CPU needs to be accessible from inside the chroot jail.
cp /usr/bin/qemu-arm-static usr/bin/
# Second stage - Run Post-install scripts.
LANG=C chroot $rootfs /debootstrap/debootstrap --no-check-certificate --no-check-gpg --second-stage
}

function configureBoot
{
dialog --infobox "Configuring boot partition ${bootp} on ${bootfs}..." 0 0; sleep 1;
mount $bootp $bootfs

#TODO: Configure /etc/inittab, and use USB serial console?
dialog --infobox "Configuring bootloader..." 0 0; sleep 1;
echo "dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait" > boot/cmdline.txt

#The system you have just created needs a few tweaks so you can use it.
dialog --infobox "Configuring fstab..." 0 0; sleep 1;
echo "proc            /proc           proc    defaults        0       0
/dev/mmcblk0p1  /boot           vfat    defaults        0       0
" > etc/fstab
}

function configureSystem
{
# By default, debootstrap creates a very minimal system, so we will want to extend it by installing more packages.
# TODO: Use apt-setup? - deb-src?
dialog --infobox "Configuring sources.list..." 0 0; sleep 1;
echo "deb $deb_mirror $suite main contrib non-free
" > etc/apt/sources.list

#Configure networking for DHCP
dialog --infobox "Setting hostname to ${hostname}..." 0 0; sleep 1;
echo $hostname > etc/hostname

dialog --infobox "Configuring network adapters..." 0 0; sleep 1;
echo "auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
" > etc/network/interfaces

# The (buggyish) analog audio driver for the SoC.
dialog --infobox "Configuring kernel modules..." 0 0; sleep 1;
echo "vchiq
snd_bcm2835
" >> etc/modules

dialog --infobox "Configuring locales..." 0 0; sleep 1;
echo "console-common	console-data/keymap/policy	select	Select keymap from full list
console-common	console-data/keymap/full	select	de-latin1-nodeadkeys
" > debconf.set
}

function thirdStatge
{
dialog --infobox "Third stage. Installing packages..." 0 0; sleep 2;

# Install things we need in order to grab and build firmware from github, and to work with the target remotely. Also, NTP as the date and time will be wrong, due to no RTC being on the board. This is important, as if you get errors relating to certificates, then the problem is likely due to one of two things. Either the time is set incorrectly on your Raspberry Pi, which you can fix by simply setting the time using NTP. The other possible issue is that you might not have the ca-certificates package installed, and so GitHub's SSL certificate isn't trusted.

echo "#!/bin/bash
debconf-set-selections /debconf.set
rm -f /debconf.set
apt-get -qq update
apt-get -qq -y install git-core binutils ca-certificates locales console-common ntp ntpdate openssh-server less vim screen
wget  -q http://raw.github.com/Hexxeh/rpi-update/master/rpi-update -O /usr/bin/rpi-update
chmod +x /usr/bin/rpi-update
mkdir -p /lib/modules/3.1.9+
touch /boot/start.elf
rpi-update
echo \"root:raspberry\" | chpasswd
sed -i -e 's/KERNEL\!=\"eth\*|/KERNEL\!=\"/' /lib/udev/rules.d/75-persistent-net-generator.rules
rm -f /etc/udev/rules.d/70-persistent-net.rules
rm -f third-stage
" > third-stage
chmod +x third-stage
LANG=C chroot $rootfs /third-stage

# Is this redundant?
echo "deb $deb_mirror $suite main contrib non-free
" > etc/apt/sources.list
}

function cleanUp
{
dialog --infobox "Cleaning up..." 0 0; sleep 2;

# Tidy up afterward
echo "#!/bin/bash
apt-get -qq clean
rm -f cleanup
" > cleanup
chmod +x cleanup
LANG=C chroot $rootfs /cleanup

cd

umount $bootp
umount $rootp

if [ "$image" != "" ]; then
  kpartx -d $image
  dialog --infobox "Created Image: ${image}." 0 0; sleep 2;
fi
}

function sayDone
{
dialog --title "RaspberryPi Card Builder v0.2" \
--msgbox "\n Done!" 0 0
}

#RUN
main
