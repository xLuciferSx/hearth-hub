#!/bin/sh
# Looks after a Hearth hub. Run it from this folder, with sudo on a Synology.
#   ./hearth.sh setup               makes .env, starts the hub, prints how to connect
#   ./hearth.sh token               prints the admin token for the app
#   ./hearth.sh status              shows each service and its health
#   ./hearth.sh backup              saves a backup now
#   ./hearth.sh update <version>    backs up, moves to a release, goes back if it isn't healthy
#   ./hearth.sh restore <archive>   replaces this hub's data with a backup
set -eu
cd "$(dirname "$0")"
PATH=$PATH:/usr/local/bin

die() {
	echo "$*" >&2
	exit 1
}

setting() {
	value=$(sed -n "s/^$1=//p" .env 2>/dev/null | tail -n 1)
	echo "${value:-$2}"
}

put() {
	if grep -q "^$1=" .env; then
		sed "s|^$1=.*|$1=$2|" .env >.env.tmp && cat .env.tmp >.env && rm -f .env.tmp
	else
		echo "$1=$2" >>.env
	fi
}

data() {
	dir=$(setting HEARTH_DATA ./data)
	case $dir in
	/*) echo "$dir" ;;
	*) echo "$PWD/${dir#./}" ;;
	esac
}

lan_address() {
	ip -4 route get 1.1.1.1 2>/dev/null | sed -n 's/.* src \([0-9.]*\).*/\1/p' | head -n 1
}

local_zone() {
	if [ -n "${TZ:-}" ]; then
		echo "$TZ"
	else
		readlink /etc/localtime 2>/dev/null | sed -n 's|.*/zoneinfo/||p'
	fi
}

services() {
	docker compose ps -a --format '{{.Service}} {{.State}} {{.Health}}'
}

# healthy waits for every long-running service, and names the ones that never get there.
healthy() {
	waited=0
	while :; do
		bad=$(services |
			awk '$1 != "init" && $1 != "backup" && !($2 == "running" && ($3 == "healthy" || $3 == "")) { print $1 }')
		[ -z "$bad" ] && return 0
		[ "$waited" -ge "${HEALTH_WAIT:-180}" ] && {
			echo "not healthy: $bad" >&2
			return 1
		}
		sleep 5
		waited=$((waited + 5))
	done
}

setup() {
	command -v docker >/dev/null || die "Docker isn't installed."
	if [ ! -e .env ]; then
		cp .env.example .env
		chmod 600 .env
		address=$(lan_address)
		[ -z "$address" ] || put HUB_LAN_URL "http://$address:$(setting HEARTH_PORT 8780)"
		zone=$(local_zone)
		[ -z "$zone" ] || put TZ "$zone"
		echo "Made .env"
	fi
	mkdir -p "$(data)"
	docker compose up -d
	echo "Waiting for the services to come up"
	healthy
	cat <<TEXT

Hearth is running. In the app, choose "Connect with a hub token" and enter:

  Address  $(setting HUB_LAN_URL "http://<this machine>:$(setting HEARTH_PORT 8780)")
  Token    $(token)
TEXT
}

token() {
	docker compose run --rm --no-deps -T --entrypoint cat init /state/gateway/admin-token 2>/dev/null
}

backup() {
	stamp=$(date +%F-%H%M%S)
	docker compose run --rm --no-deps -T --entrypoint tar init czf "/state/backups/hearth-$stamp.tar.gz" --exclude=./backups -C /state .
	echo "backups/hearth-$stamp.tar.gz"
}

update() {
	version=${1:?usage: hearth.sh update <version>}
	old=$(setting HEARTH_VERSION 0.1.0)
	put HEARTH_VERSION "$version"
	echo "Backing up first"
	backup
	if docker compose pull -q && docker compose up -d --remove-orphans && healthy; then
		echo "Now on $version"
		return
	fi
	echo "Going back to $old" >&2
	put HEARTH_VERSION "$old"
	docker compose up -d --remove-orphans
	exit 1
}

restore() {
	archive=${1:?usage: hearth.sh restore <archive in the backups folder>}
	archive=$(basename "$archive")
	[ -e "$(data)/backups/$archive" ] || die "No $archive in $(data)/backups."
	docker compose stop
	docker compose run --rm --no-deps -T --entrypoint /bin/sh init -c '
		set -e
		cd /state
		for dir in *; do
			[ "$dir" = backups ] || rm -rf "./$dir"
		done
		tar xzf "/state/backups/$1" -C /state
	' restore "$archive"
	docker compose up -d
	healthy
	echo "Restored $archive"
}

case ${1:-} in
setup) setup ;;
token) token ;;
status) services ;;
backup) backup ;;
update) update "${2:-}" ;;
restore) restore "${2:-}" ;;
*) sed -n '2,8p' "$0" | cut -c3- ;;
esac
