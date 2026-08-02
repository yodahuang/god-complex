#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pymupdf>=1.24",
#   "PyYAML>=6.0",
# ]
# ///
"""
Extract figures from a paper PDF and embed them into an Obsidian note.

Usage:
    uv run extract_figures.py <note.md>

Scans the note for self-contained extract markers of the form:
    %%extract fig=5 file="training-pipeline.png"%%

Resolves the PDF from the note's frontmatter `pdf:` field, renders each
named figure (trimmed to content bounds), saves it to imgs/, and removes
the marker from the note.
"""

import re
import shlex
import sys
from pathlib import Path

import fitz  # pymupdf
import yaml


# ── Constants ─────────────────────────────────────────────────────────────────

# Anything above this y-threshold is considered part of a running page header
# and excluded when searching for figure content. We compute it dynamically.
_HEADER_SCAN_LIMIT = 100.0  # only look for header blocks this high up
# Minimum image area (pt²) to count as a real figure vs. an inline icon
MIN_IMAGE_AREA = 5000.0
# Padding around content when trimming margins
CONTENT_PADDING = 6.0
# Extra space below caption bottom
CAPTION_PADDING = 6.0
# Render resolution
DPI = 200


# ── Marker parsing ────────────────────────────────────────────────────────────

def parse_markers(text: str) -> list[dict]:
    """
    Find all %%extract key=value ...%% markers in the note text.
    Returns list of dicts with at minimum 'fig' (int) and 'file' (str),
    plus '_raw' (the original marker line for replacement).
    """
    markers = []
    for line in text.splitlines():
        stripped = line.strip()
        if not (stripped.startswith("%%extract ") and stripped.endswith("%%")):
            continue
        inner = stripped[2:-2].strip()          # drop %%...%%
        tokens = shlex.split(inner)             # handles quoted values
        kv: dict = {"_raw": stripped}
        for token in tokens[1:]:               # skip "extract" keyword
            if "=" in token:
                k, v = token.split("=", 1)
                kv[k] = v
        if "fig" in kv and "file" in kv:
            kv["fig"] = int(kv["fig"])
            markers.append(kv)
        else:
            print(f"  ⚠ Skipping malformed marker: {stripped}")
    return markers


# ── Frontmatter & PDF resolution ─────────────────────────────────────────────

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)


def parse_frontmatter(note_path: Path) -> tuple[dict, str]:
    text = note_path.read_text()
    m = FRONTMATTER_RE.match(text)
    if not m:
        raise ValueError(f"No YAML frontmatter in {note_path}")
    return yaml.safe_load(m.group(1)), text


def resolve_pdf(fm: dict, note_path: Path) -> Path:
    raw = fm.get("pdf", "")
    if not raw:
        raise ValueError("No 'pdf:' key in frontmatter")
    raw = str(raw).strip().strip('"\'')
    raw = re.sub(r"^\[\[(.+)\]\]$", r"\1", raw)   # strip wikilink
    if Path(raw).is_absolute() and Path(raw).exists():
        return Path(raw)
    for parent in [note_path.parent, *note_path.parents]:
        hit = next(parent.rglob(raw), None)
        if hit:
            return hit
    raise FileNotFoundError(f"Could not locate '{raw}' relative to {note_path}")


# ── Figure location on the page ───────────────────────────────────────────────

def header_bottom(page: fitz.Page) -> float:
    """
    Return the y-coordinate where the running page header ends.

    A block qualifies as a header only if:
      - its top is within _HEADER_SCAN_LIMIT of the page top, AND
      - it spans at least 40% of the page width
        (running titles are wide; figure-content boxes are not)

    Falls back to 0 if no header block is found.
    """
    page_width = page.rect.width
    header_blocks = [
        b for b in page.get_text("blocks")
        if b[1] < _HEADER_SCAN_LIMIT
        and (b[2] - b[0]) > 0.4 * page_width
    ]
    return max((b[3] for b in header_blocks), default=0.0)


def caption_labels(fig: int) -> list[str]:
    """Caption-label variants across paper styles: 'Figure N:', 'Figure N.',
    'Figure N ', 'Fig. N:', 'Fig. N.'."""
    return [
        f"Figure {fig}:", f"Figure {fig}.", f"Figure {fig} ",
        f"Fig. {fig}:", f"Fig. {fig}.",
    ]


def find_figure_page(doc: fitz.Document, fig: int) -> int | None:
    variants = caption_labels(fig)
    for idx, page in enumerate(doc):
        t = page.get_text()
        if any(v in t for v in variants):
            return idx
    return None


def caption_rect(page: fitz.Page, fig: int) -> fitz.Rect | None:
    """Bounding rect of the full multi-line caption for figure `fig`."""
    labels = caption_labels(fig)
    label_hit = None
    for label in labels:
        hits = page.search_for(label)
        if hits:
            label_hit = hits[0]
            break
    if label_hit is None:
        return None

    blocks = sorted(page.get_text("blocks"), key=lambda b: b[1])
    cap_y0 = cap_y1 = label_hit.y0
    cap_x0 = label_hit.x0
    cap_x1 = page.rect.x1
    found = False

    for bx0, by0, bx1, by1, *_ in blocks:
        if not found:
            if by0 <= label_hit.y0 + 2 and by1 >= label_hit.y0:
                found = True
                cap_y0, cap_y1 = by0, by1
                cap_x0 = min(cap_x0, bx0)
                cap_x1 = max(cap_x1, bx1)
        else:
            if by0 - cap_y1 < 15 and abs(bx0 - cap_x0) < 30:
                cap_y1 = by1
            else:
                break

    return fitz.Rect(cap_x0, cap_y0, cap_x1, cap_y1 + CAPTION_PADDING)


def figure_top(page: fitz.Page, cap: fitz.Rect) -> float:
    """
    Y-coordinate of the figure's top edge.
    Prefers the top of a raster image sitting above the caption;
    falls back to the gap between the last body-text block and the caption
    (for vector/mixed figures).
    """
    hdr = header_bottom(page)
    best = None
    for img in page.get_images(full=True):
        for r in page.get_image_rects(img[0]):
            if r.width * r.height < MIN_IMAGE_AREA:
                continue
            if r.y1 <= cap.y0 and r.y0 >= hdr:
                if best is None or r.y0 < best:
                    best = r.y0
    if best is not None:
        return best

    blocks_above = [
        b for b in page.get_text("blocks")
        if b[3] < cap.y0 - 5 and b[1] > hdr
    ]
    if blocks_above:
        first_y0 = min(b[1] for b in blocks_above)
        last_y1  = max(b[3] for b in blocks_above)
        if cap.y0 - last_y1 > 30:
            # Body text ends well above the caption; figure lives in that gap.
            return last_y1 + 4
        else:
            # All text above the caption is figure content (labels, annotations).
            # Start just above the first content block, but never above hdr.
            return max(hdr, first_y0 - CONTENT_PADDING)
    return hdr


def content_x_bounds(page: fitz.Page, y0: float, y1: float) -> tuple[float, float]:
    """
    Tightest horizontal extent of content within the vertical band [y0, y1].

    Includes text blocks, significant images, and drawings — but filters out
    drawings wider than 70% of the page, which are decorative (horizontal rules,
    background fills) rather than diagram elements.
    """
    xs0: list[float] = []
    xs1: list[float] = []
    page_width = page.rect.width

    for bx0, by0, bx1, by1, *_ in page.get_text("blocks"):
        if by1 > y0 and by0 < y1:
            xs0.append(bx0)
            xs1.append(bx1)

    for img in page.get_images(full=True):
        for r in page.get_image_rects(img[0]):
            if r.y1 > y0 and r.y0 < y1 and r.width * r.height >= MIN_IMAGE_AREA:
                xs0.append(r.x0)
                xs1.append(r.x1)

    for d in page.get_drawings():
        r = d["rect"]
        if r.y1 > y0 and r.y0 < y1 and r.width < 0.7 * page_width:
            xs0.append(r.x0)
            xs1.append(r.x1)

    if not xs0:
        return page.rect.x0, page.rect.x1

    return (
        max(page.rect.x0, min(xs0) - CONTENT_PADDING),
        min(page.rect.x1, max(xs1) + CONTENT_PADDING),
    )


# ── Extraction ────────────────────────────────────────────────────────────────

def extract_figure(
    page: fitz.Page,
    fig: int,
    y0_frac: float | None = None,
    y1_frac: float | None = None,
) -> fitz.Pixmap | None:
    """
    Render the figure region.

    If y0_frac / y1_frac are provided (normalized 0–1 fractions of page height,
    as written by the skill), use them directly — no heuristics needed.

    Otherwise fall back to heuristic caption + figure-top detection.
    """
    h = page.rect.height

    if y0_frac is not None and y1_frac is not None:
        # ── Coordinate path: hints define a search window ──────────────────
        # Both y0 and y1 are treated as loose bounds; content-aware snapping
        # tightens them to the actual figure top and caption bottom.
        top    = h * y0_frac
        bottom = h * y1_frac

        cap = caption_rect(page, fig)
        if cap is not None and top < cap.y1 <= bottom + 30:
            # Snap y1 → actual caption bottom
            if cap.y1 < bottom:
                print(f"  ↕ y1 snapped {bottom / h:.3f} → {cap.y1 / h:.3f} (caption end)")
                bottom = cap.y1

            # Snap y0 → actual figure top
            detected_top = figure_top(page, cap)
            if abs(detected_top - top) > 2:
                print(f"  ↕ y0 snapped {top / h:.3f} → {detected_top / h:.3f} (figure top)")
            top = detected_top

        x0, x1 = content_x_bounds(page, top, bottom)
        region = fitz.Rect(x0, top, x1, bottom) & page.rect

    else:
        # ── Heuristic fallback ─────────────────────────────────────────────
        cap = caption_rect(page, fig)
        if cap is None:
            return None
        top = figure_top(page, cap)
        fig_x0, fig_x1 = content_x_bounds(page, top, cap.y0)
        x0 = min(fig_x0, cap.x0)
        x1 = max(fig_x1, cap.x1)
        region = fitz.Rect(x0, top, x1, cap.y1) & page.rect

    return page.get_pixmap(matrix=fitz.Matrix(DPI / 72, DPI / 72), clip=region)


# ── Main ──────────────────────────────────────────────────────────────────────

def process_note(note_path: Path) -> None:
    note_path = note_path.resolve()
    fm, text = parse_frontmatter(note_path)
    pdf_path = resolve_pdf(fm, note_path)
    markers = parse_markers(text)

    if not markers:
        print("No %%extract%% markers found — nothing to do.")
        return

    imgs_dir = note_path.parent / "imgs"
    imgs_dir.mkdir(exist_ok=True)

    print(f"PDF:  {pdf_path}")
    print(f"Note: {note_path}")
    print(f"Imgs: {imgs_dir}")
    print(f"Found {len(markers)} marker(s)\n")

    doc = fitz.open(pdf_path)
    modified = text

    for m in markers:
        fig = m["fig"]
        filename = m["file"]
        raw = m["_raw"]

        print(f"▸ fig={fig}  →  {filename}")

        page_idx = find_figure_page(doc, fig)
        if page_idx is None:
            print(f"  ⚠ Figure {fig} not found in PDF — skipping\n")
            continue
        y0_frac = float(m["y0"]) if "y0" in m else None
        y1_frac = float(m["y1"]) if "y1" in m else None
        mode = "coords" if y0_frac is not None else "heuristic"
        print(f"  page {page_idx + 1}  [{mode}]")

        pixmap = extract_figure(doc[page_idx], fig, y0_frac, y1_frac)
        if pixmap is None:
            print(f"  ⚠ Could not locate caption — skipping\n")
            continue

        out_path = imgs_dir / filename
        pixmap.save(str(out_path))
        print(f"  saved {pixmap.width}×{pixmap.height}px → {out_path}\n")

        # Remove just the marker line; the ![[embed]] line stays
        modified = modified.replace(f"\n{raw}", "").replace(f"{raw}\n", "")

    doc.close()

    if modified != text:
        note_path.write_text(modified)
        print("✓ Note updated — markers removed.")
    else:
        print("Note unchanged.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: uv run {sys.argv[0]} <note.md>")
        sys.exit(1)
    process_note(Path(sys.argv[1]))
