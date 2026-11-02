# Security

## How the hub keeps your home safe

- **No secrets in code or in `.env` by default.** First start makes a random admin token, in
  `data/gateway/admin-token`. Integration logins live in the data folder.
- **Every request is authenticated** with a bearer token: the admin token, accepted only from your
  home network, or a signed account token if you run account sign-in.
- **The message bus is private.** Mosquitto is reachable from the compose network and the machine's
  localhost, never the LAN. Run nothing untrusted on the same machine.
- **Control ports stay on localhost.** The Matter server and eufy-security-ws have no login, so they
  listen on 127.0.0.1 only.
- **The Zigbee2MQTT page has a generated token**, in `data/zigbee2mqtt/configuration.yaml`.
- **Our services run as non-root** on distroless images with no shell, a read-only filesystem and no
  Linux capabilities. `init` runs as root briefly to set up folders. `matter-server` and
  `zigbee2mqtt` run as root in their own images.
- **The Docker socket is opt-in.** Only the `watchdog` profile mounts it, and that container has no
  network.
- **Requests through a proxy or tunnel** aren't treated as coming from your home network.

## Before exposing the hub to the internet

The hub listens on your local network only. To reach it from outside, prefer:

1. A VPN such as WireGuard, Tailscale or DSM's VPN Server (best: nothing is exposed), or
2. A tunnel with its own access control in front (for example Cloudflare Tunnel with Cloudflare
   Access).

Never forward port 8780 directly on your router.

## Checklist

- Keep DSM, Docker and Hearth up to date (`./hearth.sh update <version>`).
- Keep `.env` and the `data` folder private. Backups hold the admin token, the Matter fabric and the
  Zigbee network key.
- To replace the admin token, stop the hub, delete `data/gateway/admin-token`, and start it again.

## Reporting a vulnerability

Please report privately through the repository's security advisories rather than opening a public
issue. We aim to reply within a week.
