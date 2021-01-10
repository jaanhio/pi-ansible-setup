#!/bin/sh

set -e

SD_CARD_PATH=$1
OS_IMAGE_PATH=$2

if [[ -z ${SD_CARD_PATH} ]] || [[ -z ${OS_IMAGE_PATH} ]] ; then
	echo "Please provide SD card disk path for first arg and OS image path for second arg \n"
	echo "e.g ./pi-setup.sh /dev/disk2 ~/Downloads/raspbian.img"
	exit 1
fi

# Check provided disk path and ask user for confirmation
diskutil information ${SD_CARD_PATH}

while true; do
    read -p "Do you wish to install this program?" VERIFIED_DISK_PATH
    case $VERIFIED_DISK_PATH in
        [Yy]* ) echo 'proceeding with setup'; break;;
        [Nn]* ) echo 'Exiting setup...'; exit 0;;
        * ) echo "Please answer yes or no.";;
    esac
done

echo "Formatting SD card mounted on ${SD_CARD_PATH}...\n"

diskutil eraseDisk FAT32 RASPBERRYPI MBRFormat ${SD_CARD_PATH}

echo "Formatting of SD card completed...\n"

echo "Unmounting SD card...\n"
diskutil unmountDisk ${SD_CARD_PATH}

echo "SD card unmounted...\n"
echo "Proceeding with copying raspberrypi OS onto SD card...\n"
sudo dd bs=1m if=${OS_IMAGE_PATH} of=${SD_CARD_PATH}; sync

echo "Copy of raspberrypi OS completed.\n"
echo "Enabling SSH on boot...\n"
PI_BOOT_DIR=/Volumes/boot

if [[ -d ${PI_BOOT_DIR} ]]; then
  sudo touch /Volumes/boot/ssh
else
	echo "Unable to locate boot directory specified ${PI_BOOT_DIR}. Skipping..."
fi

diskutil eject ${SD_CARD_PATH}

echo "Setup completed. You may remove SD card."
