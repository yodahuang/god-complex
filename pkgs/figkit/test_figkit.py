"""Regression checks for figkit. Run from anywhere:  figkit pkgs/figkit/test_figkit.py

Imports the figkit.py next to this file, not the installed one, so it tests your edits.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from figkit import *  # noqa: E402


def build(root, **kw):
    fig = Figure(root, title="t", desc="d", **kw)
    svg, ctx = fig.build()
    return svg, fig.check(ctx)


def test_nested_scripts():
    runs = parse("s_{t−d_{RL}}")
    assert [(r.text, r.shift) for r in runs] == [
        ("s", None), ("t−d", ("sub",)), ("RL", ("sub", "sub"))], runs
    svg, _ = build(Text("s_{t−d_{RL}}", "ct"))
    assert "{" not in re.sub(r"<style>.*?</style>", "", svg, flags=re.S).split("</defs>")[1]
    assert svg.count('baseline-shift="sub"') == 3  # t−d, then RL nested one level deeper


def test_space_before_markup():
    # Renderers drop a space sitting just inside a tspan, so it must sit outside it.
    for s in ("are a **constraint** on", "are a {p|constraint} on"):
        svg, _ = build(Para(s, "ex"))
        body = svg.split("</defs>")[1]
        assert not re.search(r"<tspan[^>]*> |  </tspan>| </tspan>", body), body
        assert re.sub(r"<[^>]+>", "", body).strip() == "are a constraint on", body


def test_hstack_splits_filled_panels():
    panel = lambda: Titled("P", Para("some words " * 8, "ex"))
    svg, warns = build(HStack(panel(), panel(), gap=10))
    xs = [float(x) for x in re.findall(r'translate\(([\d.]+) [\d.]+\)', svg)]
    assert any(300 < x < 400 for x in xs), "second panel should start mid-figure"
    assert not warns, warns


def test_hstack_overflow_warns():
    _, warns = build(HStack(Box(w=400), Box(w=400)))
    assert any("HStack" in w for w in warns), warns


def test_shape_over_text_warns():
    def draw(c):
        c.chip(0, 0, "w ∼ N(0, I)", "g", w=92)
        c.chip(60, 0, "a_{t−d:t−1}", "p", w=112)
    _, warns = build(Canvas(draw))
    assert any(w.startswith("covered") and "N(0, I)" in w for w in warns), warns

    def ok(c):  # text on top of its own chip, and an unfilled band, are fine
        c.rect(0, 0, 200, 40, "band")
        c.chip(10, 8, "fine", "g")
    _, warns = build(Canvas(ok))
    assert not warns, warns


def test_unroled_text_has_ink():
    svg, _ = build(Text("plain", "ct"))
    assert re.search(r"text\{[^}]*fill:var\(--ink\)", svg)


if __name__ == "__main__":
    tests = [(k, v) for k, v in dict(globals()).items() if k.startswith("test_")]
    failed = 0
    for name, fn in tests:
        try:
            fn(); print("ok  ", name)
        except AssertionError as e:
            failed += 1; print("FAIL", name, e)
    sys.exit(1 if failed else 0)
