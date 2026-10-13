"""Shared local state for safe repository/OpenFlow profile reconciliation."""

from __future__ import annotations

import fcntl
import hashlib
import json
import os
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

STATE_VERSION = 1
STATE_FILENAME = "repository-profiles.json"


def state_dir() -> Path:
    configured = os.environ.get("OPENFLOW_PROFILE_SYNC_STATE_DIR")
    if configured:
        return Path(configured).expanduser()
    return Path.home() / "Library/Application Support/OpenFlowSettingsSync"


@contextmanager
def sync_lock() -> Iterator[None]:
    directory = state_dir()
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    lock_path = directory / "sync.lock"
    with lock_path.open("a", encoding="utf-8") as lock:
        os.chmod(lock_path, 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def read_state() -> dict[str, Any]:
    path = state_dir() / STATE_FILENAME
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {"version": STATE_VERSION, "profiles": {}}
    except (OSError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"Cannot read OpenFlow sync state {path}: {exc}") from exc
    if (not isinstance(data, dict) or data.get("version") != STATE_VERSION
            or not isinstance(data.get("profiles"), dict)):
        raise RuntimeError(f"OpenFlow sync state has an unsupported format: {path}")
    return data


def write_state(data: dict[str, Any]) -> None:
    if data.get("version") != STATE_VERSION or not isinstance(data.get("profiles"), dict):
        raise RuntimeError("Refusing to write malformed OpenFlow sync state")
    directory = state_dir()
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    path = directory / STATE_FILENAME
    fd, temporary = tempfile.mkstemp(prefix=".repository-profiles.", dir=directory)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(data, stream, ensure_ascii=False, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def id_map(data: dict[str, Any]) -> dict[str, str]:
    result: dict[str, str] = {}
    for layer in data.get("layers", []):
        identity = layer.get("srcId")
        if identity:
            result[str(identity)] = f"layer:{layer.get('orderId')}:{layer.get('name')}"
    modules = data.get("modules") or {}
    for config in modules.get("configs", []):
        identity = config.get("srcId") or config.get("id")
        if identity:
            result[str(identity)] = f"config:{config.get('type')}:{config.get('orderId')}:{config.get('name')}"
    for index, macro in enumerate(data.get("macros", [])):
        identity = macro.get("srcId") or macro.get("id")
        if identity:
            result[str(identity)] = f"macro:{macro.get('orderId', index)}:{macro.get('name')}"
    return result


def semantic_profile(data: dict[str, Any]) -> Any:
    """Ignore regenerated IDs and serialization order, but preserve profile settings."""
    replacements = id_map(data)

    def replace(value: Any) -> Any:
        if isinstance(value, str):
            for old, stable in replacements.items():
                value = value.replace(old, stable)
            return value
        if isinstance(value, list):
            return [replace(item) for item in value]
        if isinstance(value, dict):
            return {key: replace(item) for key, item in value.items()}
        return value

    result = replace(data)
    modules = result.get("modules")
    if isinstance(modules, dict):
        configs = modules.get("configs")
        if isinstance(configs, list):
            for config in configs:
                for key, sort_key in (
                    ("settings", lambda item: (str(item.get("correlation_id", "")), json.dumps(item, sort_keys=True))),
                    ("bindings", lambda item: (str(item.get("behavior", "")), json.dumps(item, sort_keys=True))),
                ):
                    entries = config.get(key)
                    if isinstance(entries, list):
                        config[key] = sorted(entries, key=sort_key)
            modules["configs"] = sorted(
                configs,
                key=lambda item: (str(item.get("type", "")), str(item.get("orderId", "")), str(item.get("name", ""))),
            )
        bindings = modules.get("configBindings")
        if isinstance(bindings, list):
            modules["configBindings"] = sorted(
                bindings,
                key=lambda item: (
                    str(item.get("bindingLocation", "")), str(item.get("state") or ""),
                    str(item.get("srcLayerId") or ""), str(item.get("srcConfigId") or ""),
                ),
            )
    profile = result.get("profile")
    if isinstance(profile, dict):
        profile.pop("name", None)
    return result


def profile_digest(data: dict[str, Any]) -> str:
    canonical = json.dumps(semantic_profile(data), ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def direction(source_digest: str, live_digest: str, baseline_digest: str | None) -> str:
    """Choose a safe sync direction; divergent edits are a conflict, never last-writer-wins."""
    if source_digest == live_digest:
        return "match"
    if baseline_digest is None:
        return "unmanaged"
    source_changed = source_digest != baseline_digest
    live_changed = live_digest != baseline_digest
    if source_changed and live_changed:
        return "conflict"
    if source_changed:
        return "repository"
    if live_changed:
        return "openflow"
    return "match"
