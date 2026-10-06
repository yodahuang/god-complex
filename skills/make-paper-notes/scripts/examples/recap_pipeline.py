"""RECAP (pi*0.6) training pipeline -> ML/imgs/recap-pipeline.svg

Run with:  figkit recap_pipeline.py OUT.svg [PREVIEW_DIR]
"""
import math
import random
import sys

from figkit import *

STYLES["title"].size = 14

CSS = """
.card{fill:var(--gf);stroke:var(--gs);stroke-width:0.9}.img{fill:var(--ts);opacity:0.55}
.mean{stroke:var(--ts);stroke-width:1.8;stroke-dasharray:4 3}
.tickp{stroke:var(--ps);stroke-width:2.4}.gap{stroke:var(--ink);stroke-width:1.4;fill:none}
.th{stroke:var(--ps);stroke-width:1.6;stroke-dasharray:5 3}
.dot-o{fill:var(--os);opacity:0.75}
.seg-auto{fill:var(--of);stroke:var(--os);stroke-width:0.9}
.stk-o2{fill:var(--os);opacity:0.45}.stk-o3{fill:var(--os);opacity:0.2}
.vdash{stroke:var(--ts);stroke-width:3;stroke-dasharray:2 4;fill:none}
"""


# ---- one small drawing per step; each draws from its own (0, 0) -------------
def reward_strips(c):
    for k, (n, end, role) in enumerate([(10, "0 ✓", "e"), (7, "−C_{fail} ✗", "o")]):
        y = k * 28
        for i in range(n):
            c.rect(i * 21, y, 19, 20, "cell", rx=3)
            c.text(i * 21 + 9.5, y + 14, "−1", "micro", anchor="middle")
        c.chip(n * 21 + 2, y - 1, end, role)
    c.lines(300, 12, ["R_t = everything collected", "from step t to the end,",
                      "scaled per task into (−1, 0)"])


def value_hist(c):
    x0, x1, yb = 10, 250, 64
    hs = [50 * math.exp(-((u - 0.68) / 0.13) ** 2 / 2) + 14 * math.exp(-((u - 0.03) / 0.04) ** 2 / 2) + 1.5
          for u in (i / 39 for i in range(40))]
    c.hist(x0, x1, yb, hs, role="t")
    c.axis(x0, x1, yb, labels=[(x0, "−1  (fail)", "start"), (x1, "0  (done)", "end")])
    xm = lin(0, 1, x0, x1)(0.6)
    c.line(xm, yb + 2, xm, -2, "mean")
    c.text(xm + 4, 8, "V = mean", "legb", role="t")
    c.lines(276, 20, ["201 bins, not one number.", "The small bump near −1",
                      "is “this might still fail”."])


def grading(c):
    y, w = 34, 200
    x = lin(-1, 0, 0, w)
    c.axis(0, w, y, labels=[(0, "−1", "start"), (w, "0", "end")])
    xv, xr = x(-0.55), x(-0.28)
    c.line(xv, y - 9, xv, y + 9, "tickp")
    c.text(xv - 4, y - 14, "V(o_t) guessed", "tiny", role="p", anchor="end")
    c.circle(xr, y, 5, "d-e")
    c.text(xr - 4, y - 14, "R_t actual", "tiny", role="e")
    c.arrow(xv + 3, y + 8, xr - 6, y + 8, "gap")
    c.text((xv + xr) / 2, y + 22, "A", "legb", anchor="middle")

    ox, w2 = 240, 220
    a = lin(-2.6, 2.6, ox, ox + w2)
    c.axis(ox, ox + w2, y, labels=[(ox, "negative", "start"), (ox + w2, "positive ≈ 30%", "end")])
    random.seed(3)
    xs = sorted(random.gauss(0, 1) for _ in range(34))
    cut = xs[int(len(xs) * 0.7)]
    for i, v in enumerate(xs):
        c.circle(a(v), y - 6 - (i % 3) * 7, 3.2, "d-e" if v >= cut else "dot-o")
    c.line(a(cut), y + 8, a(cut), 0, "th")
    c.text(a(cut) + 4, 8, "ε_ℓ", "legb", role="p")
    c.text(ox + w2 / 2, y + 30, "A of every sample", "tiny", anchor="middle")


def prompt_tokens(c):
    def row(y, token):
        for i in range(3):
            c.rect(i * 13, y + 3, 11, 16, "img", rx=2)
        return c.chips(44, y, [("“make a doppio”", "g"), ("“tamp”", "g"), token, "->", ("actions", "e")])
    row(0, ("Advantage: positive", "p"))
    row(30, ("(token dropped)", "p", dict(dash=True)))
    # label under the dropped token: find its center from the same chip widths
    x = 44 + text_width("“make a doppio”", "ct") + 16 + 6 + text_width("“tamp”", "ct") + 16 + 6
    c.text(x + (text_width("(token dropped)", "ct") + 16) / 2, 66, "↑ 30% of samples", "tiny",
           role="p", anchor="middle")


def demo_cards(c):
    for i in range(6):
        c.rect(i * 34, 0, 28, 34, "card", rx=4)
        c.text(i * 34 + 14, 14, "demo", "micro", anchor="middle")
        c.circle(i * 34 + 14, 24, 5, "d-e")
    c.lines(214, 14, ["every demo tagged “positive”", "→ this step is just SFT"])


def takeover(c):
    end = c.segments(0, 18, [(140, "seg-auto", "{o|robot drives}", None),
                             (95, "hatch", "{p|expert takes over}", "{p|I = 1 forced}"),
                             (160, "seg-auto", "{o|robot again}", None)])
    c.chip(end + 7, 16, "✓ / ✗", "g")


def growing_data(c):
    c.stacked(0, 6, [(130, "f-g", "demos"), (110, "f-o", "round 1"),
                     (110, "stk-o2", "round 2"), (70, "stk-o3", "…")])


def reset(name, role):
    def draw(c):
        x = c.chip(0, 4, f"{name}_{{pre}}", role, w=70)
        c.arrow(x + 4, 15, x + 44, 15)
        c.chip(x + 48, 4, f"{name}^k", role, w=48)
        x2 = 230
        x = c.chip(x2, 4, f"{name}^{{k−1}}", "g", dash=True)
        c.arrow(x + 4, 15, x + 44, 15, "arw dash")
        c.cross(x + 16, 7)
        x = c.chip(x + 48, 4, f"{name}^k", "g", w=48, dash=True)
        c.text(x + 12, 19, "not this", "tiny")
    draw.__name__ = f"reset_{name}"
    return draw


def window(c, avail):
    y, w, k = 30, min(440, avail), 200
    c.axis(0, w, y, ticks=[i * 8 for i in range(26)],
           labels=[(0, "t", "start"), (k, "t+50", "middle"), (w, "end", "end")])
    c.brace(0, k, y - 10)
    c.text(k / 2, y - 21, "50 real steps: r_t + … + r_{t+49}", "tiny", role="e", anchor="middle")
    c.line(k + 4, y, w, y, "vdash")
    c.text((k + 4 + w) / 2, y - 10, "V(o_{t+50}) guesses the rest", "tiny", role="t", anchor="middle")


def pooled(c):
    for dx, role, lab in [(0, "g", "D_{demo}"), (56, "o", "D_{ℓ1}"), (112, "o", "D_{ℓ2}"), (168, "o", "…")]:
        c.cyl(dx, 0, 40, 34, role)
        c.text(dx + 20, 50, lab, "tiny", anchor="middle")
    c.arrow(220, 17, 262, 17)
    c.rect(266, 5, 76, 24, "box r-p", rx=6, dash=True)
    c.text(304, 21, "①→②→③", "ct", role="p", anchor="middle")
    c.arrow(346, 17, 372, 17)
    c.chip(376, 6, "π_{final}", "e", w=70)


# ---- layout -------------------------------------------------------------------
def step(id, role, title, sub, lead, body, drawing, dash=False):
    label = Box(VStack(Text(title, "title", role), Text(sub, "sub", role), gap=2),
                role=role, w=160, h=60, pad=(12, 8), valign="middle", dash=dash).tag(id)
    text = VStack(Text(lead, "lead"), Para(body, "ex"), Spacer(h=2), Canvas(drawing), gap=4)
    return HStack(label, text, gap=22, grow=1)


def band(title, *steps, dash=False):
    return Titled(title, Pad(VStack(*steps, gap=22), 0, 0, 4, 14), dash=dash)


L = "_ℓ"
root = VStack(
    band("A · Pretrain: offline RL on every demonstration",
         step("data", "g", "D_{demo}", "all the demos",
              "Lots of demos, and one human label each.",
              "Every episode just says success or failure. That becomes a reward: every "
              "step costs −1, so a fast success scores higher than a slow one.", reward_strips),
         step("v", "t", "① Train V_{pre}", "the value model",
              "V learns to guess how much of the task is left.",
              "It sees the images and the task, never the action, and predicts the "
              "return as a histogram. V is its mean.", value_hist),
         step("grade", "p", "② Grade samples", "A, then I",
              "Then every sample is graded against that guess.",
              "If things went better from here than V expected, A > 0. In pretraining "
              "we look all the way to the episode end (N = T). The top ~30% become I = 1.", grading),
         step("pi", "e", "③ Train π_{pre}", "the VLA itself",
              "The VLA reads the grade as one more word in its prompt.",
              "Same imitation loss as always. 30% of the time the word is hidden, so "
              "one set of weights also learns the plain, unconditioned policy (for CFG).", prompt_tokens)),
    band("B · Specialist: practice one skill ℓ",
         step("sft", "g", f"Start: π^0{L}", "plain SFT",
              "Kick off with ordinary fine-tuning on this skill’s demos.",
              f"ℓ is the task (“make a doppio”), so D{L} is the data for that one skill.", demo_cards),
         step("deploy", "o", f"Deploy π^{{k−1}}{L}", "with I = 1",
              "Let it practice, with a human ready to step in.",
              "The robot runs prompted with “positive”. When an expert grabs the controls, "
              "those steps are labeled positive no matter what V says.", takeover),
         step("grow", "g", f"Grow D{L}", "keep everything",
              "Nothing is thrown away, not even the failures.",
              "Old rounds stay too, so “the data” is humans plus every past policy.", growing_data),
         step("refit", "t", f"Refit V^k{L}", "from V_{pre}",
              "Re-learn the value model from the pretrained one.",
              f"It is trained on all of D{L}, with the same 201-bin loss as before.", reset("V", "t")),
         step("regrade", "p", f"Re-grade D{L}", "N = 50",
              "Grade again, but only trust 50 real steps.",
              "Count actual rewards for 50 steps, then let V guess the rest: less noisy than "
              "waiting for the end. Cut at ~40% positive (t-shirt: ~10%, only the fastest).", window),
         step("retrain", "e", f"Retrain π^k{L}", "from π_{pre}",
              "Retrain the policy from π_{pre} again, every round.",
              "Not from last round’s policy: only the data carries over, which avoids drift.",
              reset("π", "e"))),
    band("C · Maybe: one generalist at the end",
         step("pool", "g", "Pool it all", "not in Algorithm 1",
              "The paper gives this one sentence.",
              "Likely reading: pool every specialist’s data and rerun ①–③ fresh, "
              "instead of merging specialist weights.", pooled, dash=True), dash=True),
    gap=12,
)


def connectors(c, A):
    chains = [["data", "v", "grade", "pi"], ["sft", "deploy", "grow", "refit", "regrade", "retrain"]]
    for chain in chains:
        for a, b in zip(chain, chain[1:]):
            (x0, _, x1, y1), (_, y2, _, _) = A(a), A(b)
            c.arrow((x0 + x1) / 2, y1, (x0 + x1) / 2, y2 - 2)
    top, bot = A("deploy"), A("retrain")
    ya, yb = (top[1] + top[3]) / 2, (bot[1] + bot[3]) / 2
    xl = top[0] - 14
    c.path(f"M{top[0]:.1f} {yb:.1f}H{xl:.1f}V{ya:.1f}H{top[0] - 2:.1f}", "arw", arrow=True)
    c.text(xl - 4, (ya + yb) / 2, "repeat: k ← k + 1", "legb", anchor="middle", rotate=-90)


fig = Figure(root, overlay=connectors, css=CSS,
             title="RECAP training pipeline",
             desc="Illustrated flowchart: pretrain a value model on success-labeled demos, grade every "
                  "sample by advantage, and train the VLA with an advantage token in its prompt; then for "
                  "each skill, start with SFT, deploy with human takeovers, keep all data, refit the value "
                  "model and retrain the policy from pretrained checkpoints using 50-step advantages; "
                  "optionally pool all data into one generalist.")

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "recap-pipeline.svg"
    fig.save(out, preview=sys.argv[2] if len(sys.argv) > 2 else None)
