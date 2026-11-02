#!/bin/sh
# First-run setup, in a container, so it works from a Synology's Container Manager as well as a
# shell. Safe to run every start: it fills in what's missing and leaves everything else alone.
set -eu
umask 077
cd /state

own() {
	owner=$1
	shift
	for dir in "$@"; do
		mkdir -p "$dir"
		chown "$owner" "$dir"
	done
}

own 65532:65532 gateway zigbee native eufy-ws-config
own 1000:1000 matter-bridge
own 1883:1883 mosquitto
own 0:0 matter eufy-ws zigbee2mqtt
own 0:65532 backups
chmod 750 backups
chmod 755 eufy-ws-config

if [ ! -s gateway/admin-token ]; then
	od -An -N32 -tx1 /dev/urandom | tr -d ' \n' >gateway/admin-token.tmp
	chown 65532:65532 gateway/admin-token.tmp
	chmod 400 gateway/admin-token.tmp
	mv gateway/admin-token.tmp gateway/admin-token
	echo "made the admin token"
fi

if [ ! -s zigbee2mqtt/configuration.yaml ]; then
	ui=$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')
	{
		cat <<YAML
version: 4
homeassistant:
  enabled: false
mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://mosquitto:1883
serial:
  port: $ZIGBEE_PORT
YAML
		[ -z "$ZIGBEE_ADAPTER" ] || echo "  adapter: $ZIGBEE_ADAPTER"
		cat <<YAML
frontend:
  enabled: true
  port: 8080
  auth_token: $ui
availability:
  enabled: true
device_options:
  retain: true
advanced:
  network_key: GENERATE
  pan_id: GENERATE
  ext_pan_id: GENERATE
  channel: $ZIGBEE_CHANNEL
  log_level: warning
YAML
	} >zigbee2mqtt/configuration.yaml
	echo "made the Zigbee2MQTT settings"
fi
