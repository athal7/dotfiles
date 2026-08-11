Every change is tracked — no exemptions. The issue id anchors the branch name, the proposal, and the commit.

Request underspecified (missing who/why/what-success, or you're about to silently fill in a gap) and a live human is present? Load `interview-me` before drafting anything — one question at a time, skip it entirely in unattended/autonomous dispatch.

Resolve the tracker for the repo's org:

```sh
ORG=$(git remote get-url origin | sed -E 's#.*[:/]([^/]+)/[^/]+(\.git)?$#\1#')
chezmoi data --format json | jq -r ".orgs[\"$ORG\"].issues // empty"
```

`linear` → Linear; anything else, including empty → GitHub Issues.

| Situation | Do |
|---|---|
| Request names an issue | Fetch it |
| No reference | Search the tracker by keyword for existing open or recently-closed work. Clear match → confirm before adopting |
| No match | Draft title + short what/why, show it in full, create it |
| Tracking disabled entirely | Flag it, ask whether to proceed untracked |

Set it **In Progress** before any code work.

Ends with: a tracked issue, In Progress.
