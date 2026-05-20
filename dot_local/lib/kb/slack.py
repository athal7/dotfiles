"""Slack API helpers."""
import json, subprocess, urllib.parse, urllib.request
from kb.util import log

SLACK_API = "https://slack.com/api/"


def get_slack_token():
    try:
        result = subprocess.run(
            ["security", "find-generic-password", "-s", "chezmoi", "-a", "slack_user_token", "-w"],
            capture_output=True, text=True, timeout=5)
        return result.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return ""


def slack_api(method, token, params=None, log_prefix="kb-enrich"):
    """Call a Slack Web API method. Returns parsed JSON or None on error."""
    url = SLACK_API + method
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        resp = urllib.request.urlopen(req, timeout=30)
        data = json.loads(resp.read())
        if not data.get("ok"):
            log(f"Slack API {method} error: {data.get('error', 'unknown')}", prefix=log_prefix)
            return None
        return data
    except Exception as e:
        log(f"Slack API {method} failed: {e}", prefix=log_prefix)
        return None
