#!/usr/bin/env python3
"""Return a selected node's IPv4 address for OpenTofu's external provider."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from typing import Any


def normalized(value: str) -> str:
    return value.casefold().removesuffix(".")


def matches(node: dict[str, Any], selector: str) -> bool:
    wanted = normalized(selector)
    hostname = normalized(str(node.get("HostName", "")))
    dns_name = normalized(str(node.get("DNSName", "")))
    dns_short_name = dns_name.split(".", 1)[0]
    return wanted in {hostname, dns_name, dns_short_name}


def selected_nodes(status: dict[str, Any], selector: str) -> list[dict[str, Any]]:
    nodes: list[dict[str, Any]] = []
    self_node = status.get("Self")
    if isinstance(self_node, dict) and matches(self_node, selector):
        nodes.append(self_node)

    peers = status.get("Peer", {})
    if isinstance(peers, dict):
        nodes.extend(
            peer
            for peer in peers.values()
            if isinstance(peer, dict) and matches(peer, selector)
        )
    return nodes


def find_ipv4(status: dict[str, Any], selector: str) -> str:
    for node in selected_nodes(status, selector):
        for address in node.get("TailscaleIPs", []):
            if isinstance(address, str) and address.count(".") == 3:
                return address
    raise RuntimeError(f"Tailscale node not found or has no IPv4 address: {selector}")


def read_status() -> dict[str, Any]:
    override = os.environ.get("TAILSCALE_STATUS_JSON")
    if override:
        return json.loads(override)

    result = subprocess.run(
        ["tailscale", "status", "--json"],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def main() -> None:
    query = json.load(sys.stdin)
    selector = query["selector"]
    print(json.dumps({"ipv4": find_ipv4(read_status(), selector)}))


if __name__ == "__main__":
    main()
