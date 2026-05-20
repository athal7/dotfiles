"""GitHub API helpers via gh CLI."""
import json, subprocess
from kb.util import log


def fetch_org_repos(org, log_prefix="kb-enrich"):
    """Fetch all repos for a GitHub org via gh CLI. Returns list of {name, url, description}."""
    try:
        result = subprocess.run(
            ["gh", "repo", "list", org, "--limit", "200", "--json", "name,url,description"],
            capture_output=True, text=True, timeout=30)
        if result.returncode != 0:
            log(f"gh repo list failed: {result.stderr.strip()}", prefix=log_prefix)
            return []
        return json.loads(result.stdout)
    except (FileNotFoundError, subprocess.TimeoutExpired, json.JSONDecodeError) as e:
        log(f"GitHub fetch failed: {e}", prefix=log_prefix)
        return []
