#!/usr/bin/env python3
"""Verify the managed keymap against the preserved, read-only NayaFlow database."""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SNAPSHOT = ROOT / "dot_config/openflow/import/naya-create-profile.db"
PROFILE = ROOT / "dot_config/openflow/profiles/naya-default-macos.json"


def main() -> None:
    data = json.loads(PROFILE.read_text(encoding="utf-8"))
    connection = sqlite3.connect(SNAPSHOT.resolve().as_uri() + "?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    try:
        row = connection.execute(
            "SELECT id FROM profiles WHERE name = ?", (data["profile"]["name"],)
        ).fetchone()
        assert row is not None, "managed profile is absent from the preserved Naya snapshot"
        profile_id = row["id"]

        source_keys: dict[tuple[int, str, int], list[tuple]] = {}
        for item in connection.execute(
            """SELECT l.order_id, l.name, k.position_id, b.behavior, b.action_type,
                      b.action_code, b.context
               FROM layers l JOIN keys k ON k.layer_id = l.id
               LEFT JOIN key_bindings b ON b.key_id = k.id
               WHERE l.profile_id = ? ORDER BY l.order_id, k.position_id""",
            (profile_id,),
        ):
            key = (item["order_id"], item["name"], item["position_id"])
            source_keys.setdefault(key, [])
            if item["behavior"] is not None:
                source_keys[key].append(tuple(item[field] for field in (
                    "behavior", "action_type", "action_code", "context"
                )))
        profile_keys: dict[tuple[int, str, int], list[tuple]] = {}
        for layer in data["layers"]:
            for key in layer["keys"]:
                identity = (layer["orderId"], layer["name"], key["positionId"])
                profile_keys[identity] = [tuple(binding.get(field) for field in (
                    "behavior", "actionType", "actionCode", "context"
                )) for binding in key.get("bindings", [])]
        sort_key = lambda binding: tuple("" if field is None else str(field) for field in binding)
        for mapping in (source_keys, profile_keys):
            for bindings in mapping.values():
                bindings.sort(key=sort_key)
        assert source_keys == profile_keys, "repository key bindings differ from the Naya snapshot"
        assert sum(map(len, source_keys.values())) == 211

        source_assignments = {
            (item["layer_id"], item["module_config_id"], item["binding_location"], item["state"])
            for item in connection.execute(
                "SELECT layer_id,module_config_id,binding_location,state "
                "FROM module_config_bindings WHERE profile_id = ?", (profile_id,)
            )
        }
        profile_assignments = {
            (item["srcLayerId"], item["srcConfigId"], item["bindingLocation"], item["state"])
            for item in data["modules"]["configBindings"]
        }
        assert source_assignments == profile_assignments, "module-to-layer assignments differ from the Naya snapshot"
        assert len(source_assignments) == 10

        configs = {item["name"]: item for item in data["modules"]["configs"]}
        tune = configs["Naya Tune"]["settings"]
        tune_fields = {item["correlation_id"]: (item["value"], item["type"]) for item in tune}
        source_tune = {
            item["correlation_id"]: (item["value"], item["type"])
            for item in connection.execute(
                """SELECT ms.correlation_id,ms.value,ms.type FROM module_settings ms
                   JOIN module_configs mc ON mc.id=ms.module_config_id
                   WHERE mc.name='Naya Tune'"""
            )
        }
        fields = {
            "MS-12": "pointer_speed",
            "MS-14": "MS-14",
            "MS-16": "tick_strength",
            "MS-17": "MS-17",
        }
        assert {fields[key]: value for key, value in source_tune.items()} == tune_fields
        assert tune_fields["MS-14"] == ("20", "numboxSlider")
        assert tune_fields["MS-17"] == ("50", "numboxSlider")

        for config_name in ("Naya Tune", "Naya Touch MacOS"):
            config = configs[config_name]
            original_id = connection.execute(
                "SELECT id FROM module_configs WHERE name = ?", (config_name,)
            ).fetchone()["id"]
            source_bindings = {
                tuple(item[field] for field in (
                    "behavior", "action_type", "action_code", "invert", "threshold", "direction", "mode"
                ))
                for item in connection.execute(
                    """SELECT behavior,action_type,action_code,invert,threshold,direction,mode
                       FROM module_bindings WHERE module_config_id = ?""", (original_id,)
                )
            }
            profile_bindings = {
                tuple(item.get(field) for field in (
                    "behavior", "action_type", "action_code", "invert", "threshold", "direction", "mode"
                ))
                for item in config.get("bindings", [])
            }
            assert source_bindings == profile_bindings, f"{config_name} gestures differ from the Naya snapshot"
    finally:
        connection.close()

    print("PASS: 211 key bindings, 10 module assignments, module gestures, and raw Tune slider values match source")


if __name__ == "__main__":
    main()
