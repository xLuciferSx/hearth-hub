# Hearth hub for Synology

A self-hosted smart-home hub for a Synology NAS. It talks to your devices directly, runs your
automations on the NAS, and keeps your data there. Home Assistant isn't needed, and neither is any
other hub.

It also runs on a mini PC, a Raspberry Pi 4 or 5, or any 64-bit Linux machine with Docker.

## What it does

- **Native drivers**: Matter (including Thread), Zigbee through Zigbee2MQTT, and direct support for
  Tapo, Kasa, Apple Home accessories, Home Connect, Octopus Energy, Ohme, Dreo, Blueair, SimpliSafe,
  eufy Security, SmartThings, Ecovacs, Anker SOLIX, Smart Life and Tuya, Cosori, LG ThinQ, Toyota,
  eero, Aqara and your Synology itself.
- **One device model**: lights, radiators, locks, TVs, washers, vacuums, EV chargers and sensors all
  look the same to the app and to automations.
- **Automations** with time, sun, device and presence triggers, evaluated on the hub.
- **Away mode, heating schedules, energy and history**.
- **Everything is switched on from the app**, in Integrations. Nothing talks to a brand's cloud
  until you add that brand.

## Install on a Synology

The full guide, with Container Manager steps, USB sticks and networking, is in
[docs/synology.md](docs/synology.md). In short, over SSH:

```bash
sudo mkdir -p /volume1/docker/hearth
cd /volume1/docker/hearth
sudo git clone https://github.com/xLuciferSx/hearth-hub.git src
sudo cp -a src/deploy/. .
sudo ./hearth.sh setup
```

`setup` makes `.env`, starts the hub, and prints the address and token to enter in the Hearth app
under **Connect with a hub token**.

On another Linux machine, the same steps work from any folder.

## What runs

| Service | What it does | Runs |
|---|---|---|
| `gateway` | The hub: API on port 8780, automations, history | Always |
| `bridge-native` | The native drivers, including Matter | Always |
| `bridge-zigbee` | Turns Zigbee2MQTT devices into Hearth devices | Always |
| `mosquitto` | Internal message bus, never on your LAN | Always |
| `matter-server` | Matter controller (a standalone server, not Home Assistant) | Always |
| `backup` | Nightly backups, 14 kept | Always |
| `zigbee2mqtt` | Runs your Zigbee coordinator | Profile `zigbee` |
| `matter-bridge`, `eufy-ws` | Alexa and Google, eufy cameras | Profile `extras` |
| `watchdog` | Restarts services that hang. Holds the Docker socket, so it's opt-in | Profile `watchdog` |

Turn on optional parts with `COMPOSE_PROFILES` in `.env`, like `COMPOSE_PROFILES=zigbee,extras`, then
run `sudo docker compose up -d`.

Images are published for linux/amd64 and linux/arm64.

## Zigbee

Plug in a coordinator, then set these in `.env`:

```
COMPOSE_PROFILES=zigbee
ZIGBEE_DEVICE=/dev/serial/by-id/usb-...
ZIGBEE_ADAPTER=ember
```

For a network coordinator, leave `ZIGBEE_DEVICE` empty and set
`ZIGBEE_PORT=tcp://192.168.1.30:6638`. Change these before Zigbee2MQTT's first start, or edit
`data/zigbee2mqtt/configuration.yaml` afterwards.

Pair devices from the app, or from the Zigbee2MQTT page on port 8099. Its login token is `auth_token`
in that same file. Name a device `Room/Device` and it lands in that room.

## Looking after it

| | |
|---|---|
| `./hearth.sh status` | Each service and its health |
| `./hearth.sh token` | The admin token for the app |
| `./hearth.sh backup` | A backup now, in `data/backups` |
| `./hearth.sh update 0.2.0` | Backs up, moves to that release, and goes back if it doesn't come up healthy |
| `./hearth.sh restore hearth-2026-01-31.tar.gz` | Replaces this hub's data with a backup |

Backups hold the Matter fabric and the Zigbee network key, so a restored hub keeps its devices. Keep a
copy off the NAS, with Hyper Backup for example, and treat it as a secret.

## Limits

- Push notifications need your own Apple developer account and your own build of the app.
- Sign-in with an account and access away from home need a hubs service of your own. Otherwise use
  the admin token, at home or over your own VPN. See [SECURITY.md](SECURITY.md).
- SmartThings sign-in needs an https redirect page of your own.
- Some drivers suit UK accounts: Octopus Energy and Ohme are UK services, and regional defaults for
  Alexa, eufy and Anker are in `.env`.

## Moving from the Home Assistant version

Earlier releases read devices through Home Assistant. This release doesn't, and it starts with a new
data folder, so add your integrations again from the app. Home Assistant can keep running beside it,
but only one program can hold a Zigbee stick, and a Matter device needs adding to Hearth as well.

## API

All endpoints need `Authorization: Bearer <token>`. A few to start with:

| Endpoint | |
|---|---|
| `GET /api/home` | Rooms and devices |
| `GET /api/live` | WebSocket stream of changes |
| `POST /api/devices/{id}/command` | `{"action": "turn_on", "params": {}}` |
| `GET /api/devices/{id}/history?key=temperature&hours=24` | Readings |
| `GET/PUT /api/automations` | Automations |
| `GET/POST /api/away` | Away mode |
| `GET /api/integrations` | What's on, and its state |

## Source

`deploy/` is everything needed to run the hub. The Go code under `cmd/` and `internal/` is an earlier
snapshot of the gateway and Zigbee bridge. It's older than the published images, and `bridge-native`
isn't in it.

## Licence

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE). If you redistribute the hub or build
on it, keep the NOTICE file. Zigbee2MQTT, Mosquitto, the Matter server and eufy-security-ws are
separate projects under their own licences.
