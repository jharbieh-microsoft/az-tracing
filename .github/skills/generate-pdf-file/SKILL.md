---
name: generate-pdf-file
description: 'Generate PDF files from markdown, plain text, or HTML inputs for reports and runbooks - Brought to you by jharbieh/az-tracing'
---
# Generate PDF File

## Overview
Use this skill when you need to create a PDF document from markdown, plain text, or HTML content in this repository. This is useful for exporting architecture summaries, implementation plans, handoff notes, and operational runbooks.

## Prerequisites
- Python 3.10 or later.
- Install required packages:
  - `pip install reportlab markdown`
- Source file exists and output directory is writable.

## Quick Start
1. Choose input and output paths.
2. Run one of the wrappers:
   - Bash:
     `scripts/generate.sh --input ./IMPLEMENTATION_PLAN.md --output ./out/IMPLEMENTATION_PLAN.pdf --title "Implementation Plan"`
   - PowerShell:
     `scripts/generate.ps1 -InputPath ./IMPLEMENTATION_PLAN.md -OutputPath ./out/IMPLEMENTATION_PLAN.pdf -Title "Implementation Plan"`
3. Verify the generated file at the output path.

## Parameters Reference
| Parameter | Required | Default | Description |
|---|---|---|---|
| `input` / `InputPath` | Yes | None | Path to source file (`.md`, `.txt`, `.html`, `.htm`). |
| `output` / `OutputPath` | Yes | None | Path to destination PDF file. |
| `title` / `Title` | No | Input file name | Document title rendered in PDF header. |
| `font-size` / `FontSize` | No | `11` | Body font size in points. |
| `line-spacing` / `LineSpacing` | No | `1.3` | Multiplier for body line spacing. |

## Script Reference
- Bash command:

```bash
scripts/generate.sh --input ./README.md --output ./out/README.pdf --title "Project Overview"
```

- PowerShell command:

```powershell
scripts/generate.ps1 -InputPath ./README.md -OutputPath ./out/README.pdf -Title "Project Overview"
```

## Troubleshooting
- `ModuleNotFoundError`: install dependencies with `pip install reportlab markdown`.
- Empty output file: verify input content is not empty and output path is valid.
- Unsupported extension: use `.md`, `.txt`, `.html`, or `.htm`.

## Attribution
> Brought to you by jharbieh/az-tracing
