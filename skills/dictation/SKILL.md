---
name: dictation
description: macOS dictation custom vocabulary — sync knowledge base names and terms to the system spelling dictionary
license: MIT
---

macOS Dictation uses `~/Library/Spelling/LocalDictionary` for custom vocabulary. This plain-text file (one word per line) improves recognition of names, project terms, and domain-specific words that the default speech model wouldn't know.

## Location

- **File**: `~/Library/Spelling/LocalDictionary`
- **Format**: plain text, one word per line, no duplicates
- **Effect**: improves both spellcheck and dictation recognition system-wide

## Syncing from the knowledge base

Extract custom words from the knowledge base and write them to LocalDictionary. Load the knowledge base skill for structure and file locations.

### What to extract

1. **People names** — canonical names from the name mappings. Split into individual words. Focus on unusual surnames and given names the speech model wouldn't recognize (skip common English first names).
2. **Project names** — canonical project names from the project mappings. Include multi-word names as individual words.
3. **Product labels** — product and domain terms from label mappings.
4. **Profile headings** — scan people and project profiles for heading lines to catch names not in the mappings.

### Writing the dictionary

- **Preserve existing entries** — the user may have manually added words
- **One word per line** — multi-word names get split ("Pedram" and "Amini" on separate lines)
- **Skip common English words** — no value in adding "the", "admin", etc.
- **Include unusual terms** — uncommon surnames, project codenames, product-specific terminology
- **Deduplicate** — sort -u before writing
