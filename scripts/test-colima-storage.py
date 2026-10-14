#!/usr/bin/env python3
"""Verify the fully managed Colima profile's storage and daemon policy."""

import subprocess
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
PROFILE = ROOT / "dot_colima/default/colima.yaml"


def render() -> dict[str, object]:
    result = subprocess.run(
        ["chezmoi", "execute-template", "-S", str(ROOT), "--file", str(PROFILE)],
        check=True,
        capture_output=True,
        text=True,
    )
    return yaml.safe_load(result.stdout)


class ColimaStoragePolicyTest(unittest.TestCase):
    def test_managed_profile_preserves_vm_settings_and_bounds_build_cache(self):
        profile = render()
        self.assertEqual(64, profile["disk"])
        self.assertEqual(4, profile["memory"])
        self.assertEqual("aarch64", profile["arch"])
        self.assertEqual("docker", profile["runtime"])
        self.assertFalse(profile["autoActivate"])
        self.assertEqual("vz", profile["vmType"])
        self.assertEqual(
            {"enabled": True, "defaultKeepStorage": "4GB"},
            profile["docker"]["builder"]["gc"],
        )

    def test_complete_profile_keeps_existing_network_and_kubernetes_preferences(self):
        profile = render()
        self.assertEqual(
            {
                "address": False,
                "dns": None,
                "dnsHosts": {},
                "gatewayAddress": "192.168.5.2",
                "hostAddresses": False,
                "interface": "en0",
                "mode": "shared",
                "preferredRoute": False,
            },
            profile["network"],
        )
        self.assertEqual(
            {
                "enabled": False,
                "k3sArgs": ["--disable=traefik"],
                "port": 0,
                "version": "v1.35.0+k3s1",
            },
            profile["kubernetes"],
        )


if __name__ == "__main__":
    unittest.main()
