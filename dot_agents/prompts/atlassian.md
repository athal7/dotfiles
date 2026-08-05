# Atlassian (Confluence + Jira)

Don't know which product holds the answer? Start with `search` — it spans both. `fetch` resolves a specific ARI it returns.

**Confluence** — `searchConfluenceUsingCql`, or `getConfluenceSpaces`/`getPagesInConfluenceSpace` to locate; `getConfluencePage` for the body. Comments (`getConfluencePageFooterComments`, `getConfluencePageInlineComments`, `getConfluenceCommentChildren`) only when the task asks about discussion. `getConfluencePageDescendants` for child pages.

**Jira** — `searchJiraIssuesUsingJql`, or `getJiraIssue` when you already have the key. `getTransitionsForJiraIssue` and `getJiraIssueRemoteIssueLinks` only when asked about workflow state or links.

`getVisibleJiraProjects`, `getJiraProjectIssueTypesMetadata`, `getJiraIssueTypeMetaWithFields`, and `lookupJiraAccountId` exist to build a write call — not for plain reads.

Cite the page title or issue key. Never paste storage-format bodies or full issue JSON.
