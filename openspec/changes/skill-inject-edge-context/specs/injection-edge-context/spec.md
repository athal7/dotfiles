### ADDED Requirement: Config accepts object entries with context

The skill-inject plugin config SHALL accept array entries as either a plain string (skill name) or an object with `skill` (string) and `context` (string) fields. Plain string entries SHALL behave identically to current behavior.

#### Scenario: Plain string entry renders description

- WHEN config has a plain string entry like `"xh"`
- THEN the injection footer renders `- load \`xh\` skill (<description from frontmatter>)` — identical to current behavior

#### Scenario: Object entry renders context hint

- WHEN config has an object entry like `{"skill": "xh", "context": "Use --session=agent for auth"}`
- THEN the injection footer renders `- load \`xh\` skill — Use --session=agent for auth`

#### Scenario: Mixed string and object entries

- WHEN config has a mix of strings and objects
- THEN each entry renders according to its type

### ADDED Requirement: Context replaces description in footer

When an injection entry includes a `context` field, the footer line SHALL use the context text instead of the skill's frontmatter description. The description SHALL NOT be appended alongside the context.

#### Scenario: Object entry omits description

- WHEN an object entry has context `"All requests use xh --session=agent for auth"`
- THEN footer shows `- load \`xh\` skill — All requests use xh --session=agent for auth` (no parenthesized description)

#### Scenario: Plain string entry shows description

- WHEN a plain string entry is used
- THEN footer shows the description in parentheses as before

### ADDED Requirement: inject_list tool shows context hints

The `inject_list` tool SHALL display context hints for object entries alongside the skill names.

#### Scenario: inject_list with object entries

- WHEN `inject_list` is called and config has object entries
- THEN the output includes the context text for those entries
