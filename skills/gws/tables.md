# Inserting Real Tables in Google Docs

Text-based tables (arrow-delimited) are not proper Google Docs tables. Converting them requires a 4-phase approach executed via `gws docs documents batchUpdate` and `gws docs documents get`.

## Table definition

Before starting, define the tables you need to insert:

- **name** — human label for logging
- **cols** — number of columns
- **headers** — list of header cell strings
- **rows** — list of data rows (each a list of strings)
- **first_line** — unique substring in the first line of the text table (used to find the range to delete)
- **last_line** — unique substring in the last line of the text table

## Phase 1: Delete text + insert empty tables

Work **bottom-to-top** through the document. If you process top-to-bottom, each deletion shifts indices and invalidates subsequent ranges.

For each table (in reverse document order):

1. Read the doc: `gws docs documents get --params '{"documentId":"DOC_ID","fields":"body.content"}'`
2. Walk `body.content` paragraphs to find the `startIndex` of the paragraph containing `first_line` and the `endIndex` of the paragraph containing `last_line`
3. Send a single batchUpdate with two requests:
   ```json
   [
     {"deleteContentRange": {"range": {"startIndex": START, "endIndex": END}}},
     {"insertTable": {"rows": NUM_ROWS, "columns": NUM_COLS, "location": {"index": START}}}
   ]
   ```
   `NUM_ROWS` = data rows + 1 (header row)
4. Re-read the doc before processing the next table — indices shift after each mutation

## Phase 2: Read cell indices + populate cells

After all empty tables are inserted:

1. Read the doc; collect all `table` blocks from `body.content` — they appear in document order (top-to-bottom), matching your table definitions
2. For each table block, walk `tableRows → tableCells` and collect `(cell.startIndex + 1, text)` pairs — `+1` because index 0 of an empty cell is the cell boundary, not the text position
3. Combine all inserts across all tables into one list; **sort descending by index**
4. Send `insertText` requests in batches of ~100:
   ```json
   {"insertText": {"location": {"index": POS}, "text": "cell text"}}
   ```

Sorting descending is critical — inserting text at a lower index shifts all higher indices.

## Phase 3: Style header rows

After population, re-read the doc (indices shifted again after text insertion).

For each table block, process the first row (index 0) of `tableRows`:

**Bold header text** — for each header cell:
```json
{"updateTextStyle": {
  "range": {"startIndex": CELL_START + 1, "endIndex": CELL_END - 1},
  "textStyle": {"bold": true},
  "fields": "bold"
}}
```
Only apply if `CELL_END - CELL_START > 2` (cell has content).

**Background color** — for each header cell:
```json
{"updateTableCellStyle": {
  "tableRange": {
    "tableCellLocation": {
      "tableStartLocation": {"index": TABLE_START_INDEX},
      "rowIndex": 0,
      "columnIndex": COL_INDEX
    },
    "rowSpan": 1,
    "columnSpan": 1
  },
  "tableCellStyle": {
    "backgroundColor": {"color": {"rgbColor": {"red": 0.9, "green": 0.9, "blue": 0.9}}}
  },
  "fields": "backgroundColor"
}}
```

`TABLE_START_INDEX` is `tbl_block.startIndex` (the index of the table element itself, not the first cell).

Send all style requests in a single batchUpdate.

## Key gotchas

- `gws docs documents get` output begins with a "Using keyring backend" line — strip non-JSON prefix lines before parsing
- `tableStartLocation.index` for cell styling is the table element's `startIndex`, not the first cell's index
- Re-read the doc between every phase — indices shift after every mutation
- `gws` rejects `--output` paths outside the current directory
- Batch cell inserts in groups of ~100 to stay under request size limits
