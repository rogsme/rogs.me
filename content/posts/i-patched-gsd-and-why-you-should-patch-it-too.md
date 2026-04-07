+++
title = "I patched GSD, and why you should patch it too"
author = ["Roger Gonzalez"]
date = 2026-04-06
lastmod = 2026-04-06T21:41:55-03:00
tags = ["programming", "gsd", "claude", "opencode", "ai", "workflow"]
draft = false
+++

[GSD (Get Shit Done)](https://github.com/gsd-build/get-shit-done) is one of the best things that's happened to my development
workflow. If you haven't heard of it, it's a meta-prompting and context
engineering system for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (and [OpenCode](https://opencode.ai/)). It breaks your work into
milestones and phases, spawns fresh subagents with clean contexts for each task,
and solves the context rot problem that kills quality in long AI sessions. I
wrote about my full setup on my [AI toolbox page](/ai/).

GSD is great out of the box. But I wanted it to be _mine_.

I've been using GSD daily for weeks now, and over time I kept bumping into the
same friction points: the plan review was too shallow, the verification step was
too manual, and the UI audit felt incomplete. So I did what any developer would
do. I patched it.

This post is about the three patches I made, how they work, why I made them, and
how you can build your own. More importantly, it's about why you _should_ be
patching your tools. Not just GSD; any tool you use daily.


## The philosophy: own your tools {#the-philosophy-own-your-tools}

Here's the thing about AI tools right now: we're at a point in time where you
can design your own toolbox exactly the way you want it. Not just pick tools, but
_shape_ them. Customize them. Make them fit your brain, your workflow, your team.

GSD is open source. Its workflows are markdown files. Its commands are markdown
files. Everything is text. That means you can read them, understand them, and
rewrite the parts that don't work for you. You don't need to fork the whole
project or wait for an upstream PR to get merged. You just... change the files.

The tradeoff is that GSD updates will overwrite your changes. I'll show you how
I handle that. But first, let me show you what I changed and why.


## What I patched {#what-i-patched}

Three patches, each solving a specific pain point:

| Patch                          | Problem                                                   | Solution                                                            |
|--------------------------------|-----------------------------------------------------------|---------------------------------------------------------------------|
| Multi-model adversarial review | Stock review is shallow (5-point checklist, single model) | 6 independent AI models, 8-dimension adversarial framework          |
| Auto-verify (`--auto` flag)    | Verification is fully manual (test every item by hand)    | Automated playwright + curl checks, human only for subjective items |
| Cross-AI UI review             | Single auditor for inherently subjective UI evaluation    | 6 models independently scoring all 6 UI pillars                     |

Let's go through each one.


## Patch 1: Multi-model adversarial review {#patch-1-multi-model-adversarial-review}

This was the first patch and the one that started it all.

The stock GSD review runs a single model reviewing its own plans through a
5-point checklist. It's... fine. But after using it for a while, I noticed the
reviews were surface-level. They'd catch obvious things (missing tests, unclear
task descriptions) but they wouldn't catch architectural blind spots, failure
modes, or the kind of problems that bite you in production two weeks later.

So I replaced it with an 8-dimension adversarial review framework, executed by 6
independent AI models in parallel.


### The 6 reviewers {#the-6-reviewers}

All reviewers get the exact same prompt with the project context, phase plans,
and requirements. They review independently and don't see each other's output:

-   **GPT 5.4**, via `opencode run -m lazer/openai/gpt-5.4`
-   **Gemini 3.1 Pro**, via `opencode run -m lazer/gemini/gemini-3.1-pro-preview`
-   **MiniMax M2.5**, via `opencode run -m lazer/deepinfra/MiniMaxAI/MiniMax-M2.5`
-   **Kimi K2.5**, via `opencode run -m lazer/deepinfra/moonshotai/Kimi-K2.5-Turbo`
-   **GLM-5**, via `opencode run -m lazer/deepinfra/zai-org/GLM-5`
-   **Claude Opus**, via `claude -p --model opus`

These models are all available through [Lazer's LiteLLM proxy](https://lazertechnologies.com/) via OpenCode,
except Claude which runs through its own CLI. The key insight here is that
`opencode run -m <model>` lets you invoke _any_ model as a one-shot command,
which makes it perfect for this kind of parallel execution.


### The 8 review dimensions {#the-8-review-dimensions}

Instead of a 5-point checklist, each reviewer evaluates the plan across 8
dimensions:

1.  **Goal Alignment**: Does it actually solve the stated problem, or does it drift?
2.  **Architecture &amp; Design Coherence**: Does it fit the existing system, or fight it?
3.  **Failure Mode Analysis**: What happens when things go wrong?
4.  **Dependency &amp; Ordering Risks**: Are there hidden sequencing constraints?
5.  **Security &amp; Data Integrity**: Are new attack surfaces introduced?
6.  **Testing &amp; Verification Strategy**: Will the tests actually catch regressions?
7.  **Operational Readiness**: How will you know if it's broken in production?
8.  **Missing Pieces**: What implicit assumptions need to be explicit?

Each dimension gets a verdict: **PASS**, **FLAG** (minor concern), or **BLOCK** (must
fix before execution). With evidence and actionable recommendations, not vague
advice.

The review prompt is deliberately adversarial. It tells the reviewer:

> You are a senior staff engineer conducting a deep adversarial review. Do not be
> polite; be precise. Your job is to find what will break, what was forgotten, and
> what will cause regret in 6 months. Assume the plan authors are competent but
> blind-spotted.


### How it runs {#how-it-runs}

When you run `/gsd:review` (or `/gsd-review` in OpenCode), the workflow:

1.  Detects which CLIs are available (`opencode` and `claude`)
2.  Gathers the phase context (PROJECT.md, ROADMAP.md, PLAN.md files, REQUIREMENTS.md, etc.)
3.  Builds a structured review prompt and writes it to a temp file
4.  Invokes all 6 reviewers **in parallel**; each one gets its own bash tool call

<!--listend-->

```bash
# All run simultaneously
opencode run -m lazer/openai/gpt-5.4 "$(cat /tmp/gsd-review-prompt-4.md)" > /tmp/gsd-review-gpt-5.4-4.md
opencode run -m lazer/gemini/gemini-3.1-pro-preview "$(cat /tmp/gsd-review-prompt-4.md)" > /tmp/gsd-review-gemini-pro-4.md
opencode run -m lazer/deepinfra/MiniMaxAI/MiniMax-M2.5 "$(cat /tmp/gsd-review-prompt-4.md)" > /tmp/gsd-review-minimax-4.md
opencode run -m lazer/deepinfra/moonshotai/Kimi-K2.5-Turbo "$(cat /tmp/gsd-review-prompt-4.md)" > /tmp/gsd-review-kimi-4.md
opencode run -m lazer/deepinfra/zai-org/GLM-5 "$(cat /tmp/gsd-review-prompt-4.md)" > /tmp/gsd-review-glm-5-4.md
claude -p --model opus "$(cat /tmp/gsd-review-prompt-4.md)" > /tmp/gsd-review-claude-4.md
```

Since they run in parallel, total review time is about 1-2 minutes regardless of
how many reviewers you have. The original version ran them sequentially, which
took ~6 minutes. More on that bug below.

1.  Combines all reviews into a `REVIEWS.md` file with a consensus summary

The consensus summary is the real gem. It highlights blockers (issues raised by
2+ reviewers), agreed concerns, divergent views, and (most importantly)
**unique insights** where a single reviewer caught something all others missed.
Those blind spots are exactly why multi-model review exists.

I don't have a single dramatic "GLM-5 saved the day" story, but the pattern is
clear across multiple uses: every review has at least one or two unique insights
from a single model. Different models have different biases, different training
data, and different ways of reasoning about code. When 5 out of 6 reviewers say
PASS and one says BLOCK, that's worth investigating.

After the review, you feed it back into planning:

```nil
/gsd:plan-phase 4 --reviews
```

The planner reads the REVIEWS.md and addresses the concerns. A plan that survives
adversarial review from 6 independent AI systems is _much_ more robust than one
reviewed by a single model.


## Patch 2: Auto-verify with `--auto` {#patch-2-auto-verify-with-auto}

The stock `verify-work` workflow is fully manual: you test every single item by
hand. The workflow presents each test, you check it manually, report pass or
fail. For a phase with 10-15 tests, that's a lot of time spent clicking around
and typing "yes" over and over for things that could obviously be automated.

My patch adds an `--auto` flag. Without it, the workflow is 100% identical to
the original. With it, the workflow tries to automate the mechanical checks
before falling through to the interactive loop.

Run it like this:

```nil
/gsd:verify-work 4 --auto
```


### What `--auto` does {#what-auto-does}

1.  **Checks for `playwright-cli`.** If it's not installed, warns you and offers to
    continue without it (UI tests become manual). If it is, you get automated
    browser checks.

2.  **Auto-detects the base URL.** Scans `.env`, `PROJECT.md`, `docker-compose.yml`,
    and `package.json` for common patterns. Presents options so you can confirm or
    change.

3.  **Pings the URL.** Makes sure the app is actually running before trying to test
    anything. If it's not reachable, offers retry/skip/change URL.

4.  **Checks for auth credentials.** Looks for test tokens and credentials in `.env`
    files, test fixtures, and seed scripts. For API tests, it'll ask for a bearer
    token or API key if it can't find one. For UI tests, it'll ask for login
    credentials or use a dev bypass if one exists.

5.  **Classifies each test.** Routes tests to the right tool:

| Test references                              | Tool                         |
|----------------------------------------------|------------------------------|
| Pages, routes, visual appearance, user flows | playwright-cli               |
| API endpoints, response codes, data shapes   | curl                         |
| Form submission → API response               | playwright-cli (covers both) |
| Performance feel, subjective UX              | stays interactive            |

1.  **Runs playwright smoke checks.** For UI tests: navigates to the page, checks it
    loads without console errors, verifies key elements are visible, does basic
    click navigation. Runs `playwright-cli show` so you can watch.

2.  **Runs curl checks.** For API tests: endpoint reachability, response shape
    verification, CRUD with cleanup (create a resource, verify it, update it,
    delete it, clean up), and error handling (invalid payload → 400, missing ID →
    404).

3.  **Reports and continues.** Shows you what passed, what failed, and what needs
    manual testing. Then drops into the normal interactive loop for remaining tests
    only.


### Confidence-based failure handling {#confidence-based-failure-handling}

Not all automated failures are created equal. The patch distinguishes between
high-confidence failures and low-confidence ones:

-   **High confidence** (wrong status code, missing element, 500 error) → marked as
    issues automatically
-   **Low confidence** (timeouts, flaky selectors, intermittent network issues) →
    stays pending for manual testing

The result: I typically only need to manually verify 2-3 subjective items instead
of 10-15 total tests. It dramatically reduces UAT time while keeping the human in
the loop for things that actually need human judgment.


## Patch 3: Cross-AI UI review {#patch-3-cross-ai-ui-review}

Same concept as the adversarial plan review, but for frontend code.

GSD has a built-in UI auditor that runs a 6-pillar visual audit: Copywriting,
Visuals, Color, Typography, Spacing, and Experience Design. Each pillar gets
scored 1-4. It's useful, but it's one model's opinion about something that's
inherently subjective.

My patch adds a step after the primary audit: the same 6 external models
independently score all 6 pillars and challenge the primary auditor's findings.
The prompt explicitly tells them:

> Do not be deferential to the primary review. If you think a score is wrong, say
> so. If you think a critical issue was missed, flag it. Different eyes catch
> different things.

The result is a score comparison table appended to `UI-REVIEW.md`:

```nil
| Pillar      | Primary | GPT-5.4 | Gemini | MiniMax | Kimi | GLM-5 | Claude | Avg |
|-------------+---------+---------+--------+---------+------+-------+--------+-----|
| Copywriting |     3/4 |     3/4 |    2/4 |     3/4 |  3/4 |   3/4 |    3/4 | 2.8 |
| Visuals     |     4/4 |     3/4 |    3/4 |     4/4 |  3/4 |   4/4 |    3/4 | 3.3 |
| ...         |         |         |        |         |      |       |        |     |
```

Plus sections for: issues the primary auditor missed (caught by 2+ cross-AI
reviewers), score disagreements worth investigating, and validated findings with
high confidence.

The workflow then routes you based on severity. If there are many issues (5+
fixes, any pillar ≤ 2/4, or cross-AI average below 16/24), it tells you to fix
before moving on and suggests the right GSD command. If things look good, it
suggests proceeding to the next phase.


## The patching infrastructure {#the-patching-infrastructure}

Now for the part that makes all of this sustainable: how do the patches survive
GSD updates?

GSD's workflows live in `~/.claude/get-shit-done/workflows/` (for Claude Code)
and `~/.config/opencode/get-shit-done/workflows/` (for OpenCode). When you run
`/gsd:update`, those directories get wiped and replaced with the latest version.
Your patches are gone.

My solution is a canonical storage system. All my patch source files live in
`~/.config/gsd-patches/`, versioned in my [dotfiles](https://git.rogs.me/rogs/dotfiles). After any GSD update, I
run one command to reapply everything.


### Directory structure {#directory-structure}

```nil
~/.config/gsd-patches/
├── claude/
│   ├── commands/
│   │   ├── review.md          # /gsd:review command definition
│   │   └── verify-work.md     # /gsd:verify-work command definition
│   └── workflows/
│       ├── review.md          # adversarial review workflow
│       ├── ui-review.md       # cross-AI UI review workflow
│       └── verify-work.md     # auto-verify workflow
├── opencode/
│   ├── command/
│   │   ├── gsd-review.md
│   │   └── gsd-verify-work.md
│   └── workflows/
│       ├── review.md
│       ├── ui-review.md
│       └── verify-work.md
├── bin/
│   ├── sync                   # copies patches to runtime locations
│   └── check                  # verifies drift and missing files
├── gsd-customizations.md      # changelog of what changed and why
└── README.md
```

The Claude and OpenCode versions are nearly identical; the only differences are
file paths (`~/.claude/` vs `~/.config/opencode/`) and command syntax
(`/gsd:review` vs `/gsd-review`).


### The sync script {#the-sync-script}

This is the entire sync script. It's embarrassingly simple:

```bash
#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-all}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

copy_file() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
  printf 'SYNC  %s -> %s\n' "$src" "$dst"
}

sync_claude() {
  copy_file "$ROOT/claude/workflows/review.md" "$HOME/.claude/get-shit-done/workflows/review.md"
  copy_file "$ROOT/claude/workflows/ui-review.md" "$HOME/.claude/get-shit-done/workflows/ui-review.md"
  copy_file "$ROOT/claude/workflows/verify-work.md" "$HOME/.claude/get-shit-done/workflows/verify-work.md"
  copy_file "$ROOT/claude/commands/review.md" "$HOME/.claude/commands/gsd/review.md"
  copy_file "$ROOT/claude/commands/verify-work.md" "$HOME/.claude/commands/gsd/verify-work.md"
}

sync_opencode() {
  copy_file "$ROOT/opencode/workflows/review.md" "$HOME/.config/opencode/get-shit-done/workflows/review.md"
  copy_file "$ROOT/opencode/workflows/ui-review.md" "$HOME/.config/opencode/get-shit-done/workflows/ui-review.md"
  copy_file "$ROOT/opencode/workflows/verify-work.md" "$HOME/.config/opencode/get-shit-done/workflows/verify-work.md"
  copy_file "$ROOT/opencode/command/gsd-review.md" "$HOME/.config/opencode/command/gsd-review.md"
  copy_file "$ROOT/opencode/command/gsd-verify-work.md" "$HOME/.config/opencode/command/gsd-verify-work.md"
}

case "$MODE" in
  all)
    sync_claude
    sync_opencode
    ;;
  claude)
    sync_claude
    ;;
  opencode)
    sync_opencode
    ;;
  *)
    printf 'Usage: %s [all|claude|opencode]\n' "$0" >&2
    exit 2
    ;;
esac

printf 'Done.\n'
```

After a `/gsd:update`:

```bash
~/.config/gsd-patches/bin/sync all
```

That's it. All patches reapplied in under a second.


### The check script {#the-check-script}

I also have a `check` script that verifies whether my runtime files match the
canonical source. It uses `cmp -s` to do a byte-for-byte comparison and reports
drift:

```bash
~/.config/gsd-patches/bin/check all

# Output:
VERSION claude   1.30.0
VERSION opencode 1.30.0
OK      /home/roger/.claude/get-shit-done/workflows/review.md
OK      /home/roger/.claude/get-shit-done/workflows/ui-review.md
OK      /home/roger/.claude/get-shit-done/workflows/verify-work.md
OK      /home/roger/.claude/commands/gsd/review.md
OK      /home/roger/.claude/commands/gsd/verify-work.md
OK      /home/roger/.config/opencode/get-shit-done/workflows/review.md
...
Status: clean
```

If anything drifted (maybe I edited a runtime file directly during debugging),
it shows `DIFF` and exits with code 1. Keeps me honest.


### The changelog {#the-changelog}

I maintain a `gsd-customizations.md` file that tracks every patch: what changed,
why, which GSD version it was patched against, and which files were modified.
This is crucial. When a GSD update changes the workflow format or adds new
features, I need to know exactly what I changed so I can adapt my patches to the
new version.

Here's a taste of what it looks like:

```markdown
## 2026-03-30 - Fix opencode hangs (remove 2>/dev/null), run reviewers in parallel

**GSD version:** 1.30.0
**Files modified:** `get-shit-done/workflows/review.md`, `get-shit-done/workflows/ui-review.md`

### What changed

- Removed `2>/dev/null` from all `opencode run` and `claude -p` invocation commands
- Changed reviewer invocation from **sequential** to **parallel**

### Why

Suppressing stderr with `2>/dev/null` caused `opencode run` to hang indefinitely;
opencode needs stderr for progress output and/or terminal detection. Removing the
redirect fixed the hangs immediately.
```


### Honesty moment {#honesty-moment}

I should mention: I haven't actually had a GSD update wipe my patches yet. I
haven't updated GSD since I started patching. So the sync/check system is built
and tested, but hasn't been battle-tested by a real update cycle. I'm confident
it'll work (it's just `cp` commands) but I want to be upfront about it. When
it does happen, I'll update this post.


## Bugs I found along the way {#bugs-i-found-along-the-way}

Patching GSD meant reading the stock workflows carefully, and that led me to find
(and fix) bugs that existed in the original:

**`2>/dev/null` on `opencode run` causes hangs.** The stock workflow suppressed
stderr on external CLI calls. Turns out, `opencode run` needs stderr for
progress output and/or terminal detection. Suppressing it causes the process to
hang indefinitely. Removing `2>/dev/null` fixed it immediately. Note: stderr
suppression on _other_ commands (like `ls`, `node`, `git`) is fine; it's only
the interactive CLI tools that break.

**`claude -p` doesn't support `--no-input`.** The stock workflow passed
`--no-input` to `claude -p`, which isn't a valid flag. It caused the Claude
reviewer to fail silently (exit code 1, empty output). Just removing the flag
fixed it.

**Sequential execution was unnecessary.** The stock workflow ran reviewers one at
a time. Since each reviewer is an independent process with no shared state,
there's no reason they can't run in parallel. Switching to parallel execution
(separate bash tool calls in a single message) cut review time from ~6 minutes
to ~1-2 minutes.

These fixes are now part of my patches and would benefit anyone patching GSD.


## How to make your own patches {#how-to-make-your-own-patches}

If you want to patch GSD yourself, here's how to start:

**1. Find the file you want to change.** GSD's workflows live in
`~/.claude/get-shit-done/workflows/` (Claude Code) or
`~/.config/opencode/get-shit-done/workflows/` (OpenCode). Commands are in
`~/.claude/commands/gsd/` or `~/.config/opencode/command/`. They're all markdown
files. Read them.

**2. Make your change in a canonical location.** Don't edit the runtime files
directly; they'll get wiped on update. Create a directory (I use
`~/.config/gsd-patches/`) and keep your modified versions there.

**3. Write a sync script.** It doesn't need to be fancy. Mine is just a series of
`cp` commands. The point is that reapplying patches should be one command, not a
manual checklist.

**4. Write a check script.** Optional but useful. Being able to run `check all` and
see if your runtime matches your canonical source saves debugging time.

**5. Keep a changelog.** Track what you changed, why, and against which GSD
version. Future you will thank present you.

**6. Don't forget the command files.** I missed this on my first patch. GSD has two
sets of files: workflows (`get-shit-done/workflows/`) and commands
(`commands/gsd/`). If you patch a workflow, check if the corresponding command
file needs updating too. They're separate files that reference each other.

**7. Version control it.** Put your patches directory in your dotfiles. Mine are at
[git.rogs.me/rogs/dotfiles](https://git.rogs.me/rogs/dotfiles) under `.config/gsd-patches/`. This means if I set up a
new machine, my patches come with me.


## Ideas for your own patches {#ideas-for-your-own-patches}

You don't have to copy my patches. The beauty of this approach is that you can
shape GSD to fit _your_ workflow. Here are some ideas:

-   **Different reviewer models.** Maybe you have access to models I don't, or you
    want fewer reviewers for faster reviews. Swap the model strings in `review.md`.
-   **Custom review dimensions.** The 8 dimensions I use are tuned for backend work.
    If you're doing mobile development, you might want dimensions for offline
    behavior, battery impact, or app store compliance.
-   **Different auto-verify tools.** I use `playwright-cli` and `curl`. If your stack
    uses Cypress, Selenium, or `httpie`, adapt the classify/execute steps.
-   **Notification integration.** Add a step that pings your phone (via [ntfy](https://ntfy.sh/),
    Pushover, Telegram) when a review is complete.
-   **Custom UAT templates.** The verify-work workflow extracts tests from SUMMARY.md
    files. You could add a step that also pulls from your team's QA checklist or
    acceptance criteria document.


## Show me the code {#show-me-the-code}

All my patches are public. If you want to see the exact files behind everything
described in this post:

-   **Patch files:** [git.rogs.me/rogs/dotfiles](https://git.rogs.me/rogs/dotfiles) under `.config/gsd-patches/`
-   **Full AI workflow:** [rogs.me/ai](/ai/)
-   **GSD project:** [github.com/gsd-build/get-shit-done](https://github.com/gsd-build/get-shit-done)

Feel free to steal whatever is useful to you. That's what dotfiles are for.

See you in the next one!
