---
name: paper-reading-notes
description: Create Obsidian paper reading notes from a discussion about an ML/AI paper. Use this skill whenever the user asks to write up, capture, or save notes about a paper they've been discussing — including phrases like "write this up as a note", "save this to Obsidian", "create a note from our discussion", "paper reading note", or similar. The skill mines the conversation for confusions and insights, identifies gaps the discussion didn't cover, and produces a .md file ready to drop into the user's vault.
---

# Paper Reading Notes Skill

For Obsidian syntax — callouts, wikilinks, frontmatter types, embeds, math — consult the **obsidian-markdown** skill. This skill focuses on *what to write and why*, not how Obsidian works.

**Do not read existing notes in the vault for "style reference."** The guidance in this skill is the style. Reading other notes wastes context and risks importing patterns the user hasn't endorsed for this note. Write from the discussion and the paper directly. The only exception is if the user explicitly asks you to match a specific note's voice or format.

---

## Before writing: confirm the plan

These notes are personal — don't draft the whole thing blind. First propose a short plan and get the user's sign-off on two things:

- **The structure** — the section spine and overall framing/opening you intend to use (driven by the discussion, per "On structure" below).
- **Custom SVGs** — which hand-made diagrams, if any, would genuinely help and what each would show (see "Custom SVG diagrams"). Don't build them until the user agrees.

Keep it brief — a few lines, or an `AskUserQuestion` for the concrete forks (which diagrams to make, whether to embed a paper figure). Once confirmed, write the note.

---

## Frontmatter

Use exactly this schema. Infer values from the conversation; ask only if something is genuinely ambiguous.

```yaml
---
date: YYYY-MM-DD
pdf: "[[NoteName.pdf]]"
aliases:
  - short name or abbreviation   # omit this field entirely if it would just repeat the title
year: YYYY                       # publication year, not submission year
Arxiv: https://arxiv.org/abs/XXXX.XXXXX
original title: "Full Paper Title As Written on the Paper"
---
```

- **`aliases`** — include only when there's a genuinely shorter name or abbreviation (e.g. `SONIC`, `DiT`). If the alias would just repeat the note's title, drop the field.
- **`pdf`** — when the user provides the source PDF, `cp` it into the sibling `pdf/` folder renamed to match the note (`<NoteName>.pdf`), and point the field there: `pdf: "[[NoteName.pdf]]"`. Do the copy yourself; don't ask the user to run it.

After the frontmatter block, add a horizontal rule and an attribution note identifying yourself (the Claude model and version writing this note), then another horizontal rule before the body begins.

---

## What to write

Start by doing two things mentally before putting words down:

**Mine the conversation.** Read through the discussion that just happened. What did the user get confused about? What clicked for them? What questions did they ask that revealed something interesting about the paper? What analogies or framings emerged that made things clearer? These are the most valuable things to preserve — they're personal, they won't appear in any textbook, and they're likely to be exactly what the user will want to recall when they come back to this note months later.

**Find the gaps.** What important aspects of the paper didn't come up in the discussion? For ML papers, common gaps include: computational cost tradeoffs, what the ablations revealed, limitations the authors acknowledged, connections to concurrent or prior work, and what the paper's success depended on that might not hold in other settings. Weave these in where they fit naturally — but only where they fit naturally. Don't pad with things the discussion didn't care about just to be comprehensive (see failure modes below).

---

## Open with what it is

The first paragraph orients the reader fast: **what problem the paper tackles, and what its one new idea is.** Not "this paper introduces X, Y, and Z" — that's an abstract, and the user can read the abstract themselves. Lead with substance and a point of view about what *matters*.

For an algorithmic or systems paper, the first screen must also make the method **executable in the reader's head**. State the inputs or supervision, what is trained, what happens at inference, and the one operation that differs from the baseline. Give this concrete procedure before its proof, interpretation, or lineage. For a primarily theoretical paper, give the analogous operational picture: the objects involved, the transformation or claim, the guarantee, and the conditions under which it applies.

But keep the purpose straight: **these are notes the user returns to in order to remember what the paper was about.** The goal is recall, not a verdict. An opening can be pointed and have an opinion, but it should not be a takedown. Caveats and weaknesses have a place (see the spine below) — just not as the thing the note opens on or is organized around.

Useful shapes for the opening:
- "The problem is X; the genuinely new idea is W."
- "The new idea is W; the rest is built from Y and Z."
- "The paper's central bet is X."

If a paper has a clear lineage — it's mostly *A + B* recombined — saying so early is often the single most useful thing for recall.

---

## On structure

The note should feel like it was *written*, not assembled. Avoid the instinct to produce rigid sections and fill them in order.

**Section headers are claims or questions, not paper sections.** If your headers read "Architecture / Dataset / Training / Results", you have written a summary of the paper, not a note. Headers should be the things worth *saying* about the paper — "What's actually new", "Why X is doing all the work", "This is really A + B", "What the results lean on". Each section earns its place by making a point.

Build a **causal spine**, not an inventory of correct facts. Each section should answer a question created by the preceding explanation. For an algorithmic paper, a useful shape is concrete procedure → why that procedure has the claimed effect → where its supervision comes from → variants → limits. Introduce an equation, distinction, or terminology only when it resolves something the reader now needs to understand.

### A default spine for recall

When in doubt, this ordering reads well months later. Deviate when the paper calls for it, but it's a sound default:

1. **The problem.** What is the paper trying to solve? One short section, concrete.
2. **The novel idea — front and center.** The single thing this paper contributes. Give it the most space (see "Symmetric treatment" below). This is what the user will want to recall first, so it goes first, not buried after a lineage discussion.
3. **Lineage — what it's built from.** Where the rest comes from ("this is essentially A's encoder + B's decoder"). Often the most useful thing for placing the paper, but it comes *after* the new idea, not before — the new idea is the headline, the lineage is context.
4. **Supporting design + mechanisms.** The pieces that make the idea work: key losses, algorithms, design choices that earned their ablation.
5. **What the results lean on / caveats.** Pretraining dependencies, under-ablated tricks, honest limitations. These belong **late and proportionate** — recorded for completeness so the user remembers the fine print, not used to frame the whole note. State them neutrally; the user can form their own judgment on re-read.

There's still a meaningful distinction worth preserving somewhere in the note:

- **What the paper is about and why it matters** — the core idea, the problem it solves, the conceptual shift it makes. This is timeless. Someone reading the note in three years should still find this useful.
- **How it's actually implemented** — architecture choices, training tricks, specific numbers. This is a snapshot. It may be superseded. Make clear (with appropriate Obsidian callout) that this part is more ephemeral.

How you bridge between these, how much space each gets, whether you interleave them or separate them — use your judgment based on the paper. Some papers are mostly idea; the implementation is almost a footnote. Others are mostly an engineering contribution where the implementation *is* the idea. Let the paper's nature guide the shape of the note.

Preserve the user's own phrasing and framing when it's good. These are their notes. Use Obsidian callouts naturally to surface confusions, insights, and caveats — but don't force things into callouts just because you can.

---

## Common failure modes to avoid

These are concrete things that have gone wrong before. Check the draft against this list before saving.

- **Mirroring the paper's structure.** If section headers match the paper's section headers, the note has degenerated into a summary. Drive structure from the *discussion*, not the table of contents.
- **Operational opacity.** If several paragraphs pass before the reader knows what enters the method, what is learned, and what happens when it is used, rewrite the opening. A high-level slogan is not a substitute for the procedure.
- **Paper-local scaffolding.** Don't organize the note around transitions such as “Section 4.1 → 4.2,” unexplained equation numbers, or the paper's local order. Restate the conceptual transition so the note remains intelligible with the source closed.
- **Q&A residue.** Mine the discussion for the reasoning that resolved confusion, but don't preserve its sequence of questions. A confusion should improve the exposition order; it should not automatically become a paragraph, callout, or section.
- **Orphan facts and distinctions.** A true observation can still damage the note if the reader has no reason to care about it yet. Connect each technical fact to the method's causal story, move it to where that need arises, or cut it.
- **Trying to be comprehensive.** A note that covers every contribution and every component goes flat — the interesting bits get buried with the routine ones. Cut things that are standard practice in the field (e.g. unicycle dynamics in AV, multi-camera tokenization, choice of optimizer), even if the paper spends a section on them. One sentence acknowledgment is fine; a subsection is not.
- **Callouts: group, don't hide.** Use callouts to *visually group* supporting detail (derivations, numbers, secondary mechanisms, implementation specifics) under a clear headline — but **default to showing them expanded**. In Obsidian that's `[!note]` (always shown) or `[!note]+` (expanded but collapsible); reserve `-` (collapsed-by-default) for genuinely long reference dumps the reader rarely needs. The point of the grouping is scannability, not concealment: a reader should see the headline *and* the content, and skip by section rather than by expanding. Don't hide the main point in a callout, and don't park raw uncurated tables — callout content still has to be curated prose worth keeping.
- **Critique creep.** These notes are for *recall*, not review. A pointed observation in passing is fine, but if the note is organized around what's wrong with the paper — or opens on its weaknesses — it has drifted from its purpose. Keep caveats late and proportionate (see the spine). When you do record a limitation, state it neutrally and factually ("the result depends on X pretraining; without it, metric drops to Y") rather than as a verdict ("the framing oversells").
- **Symmetric treatment of contributions.** Most papers have one genuinely novel thing and several standard things bundled around it. Give the novel thing the most space — it's the headline. Give the standard things one sentence each, or cut them entirely if they're truly inherited.
- **Equation-first sections.** Don't lead a section with the math. Lead with the claim or the question, then introduce notation only if it carries weight. If the equation can be replaced by a sentence of prose, replace it.
- **Length creep / reads like the whole paper.** If the note is as long as reading the paper itself, it has failed at its job. A focused note is roughly a thoughtful blog post. When detail piles up, the fix is to **cut or compress** — tighten prose, drop standard-practice components, group related detail under one callout heading. Don't reach for collapsing-to-hide as the length fix; the visible text should already be thin.

### Self-contained recall check

Before saving, read only the opening and section headers. Without consulting the paper, can the reader answer:

- What problem is being solved?
- What is the new idea?
- For an algorithmic paper: what are the inputs or supervision, what is trained, and what happens at inference?
- For a theoretical paper: what objects are transformed or related, what is guaranteed, and under what conditions?
- Why should the central operation produce the claimed effect?

If not, restructure before polishing details. The note should use what is already in the reader's head, but must not require the paper's section structure to supply its missing logic.

---

## Figures from the paper

When a diagram or figure from the paper would genuinely aid understanding — architecture overviews, training pipelines, performance curves — embed it using an extract marker that the `extract_figures.py` script can process automatically.

### Step 1 — Read the page and identify bounds

Use the `Read` tool on the PDF, specifying the page number that contains the figure. The tool renders the page and you will see it directly as an image — no intermediate step needed.

Visually identify where the figure starts and ends vertically, including its caption. Express as fractions of the page height: 0.0 = top edge, 1.0 = bottom edge. Be generous — it's better to include a little whitespace than to clip content.

### Step 2 — Write the marker

```
![[descriptive-name.png]]
%%extract fig=N file="descriptive-name.png" y0=0.12 y1=0.58%%
```

- `fig` — the figure number as printed in the paper (used to locate the page)
- `file` — output filename; use a descriptive slug, not `figure-5.png`
- `y0` / `y1` — normalized vertical bounds you identified in Step 1

The `![[...]]` embed shows a broken-image placeholder in Obsidian until the script runs. The `%%extract%%` marker is invisible in reading view.

After writing the note, **run the extract script automatically** from the project root (do not tell the user to do it themselves):

```
uv run ${CLAUDE_SKILL_DIR}/scripts/extract_figures.py <note.md>
```

It extracts all marked figures, saves them to `imgs/`, and removes the markers from the note.

### What to embed

Only embed figures where a visual genuinely replaces words that are hard to convey in prose — architecture diagrams, multi-step pipelines, grids of examples. Don't embed every figure; ablation tables and bar charts rarely add value over a sentence of prose. Don't overdo it.

---

## Custom SVG diagrams

When the paper's own figures are missing, poor, or conflate things the discussion had to untangle, author your own SVG diagrams (a system overview, loss routing, a two-level hierarchy). Confirm with the user first (see "Before writing"). Save each to `imgs/` with a descriptive slug and embed with a display-width hint: `![[name.svg|680]]` — without the hint, embedded SVGs often render too small.

**Always build them with figkit**, the `figkit` command installed system-wide. Don't hand-write SVG and don't hand-place coordinates. figkit already enforces the house conventions: a CSS-variable palette with a dark-mode override, no inline styles, `context-stroke` arrowheads, legible text sizes, sub/superscript `tspan`s, and `<title>`/`<desc>`. It also lays out, measures, and checks the figure. If you ever must add raw SVG (`c.raw(...)`, `Figure(css=..., defs=...)`), keep to those same conventions: style by class, color by `var(--…)`, and use Unicode for math symbols.

Write a generator script in the scratchpad that does `from figkit import *`, and run it with `figkit gen.py` (a Python with figkit, fonttools, and `rsvg-convert` available). The worked example `scripts/examples/recap_pipeline.py` shows every feature; read it before your first figkit diagram in a session. To read the library itself, run `figkit -c "import figkit; print(figkit.__file__)"`.

### How figkit works

The model is **nested local coordinates**. Every node draws from its own (0, 0); containers place children with `translate()`. Nothing needs a global coordinate.

- **Layout nodes** size themselves from real font metrics: `VStack(*kids, gap, align)`, `HStack(*kids, gap, grow=i)` (child `i` takes the leftover width), `Pad`, `Box(child, role, w, h, pad, dash, valign)`, `Titled(title, child)` (a band), `Text(s, cls, role)`, `Para(s, cls)` (wraps to the available width, so never hand-split lines), `Spacer`.
- **`Canvas(fn)`** is the diagram inside a diagram. `fn(c)` or `fn(c, avail_w)` draws freely with the pen (`rect circle line arrow path text lines card chip chips cyl brace cross axis hist segments stacked place`; `card(x, y, title, sub, role, cy=wire_y)` is a titled box centered on a wire and returns its edges for attaching arrows). The canvas sizes itself to what was drawn, including anything at negative coords. Use `lin(d0, d1, r0, r1)` for data-to-pixel scales, and `c.place(node, x, y)` to nest layout back inside a drawing.
- **Markup in every string:** `x_t`, `V_{pre}`, `π^{k−1}`, `**bold**`, `{p|colored by role p}`.
- **Cross-node connectors:** `.tag("id")` any node, then `Figure(..., overlay=fn)` where `fn(c, A)` draws in figure coords and `A("id")` returns that node's `(x0, y0, x1, y1)`.
- **Text classes** (`STYLES`): `hd title sub lead ex leg legb ct tiny tinyb micro`. Roles: `g` data, `t` learned net, `p` token/latent, `e` good/output, `o` bad/rollout. Extra CSS classes go in `Figure(css=...)`.

### Check and render before finishing

`fig.save(path, preview=scratch_dir)` writes the SVG and then **checks the layout**. It warns on text overflowing its box, canvas, chip, or the figure, on an `HStack` row too wide for its parent, on text colliding with other text, and on a filled shape drawn on top of text. It also renders light and dark PNGs with the CSS variables resolved (via `rsvg-convert`). Fix every warning, then `Read` both PNGs. The checker doesn't see lines and arrows, so use the renders to catch arrows crossing labels or boxes, and tofu glyphs. Never ship an SVG you haven't looked at.

For illustrated, explanatory figures such as a step-by-step pipeline, prefer one row per step: a role-colored label box on the left, then a plain-language **lead sentence**, a one- or two-sentence body, and a small drawing that shows the step (a reward strip, a histogram, a timeline) instead of more text.

If a math glyph shows as a tofu box (common: `⊙ ⊗ ∈ ∘`), it'll usually still render in Obsidian. If it's load-bearing, draw it instead of trusting the font (e.g. `⊙` = a ring `circle` plus a small filled center `circle`).

---

## Algorithms

When a paper's contribution is partly an *algorithm* (a training loop, an inference procedure, a data-structure trick), reproducing the pseudocode is often worth more than prose. The vault renders pseudocode via **pseudocode.js**, using a fenced ` ```pseudo ` block with LaTeX `algorithmic` syntax:

````
```pseudo
\begin{algorithm}
\begin{algorithmic}
\REQUIRE input $x$
\STATE $y \gets f(x)$ \COMMENT{a comment}
\WHILE{not done}
    \FOR{each $i$}
        \STATE do something
    \ENDFOR
\ENDWHILE
\RETURN $y$
\end{algorithmic}
\end{algorithm}
```
````

Notes that matter for it to render:
- Use `\begin{algorithmic}` **without** the `[1]` argument.
- **Do not use `\caption{...}`** — it breaks rendering in this setup. Put the algorithm's name in the section header or a sentence above the block instead.
- Supported control words: `\REQUIRE`, `\ENSURE`, `\STATE`, `\IF`/`\ELSE`/`\ENDIF`, `\FOR`/`\ENDFOR`, `\WHILE`/`\ENDWHILE`, `\RETURN`, `\COMMENT{...}`. Inline math (`$...$`) works inside statements.

Don't transcribe every algorithm box mechanically — include one when the procedure *is* part of what makes the paper interesting and the reader would want it for reference.

---

## Output

Save as a `.md` file named after the short paper/method name. If `present_files` is available, write to `/mnt/user-data/outputs/` and present it. Otherwise render as a code block for the user to copy.
