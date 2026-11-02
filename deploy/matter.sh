#!/bin/sh
# Starts the Matter server on MATTER_INTERFACE, else the card with the default route.
card=${MATTER_INTERFACE:-$(awk '$2 == "00000000" { print $1; exit }' /proc/net/route)}
set -- --storage-path /data --paa-root-cert-dir /data/credentials --listen-address 127.0.0.1
[ -z "$card" ] || set -- "$@" --primary-interface "$card"
exec matter-server "$@"
