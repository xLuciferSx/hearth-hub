#!/bin/sh
# Keeps 14 nights of the hub's state: rooms, automations, the Matter fabric and the Zigbee network
# key. Each archive appears in one step, and the first is made as soon as this starts.
set -eu
umask 077
while :; do
	chown root:65532 /backups/hearth-*.tar.gz 2>/dev/null && chmod 640 /backups/hearth-*.tar.gz # the hub reads them to seal a copy for the phone
	file="/backups/hearth-$(date +%F).tar.gz"
	if [ ! -e "$file" ] && { [ "$(date +%H)" -ge 3 ] || [ -z "$(ls /backups/hearth-*.tar.gz 2>/dev/null)" ]; }; then
		tar czf "$file.tmp" --exclude=./backups -C /state .
		mv "$file.tmp" "$file"
		find /backups -name 'hearth-*.tar.gz' -mtime +14 -delete
		echo "saved $file"
	fi
	sleep 600
done
