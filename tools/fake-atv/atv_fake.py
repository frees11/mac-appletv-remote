#!/usr/bin/env python3
"""Fake Apple TV with real App Store app list, for developing a macOS remote."""
import argparse
import asyncio
from ipaddress import IPv4Address
import json
import logging
import os
import sys
import urllib.parse
import urllib.request

# tests.fake_device does not ship in the pyatv wheel, so the sources are needed.
# setup.sh clones them next to this script.
PYATV_ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".pyatv")
if not os.path.isdir(PYATV_ROOT):
    raise SystemExit(f"pyatv sources missing at {PYATV_ROOT} — run tools/fake-atv/setup.sh")
sys.path.insert(0, PYATV_ROOT)

import ifaddr  # noqa: E402
from zeroconf import Zeroconf  # noqa: E402

from pyatv.const import Protocol  # noqa: E402
from pyatv.core import mdns  # noqa: E402
from pyatv.protocols.companion.api import SystemStatus  # noqa: E402

from tests.fake_device import FakeAppleTV  # noqa: E402
from tests.fake_device.companion import FakeCompanionService  # noqa: E402

_LOGGER = logging.getLogger(__name__)


def _patch_rti_cleanup():
    """Reset RTI state when a Companion client disconnects.

    FakeCompanionService.connection_lost keeps rti_clients/rti_session_uuid
    forever, so one client that dies without sending _tiStop (crash, killed
    process) makes every later _tiStart fail with "RTI session already
    started" — and pyatv then aborts the whole connect.
    """
    original = FakeCompanionService.connection_lost

    def connection_lost(self, exc):
        if self in self.state.rti_clients:
            self.state.rti_clients.remove(self)
            if not self.state.rti_clients:
                self.state.rti_session_uuid = None
        original(self, exc)

    FakeCompanionService.connection_lost = connection_lost


_patch_rti_cleanup()

DEVICE_NAME = "FakeATV"
AIRPLAY_IDENTIFIER = "4D797FD3-3538-427E-A47B-A32FC6CF3A6A"
SERVER_IDENTIFIER = "6D797FD3-3538-427E-A47B-A32FC6CF3A69"
MODEL = "AppleTV6,2"

# Build version drives how pyatv reaches MediaRemote. On tvOS 15+ builds MRP is
# only reachable through the AirPlay tunnel, and the fake AirPlay service cannot
# complete pair-setup (it replays recorded legacy device-auth bytes), so
# now-playing stays dead. The tvOS 13 build keeps direct MRP working.
BUILD_MRP_DIRECT = "17K499"
BUILD_TVOS_26 = "23L471"

INSTALLED_APPS = {
    "com.netflix.Netflix": "Netflix",
    "com.google.ios.youtube": "YouTube",
    "com.disney.disneyplus": "Disney+",
    "com.apple.TVWatchList": "Apple TV",
    "com.apple.TVMusic": "Music",
    "com.spotify.client": "Spotify",
    "com.apple.TVSettings": "Settings",
}

ITUNES_LOOKUP = "https://itunes.apple.com/lookup"


def local_ip(nic_name: str) -> str:
    """IPv4 address of the given interface.

    The default route may point at a VPN (ppp0), so the interface is chosen
    explicitly — Apple TVs only see services published on the LAN interface.
    """
    for adapter in ifaddr.get_adapters():
        if adapter.nice_name != nic_name:
            continue
        for ip in adapter.ips:
            if ip.is_IPv4:
                return ip.ip
    raise SystemExit(f"no IPv4 address on interface {nic_name!r}")


def fetch_icon_urls(bundle_ids):
    """Resolve App Store artwork URLs for bundle identifiers."""
    query = urllib.parse.urlencode(
        {"bundleId": ",".join(bundle_ids), "entity": "software", "limit": 200}
    )
    with urllib.request.urlopen(f"{ITUNES_LOOKUP}?{query}", timeout=15) as response:
        payload = json.load(response)
    return {
        item["bundleId"]: item.get("artworkUrl512") or item.get("artworkUrl100")
        for item in payload.get("results", [])
        if item.get("bundleId")
    }


async def alter_playing(usecase):
    """Cycle now-playing state so clients see it change."""
    while True:
        try:
            usecase.example_video()
            await asyncio.sleep(5)
            usecase.example_music()
            await asyncio.sleep(5)
            usecase.nothing_playing()
            await asyncio.sleep(5)
        except asyncio.CancelledError:
            break
        except Exception:  # pylint: disable=broad-except
            _LOGGER.exception("Exception in playing loop")


async def publish(loop, zconf, service_type, address, port, props):
    """Publish one Bonjour service."""
    return await mdns.publish(
        loop,
        mdns.Service(
            service_type, DEVICE_NAME, IPv4Address(address), port, props
        ),
        zconf,
    )


def companion_props():
    """Bonjour TXT record mimicking a real Apple TV."""
    return {
        "rpMac": "2",
        "rpHN": "70f6e2e93f8a",
        "rpFl": "0x36782",
        "rpHA": "b03d30c603cf",
        "rpMd": MODEL,
        "rpVr": "715.2",
        "rpAD": "8177d658a620",
        "rpHI": "aad2be284a4b",
        "rpBA": "69:E5:F8:EC:4E:EB",
        "rpMRtID": SERVER_IDENTIFIER,
    }


def airplay_props():
    """Bonjour TXT record for the AirPlay service.

    features/flags/srcvers must stay on the values the fake AirPlay service
    actually implements — real tvOS 26.5 flags advertise a pairing flow it
    does not serve, and pair-setup then fails with HTTP 500.
    """
    return {
        "deviceid": "40:CB:C0:12:34:56",
        "features": "0x5A7FFFF7,0xE",
        "flags": "0x44",
        "model": MODEL,
        "vv": "2",
        "srcvers": "220.68",
        "pi": "4EE5AF58-7E5D-465A-935E-82E4DB74385D",
        "psi": SERVER_IDENTIFIER,
        "pk": "3853c0e2ce3844727ca0cb1b86a3e3875e66924d2648d8f8caf71f8118793d98",
    }


def mrp_props(build_version):
    """Bonjour TXT record for the MRP service."""
    return {
        "ModelName": "Apple TV",
        "AllowPairing": "YES",
        "macAddress": "40:cb:c0:12:34:56",
        "BluetoothAddress": False,
        "Name": DEVICE_NAME,
        "UniqueIdentifier": SERVER_IDENTIFIER,
        "SystemBuildVersion": build_version,
        "LocalAirPlayReceiverPairingIdentity": AIRPLAY_IDENTIFIER,
    }


async def appstore_icon_report(apps):
    """Print App Store artwork URLs resolved for the fake app list."""
    loop = asyncio.get_running_loop()
    try:
        icons = await loop.run_in_executor(None, fetch_icon_urls, list(apps))
    except Exception as ex:  # pylint: disable=broad-except
        _LOGGER.warning("App Store icon lookup failed: %s", ex)
        return
    for bundle_id, name in apps.items():
        url = icons.get(bundle_id)
        print(f"  {name:<12} {bundle_id:<28} {url or '(no App Store match)'}")


async def main():
    """Start the fake device and keep it published until ENTER."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--local-ip", default=None, help="LAN IP to publish on")
    parser.add_argument(
        "--interface", default="en0", help="interface to take the IP from"
    )
    parser.add_argument("--demo", action="store_true", help="cycle now playing state")
    parser.add_argument(
        "--daemon",
        action="store_true",
        help="run until interrupted instead of waiting for ENTER",
    )
    parser.add_argument(
        "--tvos26-identity",
        action="store_true",
        help="advertise a tvOS 26.5 build; realistic, but kills now-playing",
    )
    parser.add_argument("-d", "--debug", action="store_true", help="debug logs")
    parser.add_argument(
        "--status",
        default="Awake",
        choices=[s.name for s in SystemStatus],
        help="reported system status",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.INFO,
        stream=sys.stdout,
        datefmt="%Y-%m-%d %H:%M:%S",
        format="%(asctime)s %(levelname)s: %(message)s",
    )

    address = args.local_ip or local_ip(args.interface)
    loop = asyncio.get_running_loop()
    zconf = Zeroconf(interfaces=[address])
    atv = FakeAppleTV(loop, test_mode=False)

    _, mrp_usecase = atv.add_service(Protocol.MRP)
    atv.add_service(Protocol.AirPlay)
    _, companion_usecase = atv.add_service(Protocol.Companion)

    companion_usecase.set_installed_apps(INSTALLED_APPS)
    companion_usecase.set_system_status(SystemStatus[args.status])

    await atv.start()

    unpublishers = [
        await publish(
            loop,
            zconf,
            "_mediaremotetv._tcp.local",
            address,
            atv.get_port(Protocol.MRP),
            mrp_props(
                BUILD_TVOS_26 if args.tvos26_identity else BUILD_MRP_DIRECT
            ),
        ),
        await publish(
            loop,
            zconf,
            "_airplay._tcp.local",
            address,
            atv.get_port(Protocol.AirPlay),
            airplay_props(),
        ),
        await publish(
            loop,
            zconf,
            "_companion-link._tcp.local",
            address,
            atv.get_port(Protocol.Companion),
            companion_props(),
        ),
    ]

    tasks = []
    if args.demo:
        tasks.append(asyncio.ensure_future(alter_playing(mrp_usecase)))

    print(f"\n{DEVICE_NAME} ({MODEL}) published on {address}")
    print(f"  companion :{atv.get_port(Protocol.Companion)}")
    print(f"  airplay   :{atv.get_port(Protocol.AirPlay)}")
    print(f"  mrp       :{atv.get_port(Protocol.MRP)}")
    print(f"  status    {args.status}")
    print("  pairing PIN 1111\n")
    print("Installed apps (icons from the real App Store):")
    await appstore_icon_report(INSTALLED_APPS)

    if args.daemon:
        print("\nRunning until interrupted (Ctrl-C)")
        try:
            await asyncio.Event().wait()
        except asyncio.CancelledError:
            pass
    else:
        print("\nPress ENTER to quit")
        await loop.run_in_executor(None, sys.stdin.readline)

    for task in tasks:
        task.cancel()
    for unpublisher in unpublishers:
        await unpublisher()
    await atv.stop()


if __name__ == "__main__":
    asyncio.run(main())
