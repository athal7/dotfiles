# Atlassian (Confluence + Jira)

Confluence is a collector input and an approval-gated publication target. Query CQ for normal context. Use KB when CQ has no answer or projection verification is incomplete.

`/kb-enrich` uses configured Confluence and Jira collectors. Use `searchConfluenceUsingCql` for the configured space and window, then `getConfluencePage` for source content. Use page-tree calls only for the collector's hygiene scan.

For an explicit current Confluence or Jira request, use `search` to locate unknown content, then `fetch`, `getConfluencePage`, or `getJiraIssue` as applicable. When a request names a Jira issue, retrieve that issue before other work. Cite page titles or issue keys. Never paste storage-format bodies or full issue JSON.

Do not exclude Decision Log pages by label. Skip a page only when its stable page identity and normalized content fingerprint exactly match a KB write-back ledger entry. A labeled page without that exact provenance is independently authored source material.

Before any Confluence or Jira write, show the target, complete content, source identity, and linked CQ KU when one exists. Stop until the user gives explicit approval.
