# ms-office Skill

_Reference for creating, editing, reading, and converting MS Office files._

---

## Tools Available

| Task | Tool | Command |
|------|------|---------|
| markdown → .docx | pandoc | `pandoc input.md -o output.docx` |
| markdown → .pptx | pandoc | `pandoc input.md -o output.pptx` |
| markdown → .pdf | pandoc+xelatex | `pandoc input.md -o output.pdf --pdf-engine=xelatex` |
| .docx/.xlsx/.pptx → markdown | markitdown | See below |
| Programmatic .docx | python-docx | `python3 script.py` |
| Programmatic .xlsx | openpyxl | `python3 script.py` |
| Programmatic .pptx | python-pptx | `python3 script.py` |

---

## Creating Office Files

### Preferred Pattern — Write Markdown, Convert with Pandoc

**Word document:**
```bash
pandoc report.md -o report.docx
```

**Word with branding (custom template):**
```bash
pandoc report.md --reference-doc=template.docx -o report.docx
```

**PowerPoint:**
```bash
pandoc slides.md -o slides.pptx
```

**PDF:**
```bash
pandoc report.md -o report.pdf --pdf-engine=xelatex
```

### PPTX Slide Structure

Each H2 heading (`##`) becomes a new slide:

```markdown
# Deck Title

## Slide One
- Bullet one
- Bullet two

## Slide Two
Content here
```

---

## Reading Office Files

### Using markitdown

```python
from markitdown import MarkItDown

result = MarkItDown().convert("document.docx")
print(result.text_content)
```

### Using pandoc

```bash
pandoc input.docx -o output.md --track-changes=all
```

---

## Programmatic Editing

Use when you need precise control over an existing file.

### Word (.docx) with python-docx

```python
from docx import Document

doc = Document('existing.docx')
doc.add_heading('New Section', 1)
doc.add_paragraph('Content')
doc.save('updated.docx')
```

### Excel (.xlsx) with openpyxl

```python
from openpyxl import load_workbook

wb = load_workbook('data.xlsx')
ws = wb.active
ws['A1'] = 'New Value'
wb.save('updated.xlsx')
```

### PowerPoint (.pptx) with python-pptx

```python
from pptx import Presentation

prs = Presentation('template.pptx')
slide = prs.slides.add_slide(prs.slide_layouts[1])
title = slide.shapes.title
title.text = "New Slide"
prs.save('updated.pptx')
```

---

## Rules

| ❌ Never Do | ✅ Instead |
|------------|-----------|
| Install LibreOffice | Use pandoc+xelatex — lighter and correct |
| Edit .docx XML directly | Use python-docx high-level library |
| Use python-pptx for markdown-to-pptx | Use pandoc — handles this natively |
| Assume pandoc is not installed | Verify with `which pandoc` |
| Forget --pdf-engine=xelatex for PDFs | Required for proper rendering |

---

## Quick-Reference

```bash
# Create Word doc
pandoc input.md -o output.docx

# Create Word with template
pandoc input.md --reference-doc=template.docx -o output.docx

# Create PowerPoint
pandoc slides.md -o slides.pptx

# Create PDF
pandoc input.md -o output.pdf --pdf-engine=xelatex

# Convert docx to markdown
pandoc input.docx -o output.md

# Read docx programmatically
python3 -c "from markitdown import MarkItDown; print(MarkItDown().convert('doc.docx').text_content)"
```

---

_Remember: Markdown → Pandoc is the preferred path. Programmatic libraries only when you need precise control over existing files._
