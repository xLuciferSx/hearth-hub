#!/usr/bin/env python3
"""Routes each Thread network through a border router that is answering now.

Thread devices sit behind border routers such as smart speakers and Wi-Fi mesh units. Those change
their addresses, and a NAS doesn't always follow them by itself, so this asks which are alive and
keeps one route per network. A route that's still good is left alone.

Only needed for Matter devices on Thread that the hub can't reach. It needs root: run it from a
scheduled task, at boot and every five minutes. --dry-run only prints what it would do. Set
THREAD_INTERFACE to the network card, ovs_eth0 on a Synology with Open vSwitch, eth0 without.
"""
import os
import socket
import struct
import subprocess
import sys
import time

INTERFACE = os.environ.get("THREAD_INTERFACE", "eth0")
ASK = 3
LISTEN = 3


def listen():
    index = socket.if_nametoindex(INTERFACE)
    s = socket.socket(socket.AF_INET6, socket.SOCK_RAW, socket.IPPROTO_ICMPV6)
    s.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_MULTICAST_HOPS, 255)
    s.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_MULTICAST_IF, index)
    group = socket.inet_pton(socket.AF_INET6, "ff02::1") + struct.pack("I", index)
    s.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_JOIN_GROUP, group)
    s.settimeout(0.5)
    networks = {}
    for _ in range(ASK):
        s.sendto(bytes([133, 0, 0, 0, 0, 0, 0, 0]), ("ff02::2", 0, 0, index))
        until = time.time() + LISTEN
        while time.time() < until:
            try:
                packet, sender = s.recvfrom(1500)
            except socket.timeout:
                continue
            for network in advertised(packet):
                routers = networks.setdefault(network, [])
                router = sender[0].split("%")[0]
                if router not in routers:
                    routers.append(router)
    return networks


def advertised(packet):
    if packet[0] != 134:
        return []
    found, at = [], 16
    while at + 2 <= len(packet) and packet[at + 1]:
        kind, size = packet[at], packet[at + 1] * 8
        if kind == 24 and packet[at + 2] == 64:
            address = (packet[at + 8:at + size] + bytes(16))[:16]
            if address[0] == 0xFD:
                found.append(socket.inet_ntop(socket.AF_INET6, address) + "/64")
        at += size
    return found


def current(network):
    out = subprocess.run(["ip", "-6", "route", "show", network], capture_output=True, text=True).stdout.split()
    return out[out.index("via") + 1] if "via" in out else None


def main():
    dry = "--dry-run" in sys.argv
    for network, routers in sorted(listen().items()):
        now = current(network)
        if now in routers:
            print(network, "stays on", now, "of", len(routers))
            continue
        print(network, "was", now, "now", routers[0])
        if not dry:
            subprocess.run(["ip", "-6", "route", "replace", network, "via", routers[0], "dev", INTERFACE], check=True)


if __name__ == "__main__":
    main()
