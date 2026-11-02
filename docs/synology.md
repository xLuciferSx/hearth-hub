# Installing on a Synology NAS

## What you need

- DSM 7.2 or later, on a model that runs **Container Manager**. Most Plus models do.
- 2 GB of memory or more.
- A fixed address for the NAS, set on your router or in **Control Panel > Network**.
- For Matter: IPv6 turned on (see Networking).
- For Zigbee: a coordinator, as a USB stick or on the network. Network coordinators avoid the driver
  work in the USB section.

## 1. Install

Install **Container Manager** from Package Center, then choose one of these.

### Over SSH

Turn on SSH in **Control Panel > Terminal & SNMP**, sign in, and run:

```bash
sudo mkdir -p /volume1/docker/hearth
cd /volume1/docker/hearth
sudo git clone https://github.com/xLuciferSx/synology-homeassistant-gateway.git src
sudo cp -a src/deploy/. .
sudo ./hearth.sh setup
```

If `git` isn't there, install **Git Server** from Package Center, or use the option below.

### In Container Manager

1. Download this repository as a ZIP and copy everything in `deploy/` to `/volume1/docker/hearth`
   with File Station.
2. In that folder, copy `.env.example` to `.env`. Hidden files show when you tick **Show hidden
   files** in File Station's settings.
3. In **Container Manager > Project > Create**, name it `hearth`, set the path to
   `/volume1/docker/hearth`, and choose **Use existing docker-compose.yml**.

Without SSH you can't read the generated token, so set your own in `.env` before you build the
project: `HOMEAPP_TOKEN=` followed by 32 or more random characters.

### Then set the basics in `.env`

| Setting | Why |
|---|---|
| `TZ` | Your time zone, like `Europe/Berlin`. DSM's own isn't picked up, so schedules run in UTC until it's set |
| `HEARTH_DATA` | `/volume1/docker/hearth/data` keeps all data on that shared folder |
| `HUB_LAN_URL` | `http://<nas-address>:8780`. Setup fills this in, so check it's the right address |
| `HOME_LAT`, `HOME_LON` | For sunrise and sunset automations |

Apply a change with `sudo docker compose up -d`.

## 2. Connect the app

Open the Hearth app, choose **Connect with a hub token**, and enter `http://<nas-address>:8780` and
the token. Add your brands in **Integrations**.

## Networking

`bridge-native` and `matter-server` use the NAS's own network, because Matter, mDNS and Wake-on-LAN
don't work through Docker's. Their control ports listen on localhost only.

- **Firewall**: if DSM's firewall is on, allow TCP 8780 for the app and TCP 8099 for the Zigbee2MQTT
  page, plus UDP 5353 and UDP 5540 for Matter, and UDP 5541 for the Alexa and Google bridge,
  from your local network.
- **IPv6**: Matter needs it. In **Control Panel > Network > Network Interface**, edit your LAN and set
  IPv6 to **Auto**.
- **Network card**: the Matter server finds the card from the default route. On a NAS with Virtual
  Machine Manager or Open vSwitch that's `ovs_eth0`, otherwise usually `eth0`, or `bond0` with Link
  Aggregation. To set it yourself, use `MATTER_INTERFACE` in `.env`.
- **Wider networks**: device scans cover the NAS's own /24. For a bigger network, set `NATIVE_SUBNET`.
- **Thread**: Matter devices on Thread are reached through a border router. If they join but stay
  offline, the NAS may not be following that router. Add `thread-routes.py` as a root Task Scheduler
  task, at boot and every five minutes, with `THREAD_INTERFACE=ovs_eth0 python3
  /volume1/docker/hearth/thread-routes.py`, using your own card's name. Python 3 comes from Package
  Center. `--dry-run` shows what it would change.

## USB Zigbee sticks

A stick that DSM recognises shows up as `/dev/ttyUSB0` or `/dev/ttyACM0`. Check with:

```bash
ls -l /dev/serial/by-id/ /dev/ttyUSB* /dev/ttyACM*
```

Prefer the `/dev/serial/by-id/...` path if it exists, because it survives a reboot and a change of
USB port. Put it in `.env`:

```
COMPOSE_PROFILES=zigbee
ZIGBEE_DEVICE=/dev/serial/by-id/usb-...
ZIGBEE_ADAPTER=ember
```

| Stick | `ZIGBEE_ADAPTER` |
|---|---|
| Sonoff Dongle-E, most Silicon Labs | `ember` |
| Sonoff Dongle-P, most Texas Instruments | `zstack` |
| ConBee, RaspBee | `deconz` |

Plug a USB stick in with a short extension cable, away from the NAS's disks and USB 3 ports, which
interfere with Zigbee.

If no device appears, DSM hasn't loaded its USB serial driver. Add a root **Boot-up** task in
**Control Panel > Task Scheduler** that runs:

```bash
sh /volume1/docker/hearth/synology-usb.sh
```

Some models don't ship the driver at all, and DSM updates can remove one. The community project
[dsm7-usb-serial-drivers](https://github.com/robertklep/dsm7-usb-serial-drivers) has builds per CPU
and DSM version. After a DSM update, check the stick again.

## Keeping it safe

- Hearth makes a backup each night in `data/backups`, and keeps 14. Include the `docker/hearth` folder
  in Hyper Backup so there's a copy off the NAS.
- Treat backups as secrets: they hold the admin token, Matter fabric and Zigbee network key.
- Don't forward port 8780 on your router. See [SECURITY.md](../SECURITY.md).

## Updating

```bash
cd /volume1/docker/hearth
sudo ./hearth.sh update 0.2.0
```

It backs up first, and goes back to the old version if the new one isn't healthy within three
minutes. To pick up new kit files, such as a changed `docker-compose.yml`, run `git -C src pull` and
copy `src/deploy` over again; `.env` and `data` aren't part of it.

## When something's wrong

```bash
sudo ./hearth.sh status
sudo docker compose logs --tail 50 <service>
```

| You see | Try |
|---|---|
| `matter-server` keeps restarting | Set `MATTER_INTERFACE`, and check IPv6 is on |
| `zigbee2mqtt` says no valid adapter | Check `ZIGBEE_DEVICE` and `ZIGBEE_ADAPTER`, then the USB section |
| The app can't reach the hub | Check the firewall, and that `http://<nas-address>:8780/healthz` says ok |
| Devices aren't found | Set `NATIVE_SUBNET`, or add the device by its address in Integrations |
| `permission denied` from Docker | Add `sudo` |
