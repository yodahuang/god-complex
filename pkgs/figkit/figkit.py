"""figkit: nested-layout SVG diagrams for paper notes.

Every node draws in its own local coordinates (origin = its top-left corner);
containers position children with translate(). Text is measured with real font
metrics, so layout sizes itself and nothing needs hand-placed coordinates.

    # run with:  figkit gen.py
    from figkit import *
    fig = Figure(VStack(Text("Hello", "lead"), Para("long text ...", "ex")),
                 title="...", desc="...")
    fig.save("imgs/x.svg")          # writes SVG, prints layout warnings
    fig.save("imgs/x.svg", preview="scratch/")   # + light/dark PNG renders

Text markup (everywhere a string is drawn):
    x_t  x_{pre}  x^k  x^{k-1}    sub/superscript (single char needs a non-space before _)
    s_{t−d_{RL}}                   scripts nest
    **bold**                       bold span
    {p|text}                       text colored by role p (g t p e o, or any role)
    \\_ \\* \\{                     literal characters
"""
from __future__ import annotations

import html
import inspect
import json
import math
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

# ----------------------------------------------------------------------------
# Font metrics
# ----------------------------------------------------------------------------
FONT_PATH = os.environ.get("FIGKIT_FONT", "/System/Library/Fonts/SFNS.ttf")
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "figkit"
SAFETY = 1.03  # browsers on other OSes fall back to slightly wider fonts
_widths: dict[int, dict[int, float]] = {}


def _load_widths(weight: int) -> dict[int, float]:
    weight = min((400, 500, 600, 700), key=lambda w: abs(w - weight))
    if weight in _widths:
        return _widths[weight]
    f = CACHE / f"sfns-w{weight}.json"
    if f.exists():
        _widths[weight] = {int(k): v for k, v in json.loads(f.read_text()).items()}
        return _widths[weight]
    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer

    font = TTFont(FONT_PATH)
    if "fvar" in font:
        axes = {a.axisTag for a in font["fvar"].axes}
        loc = {"wght": weight} if "wght" in axes else {}
        if "opsz" in axes:
            loc["opsz"] = 17  # smallest optical size; what browsers use at ~12px
        font = instancer.instantiateVariableFont(font, loc)
    upm = font["head"].unitsPerEm
    hm = font["hmtx"]
    w = {cp: hm[g][0] / upm for cp, g in font.getBestCmap().items() if cp < 0x30000}
    CACHE.mkdir(parents=True, exist_ok=True)
    f.write_text(json.dumps(w))
    _widths[weight] = w
    return w


def char_w(ch: str, size: float, weight: int = 400) -> float:
    w = _load_widths(weight).get(ord(ch))
    if w is None:
        w = 1.0 if ord(ch) > 0x2000 else 0.6  # symbols from a fallback font run wide
    return w * size * SAFETY


# ----------------------------------------------------------------------------
# Styles: text classes carry size/weight so we can measure them
# ----------------------------------------------------------------------------
@dataclass
class TStyle:
    size: float
    weight: int = 400
    fill: str | None = None  # css var name without --, or None to let role decide
    extra: str = ""


STYLES: dict[str, TStyle] = {
    "hd": TStyle(15, 600, "ink"),
    "title": TStyle(14, 600),
    "sub": TStyle(11.5),
    "lead": TStyle(13.5, 600, "ink"),
    "ex": TStyle(12.5, 400, "body"),
    "leg": TStyle(12, 400, "legend"),
    "legb": TStyle(12, 600, "ink"),
    "ct": TStyle(11.5),
    "tiny": TStyle(11, 400, "legend"),
    "tinyb": TStyle(11, 600, "ink"),
    "micro": TStyle(9, 400, "legend"),
}

ROLES = ["g", "t", "p", "e", "o"]  # gray data, teal net, purple token, green good, orange bad
PALETTE_LIGHT = dict(
    ink="#20201a", body="#3d3d38", line="#73726c", legend="#5f5e5a", band="#c9c7bf",
    gf="#f1efe8", gs="#888780", gt="#2c2c2a", tf="#e1f5ee", ts="#0f6e56", tt="#085041",
    pf="#eeedfe", ps="#534ab7", pt="#3c3489", ef="#eaf3de", es="#3b6d11", et="#27500a",
    of="#faece7", os="#993c1d", ot="#712b13",
)
PALETTE_DARK = dict(
    ink="#e9e7e0", body="#d3d1c8", line="#a8a69d", legend="#cbc9c0", band="#5a5953",
    gf="#2c2c2a", gs="#b4b2a9", gt="#e9e7e0", tf="#0f3a30", ts="#5dcaa5", tt="#c9efe2",
    pf="#2b2552", ps="#9387e6", pt="#d2ccf7", ef="#213414", es="#8fc75a", et="#d6ecbf",
    of="#3d1f14", os="#e8835e", ot="#f6cfbf",
)

BASE_CSS = """
text{font-family:'Anthropic Sans',-apple-system,system-ui,sans-serif;fill:var(--ink)}
.s{font-size:0.72em}.b{font-weight:600}
.box{stroke-width:1.1}.chip{stroke-width:1}.dash{stroke-dasharray:5 4}
.arw{stroke:var(--line);stroke-width:1.5;fill:none}
.band{fill:none;stroke:var(--band);stroke-width:1.2}
.ax{stroke:var(--line);stroke-width:1.2;fill:none}.tk{stroke:var(--line);stroke-width:1}
.ln{stroke:var(--line);stroke-width:1.2;fill:none}
.cell{fill:var(--gf);stroke:var(--gs);stroke-width:0.8}
.hatch-bg{fill:var(--pf)}.hatch-ln{stroke:var(--ps);stroke-width:1.6;opacity:0.35}
.hatch{fill:url(#hatch);stroke:var(--ps);stroke-width:1.2}
.cross{stroke:var(--os);stroke-width:2;fill:none}
"""


def _role_css() -> str:
    out = []
    for r in ROLES:
        out.append(
            f".r-{r}{{fill:var(--{r}f);stroke:var(--{r}s)}}.k-{r}{{fill:var(--{r}t)}}"
            f".f-{r}{{fill:var(--{r}f)}}.d-{r}{{fill:var(--{r}s)}}.s-{r}{{stroke:var(--{r}s);fill:none}}"
            f".bar-{r}{{fill:var(--{r}f);stroke:var(--{r}s);stroke-width:0.7}}"
        )
    return "\n".join(out)


def _style_css() -> str:
    out = []
    for name, st in STYLES.items():
        s = f"font-size:{st.size}px"
        if st.weight != 400:
            s += f";font-weight:{st.weight}"
        if st.fill:
            s += f";fill:var(--{st.fill})"
        out.append(f".{name}{{{s}{st.extra}}}")
    return "".join(out)


# ----------------------------------------------------------------------------
# Text markup -> runs
# ----------------------------------------------------------------------------
@dataclass
class Run:
    text: str
    bold: bool = False
    shift: tuple[str, ...] | None = None  # nesting of 'sub' / 'super', outermost first
    role: str | None = None


def parse(s: str) -> list[Run]:
    runs: list[Run] = []

    def emit(t, bold, shift, role):
        if not t:
            return
        if runs and (runs[-1].bold, runs[-1].shift, runs[-1].role) == (bold, shift, role):
            runs[-1].text += t
        else:
            runs.append(Run(t, bold, shift, role))

    def walk(s, bold, role, shift):
        i, buf = 0, ""
        while i < len(s):
            c = s[i]
            if c == "\\" and i + 1 < len(s):
                buf += s[i + 1]; i += 2; continue
            if s.startswith("**", i):
                emit(buf, bold, shift, role); buf = ""
                bold = not bold; i += 2; continue
            if c in "_^" and i + 1 < len(s) and i > 0 and not s[i - 1].isspace():
                inner_shift = (shift or ()) + ("sub" if c == "_" else "super",)
                emit(buf, bold, shift, role); buf = ""
                if s[i + 1] == "{":
                    j = _match(s, i + 1)
                    walk(s[i + 2 : j], bold, role, inner_shift)  # x_{t−d_{RL}} nests
                    i = j + 1
                else:
                    emit(s[i + 1], bold, inner_shift, role); i += 2
                continue
            if c == "{":
                m = re.match(r"\{([\w-]+)\|", s[i:])
                if m:
                    j = _match(s, i)
                    emit(buf, bold, shift, role); buf = ""
                    walk(s[i + len(m.group(0)) : j], bold, m.group(1), shift)
                    i = j + 1; continue
            buf += c; i += 1
        emit(buf, bold, shift, role)

    walk(s, False, None, None)
    return runs


def _match(s: str, i: int) -> int:
    depth = 0
    for j in range(i, len(s)):
        if s[j] == "{":
            depth += 1
        elif s[j] == "}":
            depth -= 1
            if depth == 0:
                return j
    raise ValueError(f"unbalanced braces in {s!r}")


def runs_width(runs: list[Run], st: TStyle) -> float:
    w = 0.0
    for r in runs:
        size = st.size * 0.72 ** len(r.shift or ())
        weight = 600 if r.bold else st.weight
        w += sum(char_w(ch, size, weight) for ch in r.text)
    return w


def text_width(s: str, cls: str) -> float:
    return runs_width(parse(s), STYLES[cls])


def runs_svg(runs: list[Run]) -> str:
    out = []
    for r in runs:
        # Renderers drop spaces at a tspan's edges ("a {p|b}" -> "ab"), so keep them outside.
        body = r.text.strip(" ")
        lead, trail = " " * (len(r.text) - len(r.text.lstrip(" "))), " " * (len(r.text) - len(r.text.rstrip(" ")))
        if (r.bold or r.role or r.shift) and body:
            out.append(lead)
            r = Run(body, r.bold, r.shift, r.role)
        else:
            trail = ""
        t = html.escape(r.text, quote=False)
        cls = []
        if r.bold:
            cls.append("b")
        if r.role:
            cls.append(f"k-{r.role}")
        if r.shift:
            # One tspan per level: baseline-shift and the 0.72em size both compound.
            levels = list(r.shift)
            head = " ".join(["s", *cls])
            out.append(f'<tspan class="{head}" baseline-shift="{levels[0]}">'
                       + "".join(f'<tspan class="s" baseline-shift="{lv}">' for lv in levels[1:])
                       + t + "</tspan>" * len(levels))
        elif cls:
            out.append(f'<tspan class="{" ".join(cls)}">{t}</tspan>')
        else:
            out.append(t)
        out.append(trail)
    return "".join(out)


def _split_words(runs: list[Run]) -> list[list[Run]]:
    """Split runs at spaces into words (each a list of runs)."""
    words: list[list[Run]] = [[]]
    for r in runs:
        parts = r.text.split(" ")
        for k, p in enumerate(parts):
            if k > 0:
                words.append([])
            if p:
                words[-1].append(Run(p, r.bold, r.shift, r.role))
    return [w for w in words if w]


def _join_words(words: list[list[Run]]) -> list[Run]:
    out: list[Run] = []
    for k, w in enumerate(words):
        for r in w:
            if k > 0 and r is w[0]:
                r = Run(" " + r.text, r.bold, r.shift, r.role)
            if out and (out[-1].bold, out[-1].shift, out[-1].role) == (r.bold, r.shift, r.role):
                out[-1] = Run(out[-1].text + r.text, r.bold, r.shift, r.role)
            else:
                out.append(r)
    return out


# ----------------------------------------------------------------------------
# Render context: tracks the global offset so checks see global boxes
# ----------------------------------------------------------------------------
@dataclass
class Item:
    kind: str  # 'text' | 'shape' (label is then the shape's CSS classes)
    box: tuple[float, float, float, float]  # x0 y0 x1 y1 (global)
    label: str
    frame: tuple[float, float, float, float] | None  # bounds the item must stay inside
    frame_name: str = ""
    z: int = 0  # paint order: a shape with higher z is drawn on top


class Ctx:
    def __init__(self):
        self.ox = 0.0
        self.oy = 0.0
        self.items: list[Item] = []
        self.frames: list[tuple[tuple, str]] = []
        self.anchors: dict[str, tuple[float, float, float, float]] = {}
        self.z = 0

    def add(self, item: Item):
        self.z += 1
        item.z = self.z
        self.items.append(item)

    def frame(self):
        return self.frames[-1] if self.frames else (None, "")


# ----------------------------------------------------------------------------
# Nodes
# ----------------------------------------------------------------------------
class Node:
    id: str | None = None

    def measure(self, avail: float) -> tuple[float, float]:
        raise NotImplementedError

    def render(self, ctx: Ctx, w: float, h: float) -> list[str]:
        """Draw in local coords; (w, h) is the size the parent allotted."""
        raise NotImplementedError

    def tag(self, id: str):
        self.id = id
        return self


def _place(ctx: Ctx, node: Node, x: float, y: float, w: float, h: float) -> list[str]:
    ctx.ox += x; ctx.oy += y
    if node.id:
        ctx.anchors[node.id] = (ctx.ox, ctx.oy, ctx.ox + w, ctx.oy + h)
    body = node.render(ctx, w, h)
    ctx.ox -= x; ctx.oy -= y
    if not body:
        return []
    if x == 0 and y == 0:
        return body
    return [f'<g transform="translate({_f(x)} {_f(y)})">', *body, "</g>"]


def _f(v: float) -> str:
    s = f"{v:.1f}"
    return s[:-2] if s.endswith(".0") else s


def _record_text(ctx: Ctx, x0, y0, x1, y1, label):
    fr, name = ctx.frame()
    ctx.add(Item("text", (ctx.ox + x0, ctx.oy + y0, ctx.ox + x1, ctx.oy + y1), label, fr, name))


def _record_shape(ctx: Ctx, x0, y0, x1, y1, cls):
    ctx.add(Item("shape", (ctx.ox + x0, ctx.oy + y0, ctx.ox + x1, ctx.oy + y1), cls, None))


def _plain(s: str) -> str:
    return "".join(r.text for r in parse(s))


class Text(Node):
    """One line of text. Height is the line box; baseline sits inside it."""

    def __init__(self, s: str, cls: str = "ex", role: str | None = None, anchor: str = "start"):
        self.s, self.cls, self.role, self.anchor = s, cls, role, anchor
        self.st = STYLES[cls]

    @property
    def lh(self):
        return round(self.st.size * 1.38, 1)

    def measure(self, avail):
        return text_width(self.s, self.cls), self.lh

    def render(self, ctx, w, h):
        tw = text_width(self.s, self.cls)
        x = {"start": 0, "middle": w / 2, "end": w}[self.anchor]
        base = (self.lh - self.st.size) / 2 + self.st.size * 0.8
        x0 = {"start": x, "middle": x - tw / 2, "end": x - tw}[self.anchor]
        _record_text(ctx, x0, base - self.st.size * 0.78, x0 + tw, base + self.st.size * 0.2, _plain(self.s))
        return [_text_el(x, base, self.s, self.cls, self.role, self.anchor)]


def _text_el(x, y, s, cls, role=None, anchor="start"):
    c = cls + (f" k-{role}" if role else "")
    a = "" if anchor == "start" else f' text-anchor="{anchor}"'
    return f'<text class="{c}" x="{_f(x)}" y="{_f(y)}"{a}>{runs_svg(parse(s))}</text>'


class Para(Node):
    """Word-wrapped paragraph that fills the available width (or `w`)."""

    def __init__(self, s: str, cls: str = "ex", w: float | None = None, role=None, leading=1.36):
        self.s, self.cls, self.w, self.role, self.leading = s, cls, w, role, leading
        self.st = STYLES[cls]

    def lines(self, width):
        words = _split_words(parse(self.s))
        space = char_w(" ", self.st.size, self.st.weight)
        lines, cur, cw = [], [], 0.0
        for wd in words:
            ww = runs_width(wd, self.st)
            if cur and cw + space + ww > width + 0.5:  # slack: render re-wraps at the measured width
                lines.append(cur); cur, cw = [], 0.0
            cw += (space if cur else 0) + ww
            cur.append(wd)
        if cur:
            lines.append(cur)
        return lines

    def measure(self, avail):
        width = self.w or avail
        ls = self.lines(width)
        lh = self.st.size * self.leading
        return (max(runs_width(_join_words(l), self.st) for l in ls) if ls else 0), lh * len(ls)

    def render(self, ctx, w, h):
        lh = self.st.size * self.leading
        out = []
        c = self.cls + (f" k-{self.role}" if self.role else "")
        for k, l in enumerate(self.lines(self.w or w)):
            runs = _join_words(l)
            base = k * lh + (lh - self.st.size) / 2 + self.st.size * 0.8
            tw = runs_width(runs, self.st)
            _record_text(ctx, 0, base - self.st.size * 0.78, tw, base + self.st.size * 0.2,
                         "".join(r.text for r in runs))
            out.append(f'<text class="{c}" x="0" y="{_f(base)}">{runs_svg(runs)}</text>')
        return out


class Spacer(Node):
    def __init__(self, w=0, h=0):
        self.w, self.h = w, h

    def measure(self, avail):
        return self.w, self.h

    def render(self, ctx, w, h):
        return []


class Stack(Node):
    def __init__(self, *children, gap=8, align="start", grow=None):
        self.children = [c for c in children if c is not None]
        self.gap, self.align = gap, align
        self.grow = grow  # HStack: index (or list) of children that take the leftover width


class VStack(Stack):
    """Children top to bottom. align: start | middle | end | stretch."""

    def measure(self, avail):
        sizes = [c.measure(avail) for c in self.children]
        return (max((s[0] for s in sizes), default=0),
                sum(s[1] for s in sizes) + self.gap * max(len(sizes) - 1, 0))

    def render(self, ctx, w, h):
        out, y = [], 0.0
        for c in self.children:
            cw, ch = c.measure(w)
            if self.align == "stretch":
                x, cw = 0, w
            else:
                x = {"start": 0, "middle": (w - cw) / 2, "end": w - cw}[self.align]
            out += _place(ctx, c, x, y, cw, ch)
            y += ch + self.gap
        return out


class HStack(Stack):
    """Children left to right. `grow` children share leftover width. align: top|middle|bottom.

    Width-filling children (Box(fill=True), Titled) grow automatically, so two Titled
    panels side by side split the row instead of the first one taking all of it.
    """

    def _widths(self, avail):
        g = self.grow
        grow = set([g] if isinstance(g, int) else (g or []))
        grow |= {i for i, c in enumerate(self.children) if getattr(c, "fill", False) and not c.w}
        fixed = [None if i in grow else c.measure(avail)[0] for i, c in enumerate(self.children)]
        used = sum(x for x in fixed if x is not None) + self.gap * max(len(self.children) - 1, 0)
        left = max(avail - used, 0)
        return [x if x is not None else left / len(grow) for x in fixed]

    def measure(self, avail):
        ws = self._widths(avail)
        hs = [c.measure(w)[1] for c, w in zip(self.children, ws)]
        return sum(ws) + self.gap * max(len(ws) - 1, 0), max(hs, default=0)

    def render(self, ctx, w, h):
        out, x = [], 0.0
        ws = self._widths(w)
        if sum(ws) + self.gap * max(len(ws) - 1, 0) > w + 1:
            ctx.add(Item("text", (ctx.ox, ctx.oy, ctx.ox, ctx.oy),
                                  f"!overflow HStack: children need {sum(ws):.0f}px + gaps, row has {w:.0f}px",
                                  None))
        align = {"start": "top", "end": "bottom"}.get(self.align, self.align)
        for c, cw in zip(self.children, ws):
            ch = c.measure(cw)[1]
            y = {"top": 0, "middle": (h - ch) / 2, "bottom": h - ch, "stretch": 0}[align]
            if align == "stretch":
                ch = h
            out += _place(ctx, c, x, y, cw, ch)
            x += cw + self.gap
        return out


class Pad(Node):
    def __init__(self, child, t=0, r=None, b=None, l=None):
        self.child = child
        self.t = t
        self.r = t if r is None else r
        self.b = t if b is None else b
        self.l = self.r if l is None else l

    def measure(self, avail):
        cw, ch = self.child.measure(avail - self.l - self.r)
        return cw + self.l + self.r, ch + self.t + self.b

    def render(self, ctx, w, h):
        return _place(ctx, self.child, self.l, self.t, w - self.l - self.r, h - self.t - self.b)


class Box(Node):
    """A rounded rect (role-colored) around a padded child. Text inside must fit.

    w/h fix the outer size; fill=True takes all available width.
    """

    def __init__(self, child=None, role="g", pad=10, w=None, h=None, rx=8, dash=False,
                 cls=None, fill=False, valign="top"):
        self.child = child or Spacer()
        self.role, self.w, self.h, self.rx, self.dash, self.fill = role, w, h, rx, dash, fill
        self.pad = pad if isinstance(pad, tuple) else (pad, pad)
        self.cls = cls or f"box r-{role}"
        self.valign = valign

    def measure(self, avail):
        px, py = self.pad
        inner = (self.w if self.w else avail) - 2 * px
        cw, ch = self.child.measure(inner)
        w = self.w or (avail if self.fill else cw + 2 * px)
        return w, self.h or ch + 2 * py

    def render(self, ctx, w, h):
        px, py = self.pad
        d = " dash" if self.dash else ""
        out = [f'<rect class="{self.cls}{d}" x="0" y="0" width="{_f(w)}" height="{_f(h)}" rx="{self.rx}"/>']
        _record_shape(ctx, 0, 0, w, h, self.cls)
        ctx.frames.append(((ctx.ox, ctx.oy, ctx.ox + w, ctx.oy + h), f"Box({self.role})"))
        cw, ch = self.child.measure(w - 2 * px)
        y = {"top": py, "middle": (h - ch) / 2, "bottom": h - py - ch}[self.valign]
        out += _place(ctx, self.child, px, y, w - 2 * px, ch)
        ctx.frames.pop()
        return out


class Titled(Node):
    """A Box whose first line is a title, e.g. a band: Titled('A · Pretrain', body)."""

    def __new__(cls, title, child, cls_title="hd", role="g", gap=10, pad=12, dash=False, box_cls="band"):
        return Box(VStack(Text(title, cls_title), child, gap=gap, align="stretch"),
                   role=role, pad=pad, dash=dash, cls=box_cls, fill=True, rx=10)


class Free(Node):
    """Escape hatch: wrap a node and override its measured size."""

    def __init__(self, child, w=None, h=None):
        self.child, self.w, self.h = child, w, h

    def measure(self, avail):
        cw, ch = self.child.measure(avail)
        return self.w if self.w is not None else cw, self.h if self.h is not None else ch

    def render(self, ctx, w, h):
        return self.child.render(ctx, w, h)


# ----------------------------------------------------------------------------
# Canvas: free drawing in local coords, size inferred from what was drawn
# ----------------------------------------------------------------------------
def lin(d0, d1, r0, r1):
    """Linear scale: maps domain [d0, d1] onto range [r0, r1]."""
    return lambda v: r0 + (v - d0) * (r1 - r0) / (d1 - d0)


class Canvas(Node):
    """Call fn(c) to draw with c.rect/c.text/c.chip/... in local coordinates.

    Size is the bounding box of what was drawn (from 0,0), or fixed by w/h.
    fn may take (c, w) to adapt to the available width.
    """

    def __init__(self, fn, w=None, h=None, name=None):
        self.fn, self.w, self.h = fn, w, h
        self.name = name or getattr(fn, "__name__", "canvas")
        self._cache = {}

    def _run(self, avail):
        key = round(avail, 1)
        if key not in self._cache:
            c = Pen()
            if len(inspect.signature(self.fn).parameters) >= 2:
                self.fn(c, avail)
            else:
                self.fn(c)
            self._cache[key] = c
        return self._cache[key]

    def measure(self, avail):
        c = self._run(self.w or avail)
        return self.w or (c.x1 - c.x0), self.h or (c.y1 - c.y0)

    def render(self, ctx, w, h):
        c = self._run(self.w or w)
        # Anything drawn at negative coords shifts the drawing so it still fits its slot.
        dx, dy = (0 if self.w else -c.x0), (0 if self.h else -c.y0)
        frame = (ctx.ox, ctx.oy, ctx.ox + w, ctx.oy + h) if (self.w or self.h) else None
        ctx.frames.append((frame or ctx.frame()[0], f"Canvas({self.name})" if frame else ctx.frame()[1]))
        ctx.ox += dx; ctx.oy += dy
        out = _replay(ctx, c, out=[])
        ctx.ox -= dx; ctx.oy -= dy
        ctx.frames.pop()
        if dx or dy:
            out = [f'<g transform="translate({_f(dx)} {_f(dy)})">', *out, "</g>"]
        return out


def _replay(ctx: Ctx, pen: "Pen", out: list, frame=None) -> list:
    """Emit a pen's elements, recording its texts and shapes in paint order."""
    marks = iter(pen.marks + [(len(pen.els) + 1, None, None, None)])
    nxt = next(marks)
    for i, el in enumerate([None] + pen.els):
        if el is not None:
            if isinstance(el, tuple):  # nested node
                node, x, y, nw, nh = el
                out += _place(ctx, node, x, y, nw, nh)
            else:
                out.append(el)
        while nxt[0] == i:
            _, kind, (x0, y0, x1, y1), label = nxt
            if kind == "shape":
                _record_shape(ctx, x0, y0, x1, y1, label)
            elif frame:
                ctx.add(Item("text", (ctx.ox + x0, ctx.oy + y0, ctx.ox + x1, ctx.oy + y1), label, frame, "figure"))
            else:
                _record_text(ctx, x0, y0, x1, y1, label)
            nxt = next(marks)
    return out


class Pen:
    """Drawing API inside a Canvas. All methods return useful geometry."""

    def __init__(self):
        self.els: list = []
        self.marks: list = []  # (number of els drawn so far, 'text' | 'shape', box, label)
        self.x0 = self.y0 = 0.0
        self.x1 = self.y1 = 0.0

    def _mark(self, kind, x0, y0, x1, y1, label):
        self.marks.append((len(self.els), kind, (x0, y0, x1, y1), label))

    def _grow(self, x0, y0, x1=None, y1=None):
        x1 = x0 if x1 is None else x1
        y1 = y0 if y1 is None else y1
        self.x0, self.y0 = min(self.x0, x0, x1), min(self.y0, y0, y1)
        self.x1, self.y1 = max(self.x1, x0, x1), max(self.y1, y0, y1)

    def raw(self, svg: str, extent=(0, 0, 0, 0)):
        self.els.append(svg); self._grow(*extent)

    # -- primitives ------------------------------------------------------
    def rect(self, x, y, w, h, cls="box r-g", rx=0, dash=False):
        d = " dash" if dash else ""
        r = f' rx="{_f(rx)}"' if rx else ""
        self.els.append(f'<rect class="{cls}{d}" x="{_f(x)}" y="{_f(y)}" width="{_f(w)}" height="{_f(h)}"{r}/>')
        self._mark("shape", x, y, x + w, y + h, cls)
        self._grow(x, y, x + w, y + h)
        return x + w

    def circle(self, x, y, r, cls="d-e"):
        self.els.append(f'<circle class="{cls}" cx="{_f(x)}" cy="{_f(y)}" r="{_f(r)}"/>')
        self._mark("shape", x - r, y - r, x + r, y + r, cls)
        self._grow(x - r, y - r, x + r, y + r)

    def ellipse(self, x, y, rx, ry, cls):
        self.els.append(f'<ellipse class="{cls}" cx="{_f(x)}" cy="{_f(y)}" rx="{_f(rx)}" ry="{_f(ry)}"/>')
        self._mark("shape", x - rx, y - ry, x + rx, y + ry, cls)
        self._grow(x - rx, y - ry, x + rx, y + ry)

    def path(self, d, cls="ln", arrow=False, extent=None):
        """`extent=(x0, y0, x1, y1)` tells the canvas what the path covers (for sizing).

        Without it, the extent is estimated from the coordinates of absolute M/L commands.
        """
        m = ' marker-end="url(#a)"' if arrow else ""
        self.els.append(f'<path class="{cls}" d="{d}"{m}/>')
        if extent:
            self._grow(*extent)
        elif not re.search(r"[a-zA-Z]", re.sub(r"[ML]", "", d)):
            nums = [float(v) for v in re.findall(r"-?\d+\.?\d*", d)]
            if nums:
                self._grow(min(nums[0::2]), min(nums[1::2]), max(nums[0::2]), max(nums[1::2]))

    def line(self, x0, y0, x1, y1, cls="ln", arrow=False):
        self.path(f"M{_f(x0)} {_f(y0)}L{_f(x1)} {_f(y1)}", cls, arrow, extent=(x0, y0, x1, y1))

    def arrow(self, x0, y0, x1, y1, cls="arw"):
        self.line(x0, y0, x1, y1, cls, arrow=True)

    def text(self, x, y, s, cls="tiny", role=None, anchor="start", rotate=None):
        """(x, y) is the baseline point, as in SVG. Returns the right edge."""
        st = STYLES[cls]
        tw = text_width(s, cls)
        x0 = {"start": x, "middle": x - tw / 2, "end": x - tw}[anchor]
        el = _text_el(x, y, s, cls, role, anchor)
        if rotate is not None:
            el = el.replace("<text ", f'<text transform="rotate({rotate} {_f(x)} {_f(y)})" ', 1)
            self.els.append(el)
            r = tw / 2 + st.size
            self._grow(x - r, y - r, x + r, y + r)
            return x
        self.els.append(el)
        self._mark("text", x0, y - st.size * 0.78, x0 + tw, y + st.size * 0.2, _plain(s))
        self._grow(x0, y - st.size * 0.8, x0 + tw, y + st.size * 0.25)
        return x0 + tw

    def lines(self, x, y, lines, cls="leg", role=None, anchor="start", leading=1.36):
        """Several baseline-aligned lines; returns y of the last baseline."""
        lh = STYLES[cls].size * leading
        for k, s in enumerate(lines):
            self.text(x, y + k * lh, s, cls, role, anchor)
        return y + (len(lines) - 1) * lh

    def place(self, node: Node, x, y, w=None):
        """Nest any layout node here (diagram inside diagram). Returns (w, h)."""
        nw, nh = node.measure(w or 10_000)
        if w:
            nw = w
        self.els.append((node, x, y, nw, nh))
        self._grow(x, y, x + nw, y + nh)
        return nw, nh

    # -- small composites -------------------------------------------------
    def card(self, x, y, title, sub=None, role="t", w=None, pad=(10, 6), cy=None, dash=False):
        """Role-colored box with a title line and optional sub line (a model, a loss...).

        Auto-width unless w is given (overflow is still checked). Pass cy instead of
        relying on y to center the card on a wire at height cy. Returns (x0, y0, x1, y1)
        so arrows can attach to its edges.
        """
        kids = [Text(title, "title", role)] + ([Text(sub, "sub", role)] if sub else [])
        node = Box(VStack(*kids, gap=1), role=role, pad=pad, w=w, dash=dash)
        nw, nh = node.measure(w or 10_000)
        if cy is not None:
            y = cy - nh / 2
        self.place(node, x, y, w)
        return x, y, x + nw, y + nh

    def chip(self, x, y, s, role="g", w=None, h=22, dash=False, cls="ct", pad=8, anchor="start"):
        """Pill with centered label. Auto-width unless w is given. Returns right edge."""
        tw = text_width(s, cls)
        w = w or tw + 2 * pad
        if anchor == "middle":
            x -= w / 2
        self.rect(x, y, w, h, f"chip r-{role}", rx=h / 2, dash=dash)
        self.text(x + w / 2, y + h / 2 + STYLES[cls].size * 0.35, s, cls, role, "middle")
        if tw > w - 4:
            self._mark("text", x, y, x + w, y + h, f"!overflow chip {_plain(s)!r}: text {tw:.0f}px > {w:.0f}px")
        return x + w

    def chips(self, x, y, items, gap=6, h=22, arrow_gap=None):
        """Row of chips: items are (label, role) or (label, role, dict(opts)) or '->'."""
        for it in items:
            if it == "->":
                self.arrow(x + 1, y + h / 2, x + 15, y + h / 2); x += 20; continue
            label, role, *rest = it
            x = self.chip(x, y, label, role, h=h, **(rest[0] if rest else {})) + gap
        return x - gap

    def cyl(self, x, y, w, h, role="g"):
        e = min(5, h / 6)
        self.path(f"M{_f(x)} {_f(y+e)}V{_f(y+h-e)}A{_f(w/2)} {_f(e)} 0 0 0 {_f(x+w)} {_f(y+h-e)}V{_f(y+e)}",
                  f"box r-{role}", extent=(x, y, x + w, y + h))
        self._mark("shape", x, y, x + w, y + h, f"box r-{role}")
        self.ellipse(x + w / 2, y + e, w / 2, e, f"box r-{role}")

    def brace(self, x0, x1, y, depth=6, cls="s-e", up=True):
        """Square bracket over [x0, x1] whose arms point toward y."""
        d = depth if up else -depth
        self.path(f"M{_f(x0)} {_f(y)}V{_f(y-d)}H{_f(x1)}V{_f(y)}", cls, extent=(x0, y - d, x1, y))

    def cross(self, x, y, s=14):
        self.path(f"M{_f(x)} {_f(y)}l{s} {s}M{_f(x+s)} {_f(y)}l{-s} {s}", "cross", extent=(x, y, x + s, y + s))

    def axis(self, x0, x1, y, ticks=None, labels=None, cls="ax", tick_cls="tk", label_cls="tiny"):
        """Horizontal axis. ticks: list of x; labels: list of (x, text, anchor)."""
        self.line(x0, y, x1, y, cls)
        for t in ticks or []:
            self.line(t, y - 4, t, y + 4, tick_cls)
        for lx, s, *a in labels or []:
            self.text(lx, y + STYLES[label_cls].size + 4, s, label_cls, anchor=a[0] if a else "middle")

    def hist(self, x0, x1, ybase, heights, role="t", gap=1.2):
        """Bars of the given pixel heights, evenly over [x0, x1], sitting on ybase."""
        n = len(heights)
        bw = (x1 - x0) / n
        for i, h in enumerate(heights):
            self.rect(x0 + i * bw + gap / 2, ybase - h, bw - gap, h, f"bar-{role}")

    def segments(self, x, y, segs, h=18, label_cls="tiny"):
        """Timeline: segs = [(width, cls, label_above or None, label_inside or None)]."""
        for w, cls, above, inside in segs:
            self.rect(x, y, w, h, cls, rx=3)
            if above:
                self.text(x + w / 2, y - 6, above, label_cls, anchor="middle")
            if inside:
                self.text(x + w / 2, y + h / 2 + 4, inside, "tinyb", anchor="middle")
            x += w
        return x

    def stacked(self, x, y, parts, h=22, frame_role="g", label_cls="tiny"):
        """Stacked bar: parts = [(width, cls, label_below)]."""
        x0 = x
        for w, cls, lab in parts:
            self.rect(x, y, w, h, cls)
            if lab:
                self.text(x + w / 2, y + h + 14, lab, label_cls, anchor="middle")
            x += w
        self.rect(x0, y, x - x0, h, f"s-{frame_role}", rx=3)
        return x


# ----------------------------------------------------------------------------
# Figure
# ----------------------------------------------------------------------------
class Figure:
    def __init__(self, root: Node, title: str, desc: str, width: float = 680, margin: float = 4,
                 css: str = "", defs: str = "", overlay=None):
        """overlay(c, A): draw connectors in figure coords; A('id') -> (x0, y0, x1, y1)."""
        self.root, self.title, self.desc = root, title, desc
        self.width, self.margin, self.css, self.defs, self.overlay = width, margin, css, defs, overlay

    def build(self) -> tuple[str, Ctx]:
        ctx = Ctx()
        inner = self.width - 2 * self.margin
        w, h = self.root.measure(inner)
        ctx.frames.append(((0, 0, self.width, 1e9), "figure"))
        body = _place(ctx, self.root, self.margin, self.margin, inner, h)
        H = h + 2 * self.margin
        if self.overlay:
            pen = Pen()
            self.overlay(pen, lambda k: ctx.anchors[k])
            _replay(ctx, pen, body, frame=(0, 0, self.width, H))
        dark = ";".join(f"--{k}:{v}" for k, v in PALETTE_DARK.items())
        light = ";".join(f"--{k}:{v}" for k, v in PALETTE_LIGHT.items())
        css = (BASE_CSS.strip() + "\n" + _role_css() + "\n" + _style_css() + "\n" + self.css.strip() +
               f"\n:root{{{light}}}\n@media (prefers-color-scheme:dark){{:root{{{dark}}}}}")
        svg = "\n".join([
            f'<svg width="100%" viewBox="0 0 {_f(self.width)} {_f(math.ceil(H))}" role="img" xmlns="http://www.w3.org/2000/svg">',
            f"<title>{html.escape(self.title)}</title><desc>{html.escape(self.desc)}</desc>",
            "<defs>",
            '<marker id="a" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6.5" markerHeight="6.5" orient="auto-start-reverse"><path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></marker>',
            '<pattern id="hatch" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="6" height="6" class="hatch-bg"/><path d="M0 0V6" class="hatch-ln"/></pattern>',
            self.defs,
            f"<style>\n{css}\n</style>",
            "</defs>",
            *body,
            "</svg>",
        ])
        ctx.height = H
        return svg, ctx

    def check(self, ctx: Ctx) -> list[str]:
        warn = []
        texts = [i for i in ctx.items if i.kind == "text"]
        for it in texts:
            if it.label.startswith("!"):
                warn.append(it.label[1:]); continue
            x0, y0, x1, y1 = it.box
            if it.frame:
                fx0, fy0, fx1, fy1 = it.frame
                over = max(fx0 - x0, x1 - fx1, fy0 - y0, y1 - fy1)
                if over > 1.0:
                    warn.append(f"overflow {over:.0f}px out of {it.frame_name}: {it.label!r}")
        texts = [t for t in texts if not t.label.startswith("!")]
        for it in texts:  # a box that doesn't fit its parent can push a whole subtree off the canvas
            x0, _, x1, _ = it.box
            over = max(-x0, x1 - self.width)
            if over > 1.0 and it.frame_name != "figure":
                warn.append(f"overflow {over:.0f}px out of figure: {it.label!r}")
        # A filled shape painted after a text, on top of it, hides it (e.g. two chips overlapping).
        css = BASE_CSS + _role_css() + self.css
        clear = {m.group(1) for m in re.finditer(r"\.([\w-]+)\{([^}]*)\}", css) if "fill:none" in m.group(2)}
        shapes = [s for s in ctx.items if s.kind == "shape" and not (set(s.label.split()) & clear)]
        for t in texts:
            for sh in shapes:
                p, q = t.box, sh.box
                ix = min(p[2], q[2]) - max(p[0], q[0])
                iy = min(p[3], q[3]) - max(p[1], q[1])
                if sh.z > t.z and ix > 2 and iy > 2:
                    warn.append(f"covered: shape .{sh.label.split()[0]} is drawn over {t.label!r}")
        for a in range(len(texts)):
            for b in range(a + 1, len(texts)):
                p, q = texts[a].box, texts[b].box
                ix = min(p[2], q[2]) - max(p[0], q[0])
                iy = min(p[3], q[3]) - max(p[1], q[1])
                if ix > 1.5 and iy > 2.5:
                    warn.append(f"overlap: {texts[a].label!r} / {texts[b].label!r}")
        return list(dict.fromkeys(warn))

    def save(self, path, preview: str | None = None, quiet=False):
        svg, ctx = self.build()
        Path(path).write_text(svg)
        warns = self.check(ctx)
        if not quiet:
            print(f"wrote {path}  ({self.width}x{ctx.height:.0f})")
            for w in warns:
                print("  WARN", w)
            if not warns:
                print("  layout check: clean")
        if preview:
            render_preview(path, preview)
        return warns


def flatten(svg: str, theme: str = "light") -> str:
    """Resolve CSS variables for one theme (renderers like librsvg can't do var())."""
    pal = PALETTE_LIGHT if theme == "light" else PALETTE_DARK
    root = re.search(r":root\{(.*?)\}", svg, re.S)
    vals = dict(re.findall(r"(--[\w-]+):([^;}\s]+)", root.group(1))) if root else {}
    vals.update({f"--{k}": v for k, v in pal.items()})
    if theme == "dark":
        m = re.search(r"@media \(prefers-color-scheme:dark\)\{:root\{(.*?)\}\}", svg, re.S)
        if m:
            vals.update(dict(re.findall(r"(--[\w-]+):([^;}\s]+)", m.group(1))))
    svg = re.sub(r"var\((--[\w-]+)\)", lambda m: vals.get(m.group(1), "#f0f"), svg)
    return re.sub(r"@media[^{]*\{:root\{.*?\}\}", "", svg, flags=re.S)


def render_preview(svg_path, out_dir, width=1100):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = Path(svg_path).stem
    src = Path(svg_path).read_text()
    for theme, bg in (("light", "white"), ("dark", "#1e1e1e")):
        flat = out_dir / f"{stem}-{theme}.svg"
        flat.write_text(flatten(src, theme))
        png = out_dir / f"{stem}-{theme}.png"
        rsvg = ["rsvg-convert"] if shutil.which("rsvg-convert") else ["nix", "run", "nixpkgs#librsvg", "--"]
        subprocess.run([*rsvg, "--width", str(width), "--background-color", bg, str(flat), "-o", str(png)],
                       check=True)
        print(f"  preview {png}")


__all__ = [
    "Figure", "Node", "Text", "Para", "Spacer", "VStack", "HStack", "Pad", "Box", "Titled", "Free",
    "Canvas", "Pen", "lin", "STYLES", "TStyle", "ROLES", "PALETTE_LIGHT", "PALETTE_DARK",
    "text_width", "parse", "flatten", "render_preview",
]
