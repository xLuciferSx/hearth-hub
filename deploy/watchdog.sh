#!/bin/sh
# Restarts a container of ours that has been unhealthy for three minutes, three times an hour at
# most. Each one goes in a log the hub reads, so the household hears about it.
checks=/tmp/checks
mkdir -p "${checks:?}"
log=/log/watchdog.log
while :; do
	unhealthy=$(docker ps --filter health=unhealthy --filter name=hearth- --format '{{.Names}}' 2>/dev/null | grep -v backup)
	for f in "${checks:?}"/*.count; do
		[ -e "$f" ] || continue
		name=$(basename "$f" .count)
		echo "$unhealthy" | grep -qx "$name" || rm -f "${f:?}"
	done
	now=$(date +%s)
	for name in $unhealthy; do
		n=$(($(cat "$checks/$name.count" 2>/dev/null || echo 0) + 1))
		echo "$n" >"$checks/$name.count"
		[ "$n" -ge 3 ] || continue
		rm -f "${checks:?}/${name:?}.count"
		awk -v since=$((now - 3600)) '$1 > since' "$checks/$name.times" 2>/dev/null >"$checks/$name.keep"
		mv "$checks/$name.keep" "$checks/$name.times"
		short=${name#hearth-}
		short=${short%-1}
		if [ "$(wc -l <"$checks/$name.times")" -ge 3 ]; then
			[ -e "$checks/$name.gave" ] || echo "gave up on $short" >>"$log"
			touch "$checks/$name.gave"
			continue
		fi
		rm -f "${checks:?}/${name:?}.gave"
		echo "$now" >>"$checks/$name.times"
		docker restart "$name" && echo "restarted $short" >>"$log"
	done
	sleep 60
done
