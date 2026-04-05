---
title: "My AI Toolbox"
date: 2026-02-19T12:00:00-03:00
lastmod: 2026-04-04T12:00:00-03:00
---

I joined [Lazer Technologies](https://lazertechnologies.com/) in 2021, took a small detour in 2022 (but stayed on Slack and kept helping with things), and came back full-time in early 2024. In the last year or so, AI tools have completely changed how I work. Not in a "robots are coming for your job" way, but in a "I got promoted to team lead and my team is a bunch of really fast, really eager AI agents" way.

I lead a team of agents that handle most of the heavy lifting. My job is to manage them, steer them in the right direction, and make sure their output actually makes sense. It's not that I'm doing less work, it's that I can do _much_ more with an entire team behind me.

This page is a living document. I update it regularly as my workflow evolves (which happens at least twice a week, honestly). If you're curious about how AI-assisted development looks in practice, this is my setup, warts and all.

## The arsenal

I use three main tools for coding, and I like to think of them as weapons:

| Tool | Analogy | Use case |
|------|---------|----------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) + [GSD](https://github.com/gsd-build/get-shit-done) | The cannon | Big end-to-end epics, multi-file features, full milestones |
| [OpenCode](https://opencode.ai/) + [GSD](https://github.com/gsd-build/get-shit-done) + built-in agents | The arsenal | GSD overflow, medium tasks, overnight jobs, multi-model workflows |
| [Aider](https://aider.chat/) | The sniper | Precise single-file fixes, docstrings, targeted edits |

My time is split roughly 50/50 between Claude Code and OpenCode, with Aider holding its niche for single-file precision.

The split exists because of usage limits (more on that below) and because OpenCode has gotten _really_ good. GSD supports both tools natively, so I can run the same workflow on either one. My default flow looks like this: I start the day with Claude Code running GSD using Claude Opus. When I hit the usage limit (which happens way faster than it should; more below), I switch to OpenCode and continue with GPT 5.4 running GSD. For anything that doesn't need GSD (running skills, creating PRs, fixing tests, quick questions), I go straight to OpenCode. This keeps Claude Code dedicated as a GSD machine and stretches my usage across the day.

## Claude Code + GSD: The cannon

[GSD (Get Shit Done)](https://github.com/gsd-build/get-shit-done) is a meta-prompting and context engineering system for Claude Code (and now OpenCode too). The way it uses multiple subagents to explore the codebase, investigate, execute and self-review is plain magic. It solves context rot (the quality degradation that happens as Claude fills its context window) by spawning fresh agents with clean contexts for each task.

I'm paying $100/month for [Claude Max](https://claude.ai/) because I also use it for my personal projects ([YAMS](https://yams.media/), [ForgeLLM](https://gitlab.com/rogs/forge-llm), [montevideo.restaurant](https://montevideo.restaurant/), [themefetch](https://git.rogs.me/rogs/themefetch), and more). I like to keep my work and personal accounts separate. We get Claude Code for free at Lazer, but I prefer having my own.

### How I use it

When I pick up a big ticket, like an entire epic or a feature that touches multiple parts of the codebase, I use GSD milestones. My general rule of thumb is one milestone per ticket. If tickets are small, I group them into a single milestone with phases that fulfill each one.

The GSD flow goes like this:

```
/gsd:new-project or /gsd:new-milestone
          ↓
/gsd:discuss-phase N    ← shape the implementation
          ↓
/gsd:plan-phase N       ← research + plan + verify
          ↓
/gsd:execute-phase N    ← parallel execution with fresh contexts
          ↓
/gsd:verify-work N      ← acceptance testing (now with --auto!)
          ↓
        repeat
```

GSD is basically my old custom planning → execution → review flow on crack. It's open source, maintained by a big community, and advances way faster than anything I could build alone.

### My GSD workflow

Here's my actual step-by-step flow for a typical phase. This is more detailed than the diagram above because it includes my custom patches (the adversarial review, auto-verify, and UI review).

```
/gsd:discuss-phase N
        ↓
/gsd:ui-phase N             ← only for phases with frontend work
        ↓
/gsd:plan-phase N --research
        ↓
/gsd:review --phase N       ← 6-model adversarial review (my patch)
        ↓
/gsd:plan-phase N --reviews --research
        ↓
/gsd:review --phase N       ← second review pass if too many concerns remain
        ↓                     (repeat plan-with-reviews until clean)
/gsd:execute-phase N
        ↓
/gsd:verify-work N --auto   ← auto-verify with Playwright/curl (my patch)
        ↓
/gsd:ui-review N            ← cross-AI UI audit (my patch, frontend phases)
        ↓
  fix if needed             ← /gsd:fast or /gsd:quick depending on severity
        ↓
/gsd:ship N
```

A few notes on how this plays out in practice:

**The discuss → plan → review loop.** I always start with `/gsd:discuss-phase` to lock in my preferences. If there's UI work, `/gsd:ui-phase` creates the design contract before any planning happens. Then I plan with `--research` to get the domain investigation. After the first plan, I run `/gsd:review --phase N` which triggers my 6-model adversarial review patch. The reviewers produce a `REVIEWS.md` with blockers, concerns, and unique insights. I feed that back into planning with `/gsd:plan-phase N --reviews --research`, and if the second plan still has too many concerns, I review again. Usually one review-plan cycle is enough; occasionally it takes two.

**Verify with `--auto`.** After execution, I run `/gsd:verify-work N --auto` which triggers my auto-verify patch. It classifies tests and runs what it can automatically: Playwright for UI checks (page loads, key elements visible, no console errors), curl for API checks (endpoint reachability, response shape, CRUD operations). Whatever it can't verify automatically (subjective UX, performance feel) falls through to the interactive loop where I test manually. This cuts my UAT time significantly.

**UI review and fixes.** For frontend phases, `/gsd:ui-review N` runs the primary 6-pillar audit plus my cross-AI perspective patch. If the review finds issues, I check the severity. For simple fixes (copy, spacing, color values), I use `/gsd:fast fix the N issues from the phase X UI review`. For structural fixes (layout, component hierarchy), I use `/gsd:quick`. The UI review itself tells you which approach to use based on the score.

**When Claude runs out of budget.** If I hit the usage limit mid-flow, I `/clear`, switch to OpenCode, and continue from wherever I left off. The `.planning/` state carries over. On OpenCode, the GSD commands use a slightly different format (`/gsd-review` instead of `/gsd:review`, `/gsd-verify-work` instead of `/gsd:verify-work`), but the workflow is identical.

### My Claude Code config

I default to the 1M context Opus model (`opus[1m]`). The extra context is great, but I try to keep actual usage under 40-50% of that window. Going higher burns through tokens faster and invites context rot. Think of it as having a large workshop: you don't need to fill every corner to get work done.

On permissions: I use `skipDangerousModePermissionPrompt: true`. I know this sounds scary, and I used to be firmly against it. But after months of using GSD, I found that it's extremely disciplined about what it does. It respects `.planning/` boundaries, uses proper git workflows, and I've never had it do something destructive. I'm still vigilant (I review diffs, I watch what it's doing), but the constant permission prompts were slowing me down more than they were protecting me. If you're not comfortable with this, don't do it. I only got here after building a lot of trust with the tool.

I also have hooks set up: a notification system (ntfy) that pings my phone when Claude needs input or finishes a task, a GSD context monitor that tracks context window usage, a prompt guard, and a statusline that shows GSD state in the terminal. You can see all of these in my [dotfiles](https://git.rogs.me/rogs/dotfiles).

### Problems with Claude Code

#### The usage limit problem

I need to be honest about this: Claude Code's usage limits have gotten rough.

Starting around late March 2026, something changed. Sessions that used to last hours started burning through in under 90 minutes. I'd start in the morning with a fresh 5-hour window and hit the limit in about 45 minutes doing the same kind of work that used to last all morning. I'm not alone. Anthropic acknowledged the issue, saying they're "aware people are hitting usage limits in Claude Code way faster than expected" and that it was their "top priority." There's a combination of intentional peak-hours throttling and what appears to be a caching regression causing the problem.

Anthropic engineer [Thariq Shihipar confirmed on X](https://x.com/trq212/status/2037254607001559305) that session limits now drain faster during weekday peak hours (5am-11am PT) to "manage growing demand." The [GitHub issue tracking the bug](https://github.com/anthropics/claude-code/issues/38335) has been accumulating reports since March 23, and threads on [r/ClaudeAI](https://www.reddit.com/r/ClaudeAI/) and [r/ClaudeCode](https://www.reddit.com/r/ClaudeCode/) have been flooded with complaints. One thread titled "20x max usage gone in 19 minutes" accumulated over 330 comments in 24 hours. A user who reverse-engineered the Claude Code binary found two independent bugs that break prompt caching, silently inflating costs by 10-20x.

For me, it got bad enough that I've considered canceling my $100/month subscription. Just this week, I hit 50% of my weekly usage by Tuesday, and my usage resets on Friday. That's scary when you depend on the tool for your daily work. It's the single biggest reason I diversified so aggressively into OpenCode. I can't afford to sit around waiting for limits to reset when there's work to do.

#### The Anthropic third-party ban

As if the usage limits weren't enough, on April 4, 2026, Anthropic dropped another bomb: third-party harnesses like [OpenClaw](https://openclaw.ai/) can no longer use your Claude Max subscription limits. They emailed subscribers saying these tools "put an outsized strain on our systems" and that they need to "prioritize customers using core products."

Let me translate that: I'm paying $100/month. I _am_ a customer. But apparently I'm not using the product the "right way" because I'm accessing Claude through OpenClaw on Telegram instead of through claude.ai. My OpenClaw setup was running Opus 4.6 for personal tasks: managing my calendar, maintaining my open source projects, doing research. Now if I want to keep using Claude with OpenClaw, I need to pay _extra_ on top of my subscription through their "extra usage" pay-as-you-go option.

This also killed [CLIProxyAPI](/2026/02/use-your-claude-max-subscription-as-an-api-with-cliproxyapi/), which I wrote about just two months ago. That tool let me use my Max subscription with Emacs packages like forge-llm and magit-gptcommit. Dead now. Two months. I wrote an entire blog post about it, shared my config, and now it's useless.

I moved everything to [Lazer's LiteLLM proxy](https://lazertechnologies.com/) (a perk we have as employees) running [GLM-5](https://huggingface.co/zai-org/GLM-5) for OpenClaw and my Emacs tools. GLM-5 is a legitimately great model: it's open source, MIT licensed, and benchmarks competitively with frontier models on agentic tasks. But that's not the point. The point is that I was paying for a service and they changed what I was paying for. If you don't have access to a company proxy, [OpenRouter](https://openrouter.ai/) is a good alternative for routing to multiple models, or you can use API keys directly for whatever model you prefer.

Between the usage limits getting worse and the third-party ban, my relationship with Anthropic as a paying customer has taken a serious hit. The product is still excellent (Claude is the best model for coding, no question) but the business decisions around it are pushing people away. I've gone from enthusiastically recommending Claude Max to actively telling people to have a backup plan. I wrote more about this in [Anthropic is pushing away its paying customers](/2026/04/anthropic-is-pushing-away-its-paying-customers/).

#### When it goes off the rails

Rarely happens. I've seen it go off the rails maybe twice. When it does, I use GSD's built-in commands to steer it back on track. If it's _really_ far gone, I stop, `git revert`, and restart the GSD process from the top. But honestly, I've always been able to course-correct without a full reset.

## OpenCode + GSD: The arsenal

[OpenCode](https://opencode.ai/) is half my workflow. GSD runs on OpenCode natively, which means I get the same milestone-driven, context-engineered workflow I have with Claude Code, but with any model I want.

### How I use it

For GSD work, OpenCode is my overflow. When Claude Code hits usage limits, I switch to OpenCode running GPT 5.4 and pick up right where I left off. The GSD state lives in `.planning/`, so the handoff is seamless: same project files, same milestones, different engine.

For non-GSD work, OpenCode is my daily driver. Creating PRs, running tests, committing changes, asking quick questions, fixing small bugs. Anything that doesn't need a full GSD orchestration goes straight to OpenCode. This keeps Claude Code's precious usage budget reserved for the big GSD stuff.

I also run OpenCode as a [persistent server on my main machine](/2026/04/opencode-as-a-server-ai-agents-that-work-while-i-sleep/), accessible from anywhere through my WireGuard VPN. I can start coding sessions from my MacBook Air at a coffee shop or from my phone on the couch. Just open a browser and go to my OpenCode domain. This is my primary mobile coding setup. I also have a [mosh + tmux + ntfy setup](/2026/02/claude-code-from-the-beach-my-remote-coding-setup-with-mosh-tmux-and-ntfy/) for Claude Code specifically (since it's terminal-only), but for everything else, OpenCode's web UI is a massive quality-of-life upgrade. No Termux, no SSH keys, no jump box. Just a browser.

### The overnight crew

Since the OpenCode server runs 24/7, I put it to work while I sleep. Using the [opencode-scheduler](https://github.com/different-ai/opencode-scheduler) plugin, I have three jobs that run between 2 AM and 4 AM:

- **2 AM, Test gap finder**: Scans the codebase for untested or under-tested code, writes the missing tests, and opens a PR.
- **3 AM, Documentation updater**: Checks for outdated or missing docstrings and README sections, updates them, and opens a PR.
- **4 AM, Convention enforcer**: Reviews code for style and convention violations that linters don't catch, fixes them, and opens a PR.

When I log in the next morning, I usually have 1-3 PRs waiting for me. Most are good to go with minor tweaks. It's like having a junior developer who works the night shift. Not perfect, but reliable, and surprisingly good at the boring stuff.

This also helps with the Claude Code usage problem. These jobs run on OpenCode with models from Lazer's proxy, so they don't touch my Claude usage at all. More work gets done, less pressure on the limits.

### Models and providers

OpenCode connects to [Lazer's LiteLLM proxy](https://lazertechnologies.com/), which gives me access to a bunch of models. Here's what I'm actually using:

**Primary workhorses (daily drivers for GSD + plan/build):**
- **GPT 5.4**: My default model. It's verbose and careful; not quite as good as Opus on average, but close. Sometimes it matches Opus, sometimes it falls just short. More than good enough to keep GSD running when Claude is out of budget.
- **GPT 5.3 Codex**: The build agent for OpenCode's plan/build flow. Around Sonnet-level. Sometimes it's a bit too simple for complex tasks, and I'm considering bumping its reasoning effort from medium to high, but for now it gets the job done.

**GSD review panel (the 6 reviewers for my adversarial review patches):**
- GPT 5.4, Gemini 3.1 Pro, MiniMax M2.5, Kimi K2.5, GLM-5 (all via OpenCode through Lazer), plus Claude Opus (via `claude -p`). More on this in the GSD patches section below.

**Quick tasks and speed demons:**
- **Qwen3 variants** and **GPT OSS 120B**: Insanely fast. I use these for tiny things like generating commits, asking quick questions, anything where speed matters more than depth. Not my daily drivers, but great to have in the roster.

**On thin ice:**
- **Kimi K2.5**: The weakest of the bunch. It's thorough for reviews and I've gotten good feedback from it, but it's slow (probably DeepInfra, not Kimi's fault) and its output is very similar to the other reviewers. It's the one most likely to get dropped.
- **Gemini 3.1 Pro**: I used to love Gemini 2.5 Pro. It was my planning agent, and it was genuinely great. Then the Gemini 3 upgrade happened and it was terrible for my workflow. Everyone was praising it, but it simply didn't work reliably with my agent setup. Gemini 3.1 improved things, but it never recovered to 2.5 Pro levels. My workflow was demanding enough that I hit the rough edges faster than most; colleagues who were praising Gemini 3 ended up reaching the same conclusions I did, just later. I still keep Gemini in the review panel because it occasionally catches things the others miss, but it's no longer trusted with planning or execution.

### OpenCode config

Here's what my `opencode.json` looks like right now:

```json
{
  "model": "openai/gpt-5.4",
  "agent": {
    "plan": {
      "model": "openai/gpt-5.4",
      "reasoningEffort": "xhigh"
    },
    "build": {
      "model": "openai/gpt-5.3-codex",
      "reasoningEffort": "xhigh"
    }
  },
  "provider": {
    "lazer": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Lazer",
      "options": {
        "baseURL": "https://llm.lazertechnologies.com/v1"
      },
      "models": {
        "deepinfra/MiniMaxAI/MiniMax-M2.5": { "name": "MiniMax-M2.5" },
        "deepinfra/Qwen/Qwen3-Coder-480B-A35B-Instruct-Turbo": { "name": "Qwen3 Coder 480B Turbo" },
        "deepinfra/moonshotai/Kimi-K2.5-Turbo": { "name": "Kimi K2.5" },
        "deepinfra/openai/gpt-oss-120b-Turbo": { "name": "GPT OSS 120B Turbo" },
        "deepinfra/zai-org/GLM-5": { "name": "GLM-5" },
        "gemini/gemini-3.1-pro-preview": { "name": "Gemini 3.1 Pro Preview" },
        "gemini/gemini-3-flash-preview": { "name": "Gemini 3 Flash Preview" },
        "openai/gpt-5.3-codex": { "name": "GPT 5.3 Codex" },
        "openai/gpt-5.4": { "name": "GPT 5.4" }
        "openai/gpt-5.4-mini": { "name": "GPT 5.4 Mini" }
      }
    }
  },
  "plugin": ["opencode-scheduler"]
}
```

The full config with all experimental models, keybinds, permissions, and MCP servers is in my [dotfiles](https://git.rogs.me/rogs/dotfiles).

## GSD patches: Making GSD my own

This is the section I'm most proud of. GSD is great out of the box, but I've patched three of its workflows to make them significantly better for my setup. These patches survive GSD updates through a canonical storage system: all source files live in `~/.config/gsd-patches/` and get synced to both Claude Code and OpenCode runtimes.

The patches are maintained in my [dotfiles](https://git.rogs.me/rogs/dotfiles) under `.config/gsd-patches/`. After a `/gsd:update` wipes the runtime files, I just run `~/.config/gsd-patches/bin/sync all` to reapply everything.

### Patch 1: Multi-model adversarial review

**This is the headline feature.** The stock GSD review runs a single model reviewing its own plans. My patch replaces that with 6 independent AI models reviewing every plan in parallel, using an 8-dimension adversarial framework.

The 6 reviewers:
- GPT 5.4, Gemini 3.1 Pro, MiniMax M2.5, Kimi K2.5, GLM-5 (all via `opencode run -m`)
- Claude Opus (via `claude -p`)

Each reviewer gets the exact same prompt with the project context, phase plans, and requirements. They independently evaluate the plan across 8 dimensions:

1. **Goal Alignment**: Does the plan actually solve the stated problem?
2. **Architecture & Design Coherence**: Does it fit the existing system?
3. **Failure Mode Analysis**: What happens when things go wrong?
4. **Dependency & Ordering Risks**: Are there hidden sequencing constraints?
5. **Security & Data Integrity**: Are new attack surfaces introduced?
6. **Testing & Verification Strategy**: Will the tests actually catch regressions?
7. **Operational Readiness**: How will you know if it's broken in production?
8. **Missing Pieces**: What implicit assumptions need to be explicit?

Each dimension gets a verdict (PASS / FLAG / BLOCK) with evidence and actionable recommendations. The reviews are combined into a `REVIEWS.md` file with a consensus summary that highlights blockers (issues raised by 2+ reviewers), agreed concerns, divergent views, and (most importantly) unique insights where a single reviewer caught something all others missed. Those blind spots are exactly why multi-model review exists.

All 6 reviewers run in parallel, so the total review time is ~1-2 minutes. A plan that survives adversarial review from 6 independent AI systems is _much_ more robust than one reviewed by a single model.

### Patch 2: Auto-verify with `--auto`

The stock `verify-work` workflow is fully manual: you test every single item by hand. My patch adds an `--auto` flag that automates the mechanical checks so you only need to manually verify subjective items.

When you run `/gsd:verify-work N --auto`, the workflow:

1. Checks if `playwright-cli` is available (graceful fallback if not)
2. Auto-detects the base URL from `.env` or `PROJECT.md`
3. Pings the URL to confirm the app is running
4. Checks for auth credentials in `.env` or fixtures
5. Classifies each test as a **playwright candidate** (UI elements, page loads), **curl candidate** (API endpoints, response shapes), or **interactive** (subjective UX, performance feel)
6. Runs Playwright smoke checks for UI tests: page loads, key elements visible, no console errors
7. Runs curl checks for API tests: endpoint reachability, response shape, CRUD with cleanup, error handling
8. Reports results and falls through to the interactive loop for anything that couldn't be auto-verified

High-confidence failures (wrong status code, missing element, 500 error) get marked as issues automatically. Low-confidence failures (timeouts, flaky selectors) stay pending for manual testing. The result: I typically only need to manually verify 2-3 subjective items instead of 10-15 total tests. It dramatically reduces UAT time while keeping the human in the loop for things that need human judgment.

### Patch 3: Cross-AI UI review

Similar concept to the adversarial plan review, but for frontend code. After GSD's built-in UI auditor runs a 6-pillar visual audit (Copywriting, Visuals, Color, Typography, Spacing, Experience Design), my patch invokes the same 6 external models to independently score all 6 pillars and challenge the primary auditor's findings.

The result is a score comparison table showing where models agree and disagree, a list of issues the primary auditor missed (caught by 2+ cross-AI reviewers), and score disagreements that warrant investigation. The workflow then routes you to the appropriate fix command based on severity. If there are many issues or any pillar scores poorly, it tells you to fix before moving on; if things look good, it suggests proceeding to the next phase.

UI evaluation is inherently subjective. Different models have different aesthetic sensibilities. A single auditor will always have blind spots. The multi-model approach makes those blind spots visible.

### Patch changelog

I maintain a detailed changelog of all patches in `.config/gsd-patches/gsd-customizations.md` in my [dotfiles](https://git.rogs.me/rogs/dotfiles). It tracks what changed, why, and which GSD version the patch was made against. If you're curious about the evolution or want to adapt the patches for your own setup, that's the place to look.

## Aider: The sniper

[Aider](https://aider.chat/) is for precision. Let's say Claude Code or OpenCode did a great job on a feature, but missed docstrings in one file. Or left a TODO that needs resolving. Or the formatting is off in a single module. I don't need to fire up an entire agent orchestration system for that, I just point Aider at the file and fix it.

My Aider config has aliases for all the models I use through Lazer's proxy:

```yaml
alias:
  # OpenAI
  - "lazer-gpt5.3-codex:openai/openai/gpt-5.3-codex"
  - "lazer-gpt5.4:openai/openai/gpt-5.4"
  # Gemini
  - "lazer-gemini-flash:openai/gemini/gemini-3-flash-preview"
  - "lazer-gemini-pro:openai/gemini/gemini-3.1-pro-preview"
  # Grok
  - "lazer-grok:openai/xai/grok-code-fast-1"
  # Open source
  - "lazer-qwen3:openai/deepinfra/Qwen/Qwen3-235B-A22B-Instruct-2507"
  - "lazer-qwen3-coder:openai/deepinfra/Qwen/Qwen3-Coder-480B-A35B-Instruct-Turbo"
  - "lazer-kimi-k2.5:openai/deepinfra/moonshotai/Kimi-K2.5"
  - "lazer-minimax-m2.5:openai/deepinfra/MiniMaxAI/MiniMax-M2.5"
  - "lazer-gpt-oss-120b:openai/deepinfra/openai/gpt-oss-120b-Turbo"
  - "lazer-glm-5:openai/deepinfra/zai-org/GLM-5"
```

So I can do `aider --model lazer-gpt5.4` or `aider --model lazer-glm-5` and be off to the races. Aider is still the sniper, and it's still great at what it does.

## Voice AI: Talking to my tools

This is a recent addition to my workflow, and it's been a game changer. I use [Handy](https://handy.computer/) for local, offline speech-to-text. It's free, open source, and runs entirely on my machine. No audio ever leaves my computer.

Handy uses NVIDIA's [Parakeet V3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) model for transcription, which is a 600M parameter model that runs on CPU (no GPU required). It works amazingly well on both my main machine (the Ryzen 9 beast) and my MacBook Air M1. The workflow is dead simple: I put my cursor in a text field, press the shortcut to start Handy, speak, press the shortcut again, and the transcribed text gets auto-pasted into whatever I was typing in. No copy-paste needed.

I use two modes depending on the context:

**With post-processing (for written communication):** When I'm writing Slack messages, documentation, emails, or anything that needs to read like polished written text, I enable Handy's built-in post-processing. On my MacBook Air, it sends the raw transcription through GPT OSS 120B Turbo via Lazer's proxy. On my main machine, it uses Gemma 3 through [Ollama](https://ollama.com/) (fully local, no network needed). The post-processor cleans up filler words, fixes grammar, and restructures spoken rambling into proper written sentences.

**Raw transcription (for talking to AI):** When I'm talking to Claude, OpenCode, or any AI tool, I skip post-processing entirely. The AI can handle messy spoken input just fine. I just tell it "this is spoken, not written" and it adjusts. This page you're reading right now? Most of the content was dictated through Handy into Claude, and Claude cleaned it up into proper prose. It's a fantastic way to do brain dumps without the friction of typing everything out.

Voice input has made me faster at the things I used to dread: writing long Slack messages, documenting decisions, explaining context in PRs, and especially communicating with AI tools. English is my second language, and sometimes my thoughts flow better when I speak them than when I type them. Handy bridges that gap.

## Beyond coding

AI isn't just for writing code. Here's where else I use it (and yes, most of this happens from Emacs, because of course it does):

- **PR creation and commits**: I built Claude Code skills (`create-pr` and `commit`) that handle the entire PR pipeline: convention review, linting, type checking, testing, and PR creation with auto-generated descriptions. The `commit` skill analyzes the repo's own commit history to match its conventions, so it works on any project without configuration. These skills work on both Claude Code and OpenCode (OpenCode reads skills from Claude's directory). I also have [forge-llm](https://gitlab.com/rogs/forge-llm) and [magit-gptcommit](https://github.com/douo/magit-gptcommit) in my Emacs setup. These used to run through [CLIProxyAPI](/2026/02/use-your-claude-max-subscription-as-an-api-with-cliproxyapi/) (which is now dead), so I moved them to [Lazer's LiteLLM proxy](https://lazertechnologies.com/). forge-llm now defaults to GLM-5, and magit-gptcommit uses Qwen3 Coder 480B Turbo. Both have OpenAI models as fallbacks. If you don't have access to a company proxy like Lazer's, [OpenRouter](https://openrouter.ai/) is a solid alternative, or you can use your own API keys directly for the model you prefer.
- **Proofreading**: English is not my first language (hola! 🇻🇪), so I use the Claude website a lot for proofreading emails, Slack messages, documentation, you name it.
- **Research and "searches"**: I use Claude as a faster, friendlier Google. Investigations, quick questions, exploring ideas.
- **Personal assistant**: I have an [OpenClaw](https://github.com/openclaw/openclaw) agent on my Telegram chats that manages my calendar, contacts, helps me maintain my open source projects, does research, and is just an all-around good guy. It _was_ running on Claude Opus 4.6 through my Max subscription, and it was perfect. Then [Anthropic decided to block third-party harnesses from using subscription limits](https://x.com/bcherny/status/2040206440556826908) (effective April 4, 2026), so I had to rip out the model and replace it with [GLM-5](https://huggingface.co/zai-org/GLM-5) running through [Lazer's LiteLLM proxy](https://lazertechnologies.com/). GLM-5 is a great model, genuinely impressive for agentic tasks, but I shouldn't have had to make this change. I am paying $100/month and Anthropic pulled the rug.
- **Coding from anywhere**: I have two setups for remote coding. My primary setup is [OpenCode as a server](/2026/04/opencode-as-a-server-ai-agents-that-work-while-i-sleep/), a persistent OpenCode instance on my main machine, accessible from any browser through WireGuard. For Claude Code specifically (since it's terminal-only), I still use my [mosh + tmux + ntfy setup](/2026/02/claude-code-from-the-beach-my-remote-coding-setup-with-mosh-tmux-and-ntfy/). Both connect directly to my main machine through WireGuard; no jump box needed anymore.

## The before and after

Before AI tools, my workflow was: grab a task, study the code, read tons of documentation (internal and external), ask teammates for help, confirm my thought process, then code manually little by little: add something, run it, see if it produces what I expect, add a little more, repeat.

Now? It's hard to quantify exactly, but:

- Tickets that used to take **1 week** now take a **couple of days**.
- Tickets that used to take **3 days** can be done in **half a day**.
- A huge investigation (spike) that would've taken me **3-5 days** was finished in **1 day**, with way more detail than I could've produced myself.
- On a past project, we were tasked with **3 months of work** that we needed to squeeze into **1 month**. With AI (I was only using my custom OpenCode flow at the time), we finished in **3 weeks**. We even had some buffer days to spare.

But the speed isn't even the biggest change. What really shifted is the _type_ of work I do now:

- I take on more ambitious tasks. I'm less anxious about picking up things I've never done before (they do come from time to time! I certainly don't know it all, and in this line of work you never stop learning!).
- PR reviews are no longer a chore.
- I spend way more time on **architecture** than on implementation. To me, architecture is more important than code. You can have the prettiest code ever, but if it's poorly architected (for example, can't scale or someone made bad design decisions) it doesn't matter. A well-architected system can endure messy code much better than a poorly-architected one can endure clean code.

## The honest stuff

AI is not perfect. Here's what I've learned the hard way:

- **AI can't be simple.** If you ask it to keep things simple and not overcomplicate stuff, it sometimes completely misses the mark and goes full steam ahead anyway.
- **Frontend is still rough.** I'm not a frontend dev, but I've heard colleagues complain about models not being good enough for frontend work. They have to do workarounds like sending screenshots or connecting Puppeteer/Playwright so the AI can "see" what it's doing.
- **Hallucinations happen.** AI is _amazing_ at writing documentation, but every once in a while it will hallucinate stuff that doesn't exist in the codebase. It's rare now, but it does happen.
- **PR review bots can be annoying.** In my experience, around 60% of AI review suggestions make sense. The AI sometimes lacks full project knowledge, or can't see that something was done a certain way on purpose. I'm looking at you, CursorBot. You're so annoying.
- **Usage limits can derail your day.** When your tool of choice runs out of budget at 10 AM and doesn't reset for another 3-4 hours, you're stuck. Having a fallback (OpenCode, in my case) is no longer optional; it's essential.
- **Your provider can change the rules on you.** I learned this the hard way when Anthropic [blocked third-party harnesses from using subscription limits](https://x.com/bcherny/status/2040206440556826908). Tools and workflows I'd built and documented became useless overnight. Always have a provider-agnostic fallback. Don't put all your eggs in one basket.

## Code review for AI-generated code

I always review AI-generated code myself while also having Claude/OpenCode review it in parallel. I try to find things on my own and see if the AI agrees with me. Then I go through the AI's suggestions and check if they make logical sense. The combination of human + AI review catches way more than either one alone.

## The culture at Lazer

We're a very AI-forward company. We have a Slack channel called `#ai-chats` where we discuss our workflows, help each other, and share new tools. It's one of the noisiest channels in our entire Slack (and I've added to that noise a lot haha), and for good reason: there's so much knowledge being shared every day that it's amazing to be a part of. I always share my setups and configs with the team, and they share theirs back. My setup gets updated at least twice a week with stuff I learn from that channel.

## My golden rule

**Never trust AI 100%.** Always verify. Always make sure that whatever it's doing makes sense. It's a tool, not a replacement for your brain.

## Advice for getting started

It's never too late to start! Here's what I'd say to anyone beginning their AI coding journey:

Design your own tools. Poke around different models. Never stop investigating. We're at a time where we have the incredible capability of designing our own toolbox, exactly the way we like it. Want to use Codex over Claude? Go for it. GSD is not for you? Maybe [Vibe Kanban](https://github.com/BloopAI/vibe-kanban) is better. Do you have a super custom flow that works perfectly for you but might not work for anyone else? Build it yourself! Create your own agents, your own commands, and go for it. The sky is the limit.

## Where this is going

This is going way up. We're just at the beginning, and I don't see it stopping anytime soon. AI is not going to replace developers. But a developer who leverages AI effectively will replace one who doesn't.

We all got promoted to team leads. We lead a team of agents that can handle the bulk of the implementation. Our job is to manage them, give them clear direction, and verify their work makes sense. The developers who thrive in this new world aren't the ones who type the fastest; they're the ones who think the clearest, architect the best, and review the most carefully.

## Show me the dotfiles

All my configs are public. If you want to see the exact files behind everything described on this page, check out my dotfiles: [git.rogs.me/rogs/dotfiles](https://git.rogs.me/rogs/dotfiles)

You'll find my OpenCode config (providers, models, agents, plugins), Claude Code config (skills, hooks, settings), GSD patches (workflows, commands, sync scripts), and Aider config (model aliases, settings). Feel free to steal whatever is useful to you.

## What I'm watching

Tools and projects I'm currently experimenting with or keeping an eye on:

- **[GSD 2](https://github.com/gsd-build/gsd-2)**: The next generation of GSD, rebuilt as a standalone CLI on the Pi SDK instead of injected prompts. I've been using it for personal projects on weekends, and the potential is huge: direct control over context windows, sessions, crash recovery, auto-advance through milestones. But the development has been rough. The main developer releases things fast and breaks things frequently. GSD 1 is still way more reliable for client work. I'm watching GSD 2 closely and I've had good conversations with the developer through GitHub issues. He seems responsive and passionate. But it needs to reach a stable version before I'd trust it for production work.
- **Improving my mobile setup**: My [OpenCode server](/2026/04/opencode-as-a-server-ai-agents-that-work-while-i-sleep/) setup works great, but I want to make the notification flow smarter and add better tmux window management for Claude Code.
- **[NullClaw](https://github.com/nullclaw/nullclaw)**: A blazing fast alternative to OpenClaw written in Zig. 678 KB binary, ~1 MB RAM. I'm considering migrating my personal assistant setup to it.
- **MiniMax M2.7**: Waiting for DeepInfra to add it. MiniMax M2.5 has been great in my review panel, and 2.7 is supposed to be a significant upgrade.
- **Whatever shows up in `#ai-chats` next week**: Honestly, half my discoveries come from that channel. The pace of innovation right now is insane.

---

## Changelog

| Date | Summary |
|------|---------|
| April 4, 2026 | Anthropic third-party ban: OpenClaw moved from Opus 4.6 to GLM-5, CLIProxyAPI deprecated, Emacs tools (forge-llm, magit-gptcommit) migrated to Lazer proxy, added provider diversification warnings. |
| April 2026 | Major update: 50/50 Claude/OpenCode split, GSD patches (adversarial review, auto-verify, UI review), usage limits reality check, OpenCode server setup, model landscape overhaul, voice AI with Handy. [Archive.org capture](https://web.archive.org/web/20260404172912/https://rogs.me/ai/) |
| February 2026 | Initial version of this page - [Archive.org capture](https://web.archive.org/web/20260311131024/https://rogs.me/ai/) |

---

_Last updated: April 4, 2026. This page is a living document. I'll keep adding to it as my workflow evolves. If you have questions or want to chat about AI workflows, [hit me up](/contact)!_
