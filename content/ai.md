---
title: "My AI Toolbox"
date: 2026-02-19T12:00:00-03:00
lastmod: 2026-02-19T12:00:00-03:00
---

I've been a senior backend developer at [Lazer Technologies](https://lazertechnologies.com/) for 5 years now. In the last year or so, AI tools have completely changed how I work. Not in a "robots are coming for your job" way, but in a "I got promoted to team lead and my team is a bunch of really fast, really eager AI agents" way.

I lead a team of agents that handle most of the heavy lifting. My job is to manage them, steer them in the right direction, and make sure their output actually makes sense. It's not that I'm doing less work, it's that I can do _much_ more with an entire team behind me.

This page is a living document. I update it regularly as my workflow evolves (which happens at least twice a week, honestly). If you're curious about how AI-assisted development looks in practice, this is my setup, warts and all.

## The arsenal

I use three main tools for coding, and I like to think of them as weapons:

| Tool | Analogy | Use case |
|------|---------|----------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) + [GSD](https://github.com/gsd-build/get-shit-done) | The cannon | Big end-to-end epics, multi-file features, full milestones |
| [OpenCode](https://opencode.ai/) + custom agents | The shotgun | Medium tasks, multi-model workflows, tasks that benefit from specific models |
| [Aider](https://aider.chat/) | The sniper | Precise single-file fixes, docstrings, targeted edits |

I used to use Aider for almost everything. Then I built my own agents for OpenCode with a planning → execution → review flow. Then [GSD](https://github.com/gsd-build/get-shit-done) came along and absolutely floored my custom flow. Now I default to Claude Code + GSD for most things, drop to OpenCode for medium tasks where specific models shine, and use Aider only when firing up Claude Code or OpenCode would be overkill for a single file change.

## Claude Code + GSD: The cannon

[GSD (Get Shit Done)](https://github.com/gsd-build/get-shit-done) is a meta-prompting and context engineering system for Claude Code. The way it uses multiple subagents to explore the codebase, investigate, execute and self-review is plain magic. It solves context rot (the quality degradation that happens as Claude fills its context window) by spawning fresh agents with clean 200k token contexts for each task.

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
/gsd:verify-work N      ← manual acceptance testing
          ↓
        repeat
```

I thought I was super smart because I had come up with my own planning → execution → review flow. Turns out GSD is basically the same concept on crack. It's open source, maintained by a big community, and advances way faster than anything I could build alone.

### My Claude Code config

I do **not** use `claude --dangerously-skip-permissions`. That sounds like a bad idea. Instead, I set granular permissions in `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(./scripts/*)",
      "Read",
      "Grep",
      "Glob"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Edit(.env*)",
      "Write(.env*)"
    ]
  }
}
```

I also have a `PostToolUse` hook that auto-formats Python files whenever Claude edits them. One less thing to worry about.

For `CLAUDE.md`, I typically let Claude set it up with the `/init` command. It gets it ~80% right, and I just tweak the remaining 20%.

I do **not** use MCP servers with Claude Code. GSD already uses a lot of tokens, so I want to keep it lean. All my MCP servers go to OpenCode instead.

### When it goes off the rails

Rarely happens. I've seen it go off the rails maybe twice. When it does, I use GSD's built-in commands to steer it back on track. If it's _really_ far gone, I stop, `git revert`, and restart the GSD process from the top. But honestly, I've always been able to course-correct without a full reset.

## OpenCode + custom agents: The shotgun

[OpenCode](https://opencode.ai/) is my multi-model workhorse. I built a 3-phase agent system that I use for medium-sized tasks:

### Planning agent
Uses **Gemini 2.5 Pro** or **Gemini 3.0 Pro** (huge 1M token context). It fetches the ticket from Jira or Linear, reads the requirements, and creates a detailed step-by-step implementation plan. No code, just planning. Once approved, the plan gets saved to `docs/plans/TICKET_NUMBER.md`, which is how the execution and review agents know what to do.

Here's a generalized version of what my planning agent looks like:

```markdown
---
description: Understands requirements and creates detailed implementation plans.
model: gemini/gemini-3-pro-preview  # 1M token context for huge codebases
temperature: 0.1
tools:
  write: true
  edit: false   # No editing - planning only
  bash: false   # No code execution
permission:
  edit: ask
  bash: ask
  webfetch: ask
---
You are in the **Planning** phase. Your primary goal is to fully understand
the ticket's requirements. When the user provides a ticket ID (e.g., `ENG-123`):

1. **First**, check whether a plan for this ticket already exists in `docs/plans/`.
   - If it exists, notify the user and ask whether they want to edit or replace it.
   - If it does not exist, proceed.

2. **Retrieve the ticket details** from your project management tool (Jira, Linear,
   GitHub Issues, etc.). Fetch the full ticket information: description, acceptance
   criteria, attachments, subtasks, comments.

3. **Create a detailed, step-by-step implementation plan** using your plan template.
   - The plan must be broken into phases and steps.
   - Every step must include a clear rationale explaining *why* the action is needed.
   - Cross-check the plan against *all* requirements and acceptance criteria.
   - **Do not write any code.** This phase is *only* for planning.

4. **Verify the plan**: Confirm that every requirement in the ticket is addressed.
   Use the acceptance criteria as a checklist.

5. **Present the plan** to the user and wait for approval. Once approved, save it
   to `docs/plans/TICKET_NUMBER.md`.

The Planning phase is the most important part of the workflow. A thorough plan
ensures the agent fully understands the requirements and defines a clear path
to implementation. This phase should **always** plan and **never** execute.
```

The plan template I use follows a simple structure: Phases with steps, each step with an action and a rationale:

```markdown
### Phase 1: [Phase Title]
**Goal:** [What this phase achieves]

- **Step 1.1: [Step Title]**
  - **Action:** [What to do]
  - **Rationale:** [Why we're doing it this way]

- **Step 1.2: [Step Title]**
  - **Action:** [What to do]
  - **Rationale:** [Why we're doing it this way]

### Phase 2: [Phase Title]
**Goal:** [What this phase achieves]
...

### Phase N: Integration and Verification
**Goal:** [Final quality checks]

- **Step N.1: Final Quality Checks**
  - **Action:** Run the full suite of project quality tools (linting, type
    checking, tests).
  - **Rationale:** Ensures no regressions were introduced.
```

The number of phases and steps depends on the ticket complexity. Simple tickets might be 2 phases with 3-4 steps each. Complex ones can be 5+ phases.

### Execution agent
Uses **Grok Code Fast** (tiny, super cheap, and really good at coding). It reads the saved plan from `docs/plans/` and implements it step by step. If it doesn't find a plan, it refuses to do anything, no cowboy coding allowed. It pauses at natural breakpoints and waits for my input before continuing.

```markdown
---
description: Implements an approved plan, executing steps and running tests.
model: xai/grok-code-fast  # Cheap, fast, good enough at coding
temperature: 0.1
tools:
  write: true
  edit: true
  bash: true
permission:
  edit: allow
  bash:
    "*": ask
  webfetch: ask
---
You are in the **Execution** phase. Your goal is to implement an approved plan
incrementally. Upon receiving a ticket ID (e.g., `ENG-123`), read the relevant
plan file from `docs/plans/TICKET_NUMBER.md` and execute each phase and step.

**If you don't find a plan, let the user know and don't do anything else.**

1. **Load the plan:** Read the approved implementation plan to understand the
   detailed steps and phases.
2. **Execute step by step:** Implement each phase and step of the plan, running
   tests and quality checks as needed.
3. **Wait for instructions:** Pause at natural breakpoints or when encountering
   decisions, and wait for user guidance before proceeding.
4. **Iterate as needed:** Adjust the implementation based on user feedback or
   new requirements that emerge during development.
5. **Complete implementation:** Ensure all plan requirements are met before
   moving to the Review phase.
```

The key insight here is that if the plan is detailed enough (and it should be, thanks to Gemini's massive context), the execution agent doesn't need to be expensive. A cheap, fast model that's good at coding is more than enough when it has clear instructions to follow.

### Review agent
Uses **Claude Sonnet 4.5** (the reviewer needs to be smart). It loads the original ticket requirements _and_ the saved plan, then verifies the implementation against both. It runs quality checks, flags issues by severity, and collaborates with you on fixes.

```markdown
---
description: Ensures code quality, correctness, and best practices compliance.
model: anthropic/claude-sonnet-4-5  # The reviewer must be smart
temperature: 0.1
tools:
  write: true
  edit: true
  bash: true
permission:
  edit: ask
  bash: ask
  webfetch: ask
---
You are in the **Review** phase. Your goal is to ensure the code is robust,
maintainable, and adheres to best practices.

1. **Load context:**
   - Retrieve the original ticket details from your project management tool.
   - Read the implementation plan from `docs/plans/`.
   - Review the actual implementation code.
   - Run quality checks (tests, lint) to establish a baseline.

2. **Verify implementation:** Create a checklist mapping ticket requirements to
   the implementation. Confirm acceptance criteria are met.

3. **Identify improvements:** Systematically analyze security, correctness,
   robustness, error handling, testing, documentation, and maintainability.

4. **Prioritize issues:** Categorize by severity:
   - Critical (must fix), High (should fix), Medium (nice to fix), Low (optional)
   - For each issue: document location, problem, impact, proposed fix, severity.

5. **Collaborate with the user:**
   - Present findings before making changes.
   - Accept user input on what constitutes a "non-issue".
   - Wait for approval before proceeding with fixes.

6. **Fix and validate:** Fix issues in priority order, run quality checks after
   each batch, add tests for edge cases discovered during review.

7. **Final verification:** Ensure all tests pass, no linting issues, no type
   errors. Generate a summary report with metrics.
```

This was my original flow before GSD came along. I still use it for lighter tasks where GSD feels like too much.

### Why those specific models?

I've tested _multiple_ models for each agent, and I mean **MULTIPLE**. These are the ones that give the best results for the smallest price. I'll admit it: I'm cheap. I want to squeeze every dollar from the tokens I'm getting. All three agents would work amazingly with Sonnet + Opus, but that would be way more expensive. With the right planning, a cheap execution model is more than enough.

### My MCP servers

I use three MCP servers, all in OpenCode:

- **[PAL MCP](https://github.com/BeehiveInnovations/pal-mcp-server)** (always on): A Provider Abstraction Layer that connects OpenCode to multiple AI models within a single session. Think of it as multi-model orchestration. I can get second opinions, run code reviews with different models, and do consensus building without leaving my current context.
- **[Jira MCP](https://mcp.atlassian.com/)** (toggled): For fetching ticket details directly from Jira during the planning phase.
- **[Context7](https://github.com/upstash/context7)** (toggled): For documentation lookups.

### All models through Lazer's LiteLLM

We run our own LLM provider at Lazer using [LiteLLM](https://github.com/BerriAI/litellm) (which I help manage!). It exposes models from Gemini, OpenAI, Anthropic, xAI, Perplexity, Qwen, GLM, Llama, and many more. All models in my OpenCode config are prefixed by `lazer/` and go through our LiteLLM server. Same for Aider.

Here's a snippet of my OpenCode providers config:

```json
{
  "provider": {
    "lazer": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Lazer",
      "options": {
        "baseURL": "https://llm.lazertechnologies.com/v1"
      },
      "models": {
        "gemini/gemini-2.5-pro": { "name": "Gemini 2.5 Pro" },
        "gemini/gemini-3-pro-preview": { "name": "Gemini 3 Pro Preview" },
        "xai/grok-code-fast-1-0825": { "name": "Grok Code Fast" },
        "anthropic/claude-sonnet-4-5": { "name": "Claude Sonnet 4.5" },
        "anthropic/claude-opus-4-5-20251101": { "name": "Claude 4.5 Opus" }
      }
    }
  }
}
```

## Aider: The sniper

[Aider](https://aider.chat/) is for precision. Let's say Claude Code or OpenCode did a great job on a feature, but missed docstrings in one file. Or left a TODO that needs resolving. Or the formatting is off in a single module. I don't need to fire up an entire agent orchestration system for that, I just point Aider at the file and fix it.

My Aider config is mostly about registering custom models through Lazer's LiteLLM. I have aliases set up for quick switching:

```yaml
alias:
  - "lazer-sonnet:openai/anthropic/claude-sonnet-4-5"
  - "lazer-haiku:openai/anthropic/claude-3-5-haiku-20241022"
  - "lazer-gemini-flash:openai/gemini/gemini-3-flash-preview"
  - "lazer-grok:openai/xai/grok-code-fast-1"
```

So I can just do `aider --model lazer-sonnet` or `aider --model lazer-grok` and be off to the races.

## Beyond coding

AI isn't just for writing code. Here's where else I use it (and yes, most of this happens from Emacs, because of course it does):

- **PR descriptions**: I wrote [forge-llm](https://gitlab.com/rogs/forge-llm), an Emacs package that generates PR descriptions in [Forge](https://magit.vc/manual/forge/) using LLMs. It analyzes the git diff and writes a structured description. I use it with my Claude Max subscription through [CLIProxyAPI](/2026/02/use-your-claude-max-subscription-as-an-api-with-cliproxyapi/).
- **Git commits**: [magit-gptcommit](https://github.com/douo/magit-gptcommit) auto-generates conventional commit messages from staged changes, also through CLIProxyAPI.
- **Proofreading**: English is not my first language (hola! 🇻🇪), so I use the Claude website a lot for proofreading emails, Slack messages, documentation, you name it.
- **Research and "searches"**: I use Claude as a faster, friendlier Google. Investigations, quick questions, exploring ideas.
- **Personal assistant**: I have an [OpenClaw](https://github.com/openclaw/openclaw) agent on my Telegram chats that manages my calendar, contacts, helps me maintain my open source projects, does research, and is just an all-around good guy.
- **Coding from my phone**: I have a full [mobile coding setup](/2026/02/claude-code-from-the-beach-my-remote-coding-setup-with-mosh-tmux-and-ntfy//) using mosh, tmux, and ntfy. The idea is simple: I connect to my work PC from my phone through a WireGuard VPN, give Claude Code a task, pocket the phone, and get a push notification when Claude needs my help or finishes. Async development from the beach, the couch, wherever. It's genuinely a game changer.

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

You'll find my OpenCode config (providers, MCP servers, agents), Aider config (model aliases, metadata, settings), and pretty much everything else. Feel free to steal whatever is useful to you.

## What I'm watching

Tools and projects I'm currently experimenting with or keeping an eye on:

- **[Vibe Kanban](https://github.com/BloopAI/vibe-kanban)**: A kanban-style approach to AI-assisted development. Interesting alternative to GSD's milestone flow.
- **Improving my mobile setup**: My [Claude Code from the beach](/2026/02/claude-code-from-the-beach-my-remote-coding-setup-with-mosh-tmux-and-ntfy//) setup works great, but I want to make the notification flow smarter and add better tmux window management.
- **[NullClaw](https://github.com/nullclaw/nullclaw)**: A blazing fast alternative to OpenClaw written in Zig. 678 KB binary, ~1 MB RAM. I'm considering migrating my personal assistant setup to it.
- **[OpenAI Codex](https://github.com/openai/codex)**: OpenAI's agentic coding tool. Another cannon-class option worth evaluating as competition between Claude Code, Codex, and Gemini CLI heats up.
- **[Gemini CLI](https://github.com/google-gemini/gemini-cli)**: Google's CLI for Gemini models. GSD already supports it, so it might be worth integrating into my workflow for tasks where Gemini's massive context window shines.
- **Whatever shows up in `#ai-chats` next week**: Honestly, half my discoveries come from that channel. The pace of innovation right now is insane.

---

_Last updated: February 2026. This page is a living document. I'll keep adding to it as my workflow evolves. If you have questions or want to chat about AI workflows, [hit me up](/contact)!_


