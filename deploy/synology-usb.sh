#!/bin/sh
# Makes a USB Zigbee stick appear on a Synology. DSM doesn't always load its USB serial drivers.
# Run it as root from a Task Scheduler boot-up task. A driver DSM doesn't have is skipped.
for driver in usbserial ftdi_sio cdc-acm cp210x ch341 pl2303; do
	file=/lib/modules/$driver.ko
	if [ -e "$file" ] && ! lsmod | grep -q "^$(echo "$driver" | tr - _) "; then
		insmod "$file" && echo "loaded $driver"
	fi
done
ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "No serial device yet. See the USB section of the guide."
