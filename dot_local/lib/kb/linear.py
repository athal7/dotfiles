"""Linear API helpers."""
import json, subprocess, urllib.request
from kb.util import log

LINEAR_API = "https://api.linear.app/graphql"


def get_linear_token():
    try:
        result = subprocess.run(
            ["security", "find-generic-password", "-s", "chezmoi", "-a", "linear_api_key", "-w"],
            capture_output=True, text=True, timeout=5)
        return result.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return ""


def linear_graphql(query, token, log_prefix="kb-enrich"):
    """Execute a GraphQL query against Linear API. Returns data dict or None."""
    payload = json.dumps({"query": query}).encode()
    req = urllib.request.Request(LINEAR_API, data=payload,
        headers={"Authorization": token, "Content-Type": "application/json"})
    try:
        resp = urllib.request.urlopen(req, timeout=30)
        data = json.loads(resp.read())
        if "errors" in data:
            log(f"Linear API error: {data['errors'][0].get('message', 'unknown')}", prefix=log_prefix)
            return None
        return data.get("data")
    except Exception as e:
        log(f"Linear API failed: {e}", prefix=log_prefix)
        return None


def fetch_all_projects(token, log_prefix="kb-enrich"):
    """Fetch all Linear projects with pagination. Returns list of {name, url, state, labels}."""
    all_projects = []
    has_more = True
    after = None
    while has_more:
        cursor_arg = f', after: "{after}"' if after else ""
        query = (
            f'{{ projects(first: 100{cursor_arg}) {{ pageInfo {{ hasNextPage endCursor }}'
            f' nodes {{ name url state labels {{ nodes {{ name }} }} }} }} }}'
        )
        data = linear_graphql(query, token, log_prefix=log_prefix)
        if not data:
            break
        page = data["projects"]
        for node in page["nodes"]:
            labels_data = node.pop("labels", None)
            node["labels"] = [l["name"] for l in (labels_data or {}).get("nodes", [])]
        all_projects.extend(page["nodes"])
        has_more = page["pageInfo"]["hasNextPage"]
        after = page["pageInfo"]["endCursor"]
    return all_projects
