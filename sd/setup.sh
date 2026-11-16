#!/bin/sh -e
## $ ./setup.sh /dev/sdh UNIT01
die()
{
	echo "FAILED! $@"
	exit 1
}

IMG="$( ls ../downloads/*-arm64-lite.img )"
if [ $# -ne 2 ]; then
	die "usage: ${0} <dev of SD card> <hostname>"
fi
DEV="$1"
test ! -e "$DEV" && die "'$DEV' does not exist!" || true

HNAME="$( echo $2 | tr '[:upper:]' '[:lower:]' )"
test -e ./overlay/${HNAME} || die "no configuration for hostname '$HNAME'"
echo "using hostname '$HNAME'"

## prepare
rm -rf ./boot || true
cp -arf ./common/boot ./
rm -rf ./rootfs || true
cp -arf ./common/rootfs ./
cp -arf ./overlay/${HNAME}/* ./rootfs/

sudo dd if="$IMG" of="$DEV" bs=4M conv=fdatasync status=progress
sleep 5

## install boot files
BOOT="/run/media/$USER/bootfs"
udisksctl mount -b "${DEV}1"
## /boot [fat32] won't keep protections, which will throw an error -> true
## TODO this will change for ./boot/firmware/
sudo cp -arfv ./boot/* "$BOOT"/ || true
udisksctl unmount -b "${DEV}1"

## install rootfs files
ROOTFS="/run/media/$USER/rootfs"
udisksctl mount -b "${DEV}2"
sudo cp -arfv ./rootfs/* "$ROOTFS/"

## (2/2) /home/pi configs
sudo chown -R 1000:1000 "$ROOTFS/home/pi"
test -d "$ROOTFS/home/pi" && sudo chmod 700 "$ROOTFS/home/pi" || true
test -d "$ROOTFS/home/pi/.ssh" && chmod 700 "$ROOTFS/home/pi/.ssh" || true
test -f "$ROOTFS/etc/NetworkManager/NetworkManager.conf" && sudo chown root:root "$ROOTFS/etc/NetworkManager/NetworkManager.conf"
test -d "$ROOTFS/etc/NetworkManager/system-connections" && sudo chown root:root "$ROOTFS/etc/NetworkManager/system-connections"/*
test -d "$ROOTFS/etc/NetworkManager/system-connections" && sudo chmod 600 "$ROOTFS/etc/NetworkManager/system-connections"/*

## edit /etc/passwd, replace /usr/bin/nologin by /bin/bash
sudo sed -i '/^pi:/ s|/usr/sbin/nologin|/bin/bash|' "$ROOTFS/etc/passwd"

udisksctl unmount -b "${DEV}2"
echo "READY."
