#!/usr/bin/env python3
"""Generate a PDF document from markdown, text, or HTML input."""

from __future__ import annotations

import argparse
import html
from pathlib import Path

from markdown import markdown
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a PDF document from markdown, text, or HTML input."
    )
    parser.add_argument("--input", required=True, help="Path to input file.")
    parser.add_argument("--output", required=True, help="Path to output PDF.")
    parser.add_argument("--title", default=None, help="Optional PDF title.")
    parser.add_argument("--font-size", type=float, default=11.0, help="Body font size.")
    parser.add_argument(
        "--line-spacing",
        type=float,
        default=1.3,
        help="Line spacing multiplier for body text.",
    )
    return parser.parse_args()


def normalize_to_lines(content: str, extension: str) -> list[str]:
    if extension == ".md":
        rendered = markdown(content)
        content = rendered.replace("<br>", "\n").replace("<br/>", "\n").replace("<br />", "\n")
        content = content.replace("</p>", "\n\n").replace("<p>", "")
        content = content.replace("</li>", "\n").replace("<li>", "- ")
        content = content.replace("<h1>", "\n").replace("</h1>", "\n")
        content = content.replace("<h2>", "\n").replace("</h2>", "\n")
        content = content.replace("<h3>", "\n").replace("</h3>", "\n")
        content = content.replace("<strong>", "").replace("</strong>", "")
        content = content.replace("<em>", "").replace("</em>", "")
        content = content.replace("<code>", "").replace("</code>", "")
        content = content.replace("&nbsp;", " ")

    if extension in {".html", ".htm"}:
        content = content.replace("<br>", "\n").replace("<br/>", "\n").replace("<br />", "\n")
        content = content.replace("</p>", "\n\n").replace("<p>", "")
        content = content.replace("</li>", "\n").replace("<li>", "- ")
        content = content.replace("<h1>", "\n").replace("</h1>", "\n")
        content = content.replace("<h2>", "\n").replace("</h2>", "\n")
        content = content.replace("<h3>", "\n").replace("</h3>", "\n")

    lines = [html.escape(line.strip()) for line in content.splitlines()]
    return lines


def build_pdf(input_path: Path, output_path: Path, title: str, font_size: float, line_spacing: float) -> None:
    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    extension = input_path.suffix.lower()
    if extension not in {".md", ".txt", ".html", ".htm"}:
        raise ValueError("Unsupported input extension. Use .md, .txt, .html, or .htm")

    text = input_path.read_text(encoding="utf-8")
    lines = normalize_to_lines(text, extension)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    styles = getSampleStyleSheet()
    title_style = styles["Title"]
    body_style = ParagraphStyle(
        "Body",
        parent=styles["BodyText"],
        fontName="Helvetica",
        fontSize=font_size,
        leading=font_size * line_spacing,
        spaceAfter=6,
    )

    doc = SimpleDocTemplate(str(output_path), pagesize=letter)
    story = [Paragraph(html.escape(title), title_style), Spacer(1, 12)]

    for line in lines:
        if not line:
            story.append(Spacer(1, 8))
            continue
        story.append(Paragraph(line, body_style))

    doc.build(story)


def main() -> None:
    args = parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)
    title = args.title or input_path.stem.replace("_", " ").replace("-", " ").title()

    build_pdf(
        input_path=input_path,
        output_path=output_path,
        title=title,
        font_size=args.font_size,
        line_spacing=args.line_spacing,
    )
    print(f"Generated PDF: {output_path}")


if __name__ == "__main__":
    main()
