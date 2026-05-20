"""LM Studio helpers."""
import json, os, re, urllib.request
from kb.util import log

LMS_URL = os.environ.get("LMS_URL", "http://127.0.0.1:1234/v1/chat/completions")
LMS_MODEL = os.environ.get("LMS_MODEL", "qwen/qwen3-8b")


def lms_available():
    try:
        urllib.request.urlopen("http://127.0.0.1:1234/v1/models", timeout=2)
        return True
    except Exception:
        return False


def lms_call(messages, max_tokens=2000, timeout=60, log_prefix="kb"):
    """Make a single LM Studio API call. Returns content string or None."""
    payload = json.dumps({
        "model": LMS_MODEL, "messages": messages,
        "temperature": 0.2, "max_tokens": max_tokens,
    }).encode()
    try:
        req = urllib.request.Request(LMS_URL, data=payload, headers={"Content-Type": "application/json"})
        resp = urllib.request.urlopen(req, timeout=timeout)
        data = json.loads(resp.read())
        return data.get("choices", [{}])[0].get("message", {}).get("content", "")
    except Exception as e:
        log(f"WARNING: LM Studio call failed: {e}", prefix=log_prefix)
        return None


def clean_json(text):
    """Strip ```json fences from LLM output."""
    return re.sub(r"^```json\s*|```\s*$", "", text.strip()).strip()
