---
name: read-xlsx
description: >
  Extract and convert Excel files (.xlsx, .xls, .xlsm) to structured markdown.
  Reads ALL sheets in the workbook. Each sheet becomes a separate section.
  Output: docs/extracted/[filename].md — ready for qa-checklist-interpreter
  or any agent that needs tabular data from spreadsheets.
allowed-tools: Bash, Read, Write
---

# Read Excel → Markdown

Converts any Excel file to structured markdown, preserving all sheets and table structure.

## When to Use
- QA checklist pipeline receives an `.xlsx` file with test cases
- Brief contains Excel attachments with requirements or data
- Any agent needs to read tabular data from a spreadsheet

## Process

### Step 1: Detect Sheets

```bash
# Method 1: openpyxl (preferred)
/usr/bin/python3 -c "
import openpyxl
wb = openpyxl.load_workbook('INPUT_FILE', data_only=True)
for name in wb.sheetnames:
    ws = wb[name]
    print(f'{name} ({ws.max_row} rows x {ws.max_column} cols)')
"
```

If openpyxl is not available:
```bash
# Method 2: ssconvert (gnumeric) — list sheets
ssconvert --list-sheets "INPUT_FILE" 2>/dev/null

# Method 3: libreoffice
libreoffice --headless --calc --convert-to csv:"Text - txt - csv (StarCalc)":44,34,76,1 "INPUT_FILE" --outdir /tmp/xlsx_extract/ 2>/dev/null
```

### Step 2: Extract ALL Sheets to Markdown

```bash
mkdir -p docs/extracted

/usr/bin/python3 << 'PYEOF'
import openpyxl
import sys
import os

input_file = "INPUT_FILE"
basename = os.path.splitext(os.path.basename(input_file))[0]
output_file = f"docs/extracted/{basename}.md"

wb = openpyxl.load_workbook(input_file, data_only=True)

with open(output_file, 'w') as out:
    out.write(f"# Extracted: {basename}\n")
    out.write(f"Source: `{input_file}`\n")
    out.write(f"Sheets: {len(wb.sheetnames)}\n\n")
    out.write("---\n\n")

    for sheet_name in wb.sheetnames:
        ws = wb[sheet_name]
        out.write(f"## Sheet: {sheet_name}\n\n")

        rows = list(ws.iter_rows(values_only=True))
        if not rows:
            out.write("*(empty sheet)*\n\n")
            continue

        # Find actual data bounds (skip fully empty rows)
        data_rows = []
        for row in rows:
            if any(cell is not None for cell in row):
                data_rows.append(row)

        if not data_rows:
            out.write("*(empty sheet)*\n\n")
            continue

        # First non-empty row is header
        headers = data_rows[0]
        max_cols = len(headers)

        # Write header row
        header_cells = [str(h) if h is not None else "" for h in headers]
        out.write("| " + " | ".join(header_cells) + " |\n")
        out.write("| " + " | ".join(["---"] * max_cols) + " |\n")

        # Write data rows
        for row in data_rows[1:]:
            cells = []
            for i, cell in enumerate(row[:max_cols]):
                val = str(cell) if cell is not None else ""
                # Escape pipe characters in cell values
                val = val.replace("|", "\\|")
                # Truncate very long cells
                if len(val) > 200:
                    val = val[:197] + "..."
                cells.append(val)
            # Pad if row has fewer columns than header
            while len(cells) < max_cols:
                cells.append("")
            out.write("| " + " | ".join(cells) + " |\n")

        out.write(f"\n*({len(data_rows)-1} data rows)*\n\n")

print(f"Extracted to: {output_file}")
print(f"Sheets: {len(wb.sheetnames)}")
for name in wb.sheetnames:
    ws = wb[name]
    print(f"  - {name}: {ws.max_row} rows x {ws.max_column} cols")
PYEOF
```

### Step 3: Fallback if openpyxl Unavailable

```bash
# Try installing openpyxl first
pip install openpyxl 2>/dev/null || pip3 install openpyxl 2>/dev/null

# If still unavailable, use ssconvert (gnumeric)
if ! /usr/bin/python3 -c "import openpyxl" 2>/dev/null; then
  echo "openpyxl not available, trying ssconvert..."

  mkdir -p /tmp/xlsx_sheets
  SHEET_COUNT=$(ssconvert --list-sheets "INPUT_FILE" 2>/dev/null | wc -l)

  for i in $(seq 0 $((SHEET_COUNT - 1))); do
    ssconvert --export-type=Gnumeric_stf:stf_csv \
      --export-file-per-sheet "INPUT_FILE" "/tmp/xlsx_sheets/sheet_%d.csv" 2>/dev/null
  done

  # Convert CSVs to markdown
  mkdir -p docs/extracted
  BASENAME=$(basename "INPUT_FILE" .xlsx)
  OUTPUT="docs/extracted/${BASENAME}.md"

  echo "# Extracted: $BASENAME" > "$OUTPUT"
  for csv in /tmp/xlsx_sheets/sheet_*.csv; do
    SHEET_NAME=$(basename "$csv" .csv)
    echo "" >> "$OUTPUT"
    echo "## Sheet: $SHEET_NAME" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    # Convert CSV to markdown table
    head -1 "$csv" | sed 's/,/ | /g; s/^/| /; s/$/ |/' >> "$OUTPUT"
    head -1 "$csv" | sed 's/[^,]*/ --- /g; s/,/|/g; s/^/|/; s/$/|/' >> "$OUTPUT"
    tail -n +2 "$csv" | sed 's/,/ | /g; s/^/| /; s/$/ |/' >> "$OUTPUT"
  done

  rm -rf /tmp/xlsx_sheets
fi
```

### Step 4: Verify Output

```bash
# Check output exists and has content
OUTPUT_FILE="docs/extracted/[basename].md"
wc -l "$OUTPUT_FILE"
head -30 "$OUTPUT_FILE"
```

## Output Format

```markdown
# Extracted: [filename]
Source: `briefs/test-cases.xlsx`
Sheets: 3

---

## Sheet: Test Cases
| TC ID | Description | Input | Expected Result | Priority |
| --- | --- | --- | --- | --- |
| TC-001 | Login valid user | admin/pass123 | Dashboard displayed | critical |
| TC-002 | Login invalid | wrong/wrong | Error message shown | high |

*(25 data rows)*

## Sheet: Test Data
| User | Password | Role |
| --- | --- | --- |
| admin | pass123 | administrator |
| user1 | test456 | viewer |

*(10 data rows)*

## Sheet: Config
| Key | Value |
| --- | --- |
| base_url | http://localhost:3000 |
| api_url | http://localhost:8000/api |

*(5 data rows)*
```

## Integration with QA Pipeline

When called from `qa-checklist-interpreter`:
1. Interpreter detects `.xlsx` extension
2. Calls this skill to convert → `docs/extracted/[name].md`
3. Interpreter reads the markdown output
4. Detects format type (usually `scenario_table`)
5. Normalizes to standardized checklist format

## CSV Support

This skill also handles `.csv` files:
```bash
# CSV is simpler — single sheet, direct conversion
BASENAME=$(basename "INPUT_FILE" .csv)
OUTPUT="docs/extracted/${BASENAME}.md"

echo "# Extracted: $BASENAME" > "$OUTPUT"
echo "" >> "$OUTPUT"
echo "## Sheet: Data" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Header
head -1 "INPUT_FILE" | sed 's/,/ | /g; s/^/| /; s/$/ |/' >> "$OUTPUT"
head -1 "INPUT_FILE" | sed 's/[^,]*/ --- /g; s/,/|/g; s/^/|/; s/$/|/' >> "$OUTPUT"

# Data
tail -n +2 "INPUT_FILE" | sed 's/,/ | /g; s/^/| /; s/$/ |/' >> "$OUTPUT"
```
