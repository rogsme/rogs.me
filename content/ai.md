---
title: "My AI Toolbox"
date: 2026-02-19T12:00:00-03:00
lastmod: 2026-09-30T12:00:00-03:00
---

I joined [Lazer Technologies](https://lazertechnologies.com/) in 2020, took a small detour in 2022 (but stayed on Slack and kept helping with things), and came back full-time in early 2024. In the last year or so, AI tools have completely changed how I work. Nobody is coming for my job; it feels more like I got promoted to team lead, and my team is a bunch of really fast, really eager AI agents.

I lead a team of agents that handle most of the heavy lifting. My job is to manage them, steer them in the right direction, and make sure their output actually makes sense. I work just as hard as before, but with an entire team behind me I get _much_ more done.

This page is a living document. I update it as my workflow evolves, and if you read the April version, almost everything changed. GSD, Aider and tmux are all gone, and the three-weapons setup I used to describe here got replaced by a set of small skills that take a ticket all the way to a reviewed PR. If you're curious about how AI-assisted development looks in practice, this is my setup, warts and all.

## The setup at a glance

| Piece | What I use |
|------|---------|
| Coding agents | [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [OpenCode](https://opencode.ai/) |
| Models | Claude Opus 5.5 (Fable now and then), GPT-6 Astra, GPT-6.1 Sol, GLM 5.3 and GLM 5.3 Flash |
| Workflow | My own skills (ticket, plan, build, address review) plus a dispatcher agent |
| Code review | A Claude reviewer in GitHub Actions, fed with ticket and PR context |
| Terminal | [herdr](https://herdr.dev/) for sessions, [worktrunk](https://worktrunk.dev/) for git worktrees |
| Mobile | [Moshi](https://getmoshi.app/) + herdr, over [Headscale](/2026/08/running-headscale-on-my-own-infra-and-finally-killing-my-wireguard-setup/) |
| Voice | [Handy](https://handy.computer/) with Parakeet V3 |
| Docs | A generated [codebase wiki](/2026/09/i-dont-write-codebase-documentation-anymore/) that updates on every push |

## A normal day: four or five agents at once

My day starts with the dispatcher (more on it below). I ask it for a frontier ticket, something big or subtle, and I hand that one to Claude Code with Opus 5.5. Then I ask for a second frontier ticket and run it on OpenCode, planning with GPT-6 Astra and executing with GPT-6.1 Sol.

Once those two are running, I ask the dispatcher for small tickets that were already marked as safe for a cheaper model, and I spin up two or three GLM sessions on them. So at any given time I have four or five agents working in parallel, each in its own git worktree and its own herdr pane.

My job at that point is mostly answering questions, approving plans, and reviewing what comes out.

## From ticket to reviewed PR

> Blog post incoming! The skills, the dispatcher agent and the CI reviewer workflow live in a client repo, so I can't link them yet. I'm writing a full post about this pipeline with cleaned-up versions you can copy into your own repo. Until then, this section explains what each piece does and why; I'll update it with the link as soon as the post is up.

This is the core of the whole setup. A ticket moves through a handful of skills and one custom agent (the dispatcher). Each skill is a markdown file that lives in the repo (in `.claude/skills/`), and both Claude Code and OpenCode load them. The steps never call each other: each one ends with a status line, and I'm the one who starts the next step.

```
linear-ticket        write the ticket (after auditing the code)
      |
dispatcher           what should I work on next?
      |
      |   I create the worktree
      v
start-ticket         read-only investigation, then a plan
      |              Status: AWAITING_APPROVAL
      |   I approve the plan
      v
work-ticket          TDD implementation, browser pass, PR, green CI
      |              Status: READY_FOR_REVIEW
      v
CI reviewer          Claude reviews every push, with ticket context
      |
      v
address-pr-review    verify each comment, fix or push back (max 2 rounds)
      |
      |   I run the human verification steps
      v
merge                I press the button
```

The skill names say "Linear" because my current project uses Linear, but the idea is tracker-agnostic. On a personal project I use [Kaneo](https://kaneo.app/) with basically the same skills and a few small changes.

A few rules hold the whole thing together:

- The agent that wrote the code never reviews it.
- The agent that fixes review comments never resolves the threads. The reviewer does.
- Every claim ("CI is green", "reviewed", "verified") is pinned to an exact commit SHA. A green check on an older commit proves nothing about the current one.
- A human (me) sits at three gates: I approve the plan, I run the verification steps, and I merge.

### Writing tickets (`linear-ticket`)

Tickets are written by an agent too, but only after it audits the code. It checks what's done, what's partial and what's missing, searches the tracker for duplicates (archived ones included), and shows me every ticket before creating anything. Each ticket has a problem statement, acceptance criteria, its dependencies, and a note that the plan is soft: whoever implements it has to look at the current code first.

Tickets that only make sense together (say, a backend endpoint and the page that renders it) can form a bundle, and one PR delivers the whole bundle. The rule is that a bundle is one piece of functionality a user can see, never a convenience grouping.

### Picking what's next (the dispatcher)

The dispatcher is a custom OpenCode agent, and it's the piece I use the most. It's read-only: it looks at the tracker, the open PRs and the code, builds a dependency graph from the tickets' blocking relations, and ranks candidates by how many other tickets each one unblocks.

It also lists my own PRs that are waiting for review or merge _before_ recommending anything new, because finishing beats starting. It can't fix anything: its shell access is a tiny allowlist (`git log`, `git status`, `gh pr view`), and it isn't allowed to spawn subagents, since a subagent wouldn't inherit those limits. When I pick a ticket, it writes the prompt I paste into the next session.

### Model routing

Not every ticket needs the most expensive model. Tickets can carry a model routing section that says which kind of model should implement them. My rule of thumb: if tests or a browser pass can prove the change is right, a cheaper model can do it. If passing tests doesn't prove correctness (answer quality, streaming failure paths, concurrency), it stays on a frontier model.

The way I fill this in is a bit of a hack. My Claude weekly limit resets on Saturday mornings, and I usually still have tokens left on Friday. So right before the reset I start one big Claude session at max effort, walk through the whole backlog, and split the tickets into "frontier" and "small model". The dispatcher then uses those labels to hand me the right ticket for each agent. Tokens that would have expired get spent on planning.

### Planning (`start-ticket`)

I create the worktree myself with worktrunk. The branch and the directory are both named after the ticket, and the skills check that before doing anything. They never create or repair a worktree.

Then `start-ticket` runs a fully read-only investigation. It loads the ticket and all its comments, checks the blockers, reads the architecture notes and decision records for the area, reads my meeting notes on the topic (client decisions often reach my notes before they reach the tracker), and traces the current implementation end to end. The output is a plan where every acceptance criterion maps to a step, plus the browser checks the implementation will run. It doesn't touch the tracker and doesn't write code.

The plan usually comes with two or three questions. I'd much rather answer them here than find the assumptions later in a diff.

### Building (`work-ticket`)

I say "go". The first thing the agent does is post the approved plan to the ticket and move it to In Progress. Then it implements, and this is the step that takes the longest (anywhere from half an hour to almost two hours).

All my agentic work is test-first, backend and frontend. It's a rule in my Claude and OpenCode configs: before an agent changes behavior, it writes a failing unit test, then makes it pass, and builds from there. Frontend changes also get end-to-end tests, but those come at the end, once the feature works. Commits are atomic, the pre-commit hook runs lint, type checks and tests for every touched area, and branches sync by merging `main`, never by rebasing or force-pushing.

Before opening the PR, the agent also has to prove the product works. For any change a user can see, it starts a signed-in instance of the real app and drives it with [Playwright CLI](https://playwright.dev/) against the real backend, walking every acceptance criterion that has a visible result. It takes a screenshot per criterion and a video per interactive flow, and uploads them to both the ticket and the PR. It also runs one negative check, like opening a page as a user who shouldn't see it.

The PR includes a "Human verification" section with exact setup commands, numbered steps at exact URLs, the expected result of each, and cleanup. "Open the app and check it works" is not accepted. Then the agent waits for CI on the exact head commit, fixes deterministic failures itself, posts a handoff comment on the ticket, and stops.

### The CI reviewer

Every push to every non-draft PR triggers a GitHub Action that runs Claude Code (Opus 5.5 right now, through [Lazer Proxy](https://lazertechnologies.com/)) as a read-only reviewer.

My biggest complaint about AI PR reviewers has always been context. They see a diff and nothing else, so they can't tell a mistake from a decision someone made on purpose. That's where the old "60% of AI suggestions make sense" number on this page came from (I'm still looking at you, CursorBot).

So before the model sees anything, the workflow builds the context itself:

1. A script collects the PR description, prior reviews, and every review thread with its resolved or open state.
2. Another script pulls every ticket the PR delivers from the tracker.
3. Both get injected into the prompt, and the reviewer uses the tickets as the specification.

The reviewer can read files, grep, run `git`, and run a focused test against the locked dependencies to reproduce a bug. It can post inline comments. It can't edit, write, browse the web, or spawn subagents. It has to try to refute each finding before posting it, say whether it reproduced it or only traced it, and classify it (blocking, bug, test gap, question, nit). A small cleanup step hides superseded summaries so the PR doesn't fill up with bot noise.

The difference is huge. Of the replies my agents have written to review comments on my current project, 231 accepted the comment, 12 partially accepted it and 4 rejected it. That's a long way from 60%, and what changed was mostly the context.

The workflow and the context script will be in the upcoming post, too.

### Answering the review (`address-pr-review`)

In a fresh session I say "address the comments on the PR". The skill's first rule is to treat review comments (human or bot) as claims to verify, not instructions to follow. Each comment gets checked; if it's real, the agent fixes the root cause with the smallest change and a regression test, commits, and when every comment is handled, pushes once. CI runs, the reviewer reviews again, and the agent replies to each thread with what it did and the commit that did it.

If a comment contradicts a recorded decision, the agent pushes back with the decision record as evidence. It never resolves threads itself; the reviewer does that when it's satisfied.

And it stops after two rounds, whatever the reviewer says next. If the PR still isn't clear, that's when I step in. That cap exists for a reason: a reviewer that reproduces its findings never runs out of edge cases, and "keep going until the reviewer says clear" once got me a PR with 38 findings across 28 reviewed commits.

### Verification and merge

When the reviewer is clear, I run the human verification steps myself. More and more, I ask an agent to run them with Playwright first, and then I run them. After that I read the code to make sure it makes sense, and I merge. There's a `finish-ticket` skill that does the whole audit trail (merge, verify parents, post-merge CI, completion comment), but honestly I'm usually the one pressing the button.

After each merge, a CI job regenerates the codebase wiki. I wrote about that in [I don't write codebase documentation anymore](/2026/09/i-dont-write-codebase-documentation-anymore/).

## Models and harnesses

### Claude Code

I'm still paying $100/month for [Claude Max](https://claude.ai/). Nine times out of ten I run Opus 5.5; I still reach for Fable now and then. I still skip permission prompts (`skipDangerousModePermissionPrompt: true`). I used to be against it, but after months of watching agents work in isolated worktrees with test-first rules and a pre-commit hook, the prompts slowed me down more than they protected me. If you're not comfortable with it, don't do it.

Good news on the usage limits: they've gotten a lot better for me. Opus 5.5 is way gentler on tokens than 4.6 or 4.8 were. It still uses plenty, but I rarely hit the limit now, and when I do it resets in an hour or two, and I can keep going on GPT in the meantime. Fable is still hungry, but it doesn't bother me like it used to.

### OpenCode

OpenCode is where everything that isn't Claude runs. On top of Claude Max, I now pay for OpenAI's [ChatGPT Pro 100](https://help.openai.com/en/articles/9793128-about-chatgpt-pro-tiers) plan ($100/month), which OpenCode connects to with OAuth. Having a second subscription is a big part of why the Claude limits stopped hurting.

- GPT-6 Astra plans and GPT-6.1 Sol executes the frontier tickets I don't give to Claude. Sol 6.1 came out yesterday, and if the benchmarks hold up I'll probably drop Astra and use Sol for both.
- GLM 5.3 and GLM 5.3 Flash handle the small tickets, and the odd part is that Flash plans while the big model executes. Everything I've read says the stronger model should plan and the lighter one should code, but with GLM I get better results the other way around, and I honestly don't know why. Flash is very fast and very good at planning; the big model is very good at programming.

So on my machine the routing is simple: Anthropic models go through my Claude subscription, OpenAI models through my ChatGPT subscription, and everything else through [Lazer Proxy](https://lazertechnologies.com/). (CI is the exception: the GitHub Actions jobs use the proxy for everything, Claude included.) The GLM models are served by Fireworks behind the proxy, so they're Chinese models running on North American infrastructure.

The full OpenCode and Claude Code configs are in my [dotfiles](https://git.rogs.me/rogs/dotfiles).

### The third-party ban still stands

In April, Anthropic [blocked third-party harnesses from using subscription limits](https://x.com/bcherny/status/2040206440556826908) with less than a day of notice. That killed [CLIProxyAPI](/2026/02/use-your-claude-max-subscription-as-an-api-with-cliproxyapi/) and forced my personal assistant off Opus. I wrote a whole angry post about it: [Anthropic is pushing away its paying customers](/2026/04/anthropic-is-pushing-away-its-paying-customers/).

It's still true, and I'm still a little mad. But time has passed, I have other options, and I'm not putting all my eggs in one basket anymore. The lesson from that post still holds: always have a provider-agnostic fallback.

## The terminal: herdr and worktrunk

I switched from tmux to [herdr](https://herdr.dev/), and I'm not going back.

My first try didn't stick. The keybindings were different, I didn't have time, and I was way too used to tmux. Then my friend Reed (who you might remember from [my certification post](/2026/07/how-i-got-claude-certified-and-how-you-can-too/)) suggested something obvious in hindsight: ask an agent to configure herdr with the same keybindings as my tmux setup. Genius tip. Five or ten minutes later, I was fully used to it.

herdr works a lot like tmux: I open sessions, attach, detach, and they keep living in the background. But it adds things I used to need plugins for, or couldn't have at all:

- Sessions survive a reboot. No resurrect plugin needed.
- A side panel shows every agent I have running, so I can see at a glance who's working and who's waiting for me.
- Multiple projects open at the same time, out of the box.
- It's a first-class citizen in Moshi (see below).

It's also a very active open source project, and it's built with AI agents in mind.

Worktrees are still managed by [worktrunk](https://worktrunk.dev/) (`wt`). Every ticket gets its own worktree under `~/code/worktrees/<repo>/<ticket>`, gitignored files like `.env` get copied in by a hook, and that's what lets four or five agents work on the same repo without stepping on each other. If it isn't broken, don't fix it.

## Coding from my phone: Moshi + herdr

My mobile setup used to be a whole chain: Termux, mosh, a jump box, tmux, ntfy for notifications, WireGuard to tie it together. I wrote [a full blog post](/2026/02/claude-code-from-the-beach-my-remote-coding-setup-with-mosh-tmux-and-ntfy/) about it, and I'm still proud of it, but it had a lot of moving parts.

Now it's just [Moshi](https://getmoshi.app/) with herdr inside it. Moshi speaks mosh, so the connection survives me pocketing the phone, and herdr is a first-class citizen in Moshi, so I land in the same sessions I have on my desk, with the same side panel showing all my agents.

It works really well on my Galaxy Fold. Opening the inner screen and having a full terminal on it is invaluable. I can check on four agents, answer a planning question, and approve a plan from the couch.

For connectivity, WireGuard is gone too. I moved to [Headscale](https://headscale.net/), the open source Tailscale control server, running on my own infra (full write-up: [Running Headscale on my own infra](/2026/08/running-headscale-on-my-own-infra-and-finally-killing-my-wireguard-setup/)). It stays on on my phone and my machines, so I can reach them from anywhere with an internet connection.

The [OpenCode server](/2026/04/opencode-as-a-server-ai-agents-that-work-while-i-sleep/) I set up in April is technically still running, but I don't use it anymore. Moshi and herdr replaced it completely. I should probably turn it off.

## Voice AI: talking to my tools

I still use [Handy](https://handy.computer/) for local, offline speech-to-text, and I'd estimate 40 to 45% of my work now happens by voice instead of the keyboard. It's not my main input yet, but it's getting close. Most of the answers that went into this page were dictated.

Handy runs NVIDIA's [Parakeet V3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3), a 600M parameter model that runs on CPU. I tried the newer models Handy offers and didn't see any improvement, only bigger and slower models. Parakeet is extremely fast and extremely accurate.

The part that matters most to me: it handles two languages properly. I'm a native Spanish speaker, and I switch between Spanish and English all day. Every other multilingual model I tried would hear me speak Spanish and transcribe it in English, or the other way around. Parakeet never does that: if I speak Spanish I get Spanish, and if I speak English I get English.

I use two modes, depending on who's going to read the text.

With post-processing, for anything a human reads (Slack messages, docs, emails), Handy runs the raw transcription through a model that cleans up filler words, fixes grammar, and turns spoken rambling into proper written sentences. On my MacBook Air that's GPT OSS 120B through Lazer Proxy. On my main Linux machine it's Gemma 3, running locally in [Ollama](https://ollama.com/), so nothing leaves the machine.

Without post-processing, for talking to agents, I use the raw transcription and just tell the agent "this is spoken, not written". Agents handle messy spoken input just fine, and I give way more context when I talk than when I type.

## Beyond coding

- Commits and PRs: my agents create them with skills that follow each repo's commit conventions and PR templates. I still have [forge-llm](https://gitlab.com/rogs/forge-llm) and [magit-gptcommit](https://github.com/douo/magit-gptcommit) in Emacs, pointed at the latest models on Lazer Proxy, but I rarely use them now that agents do almost all the work.
- Documentation: a [generated wiki](/2026/09/i-dont-write-codebase-documentation-anymore/) that rewrites itself from the code on every push to `main`. It replaced the overnight documentation job.
- Personal assistant: my [OpenClaw](https://github.com/openclaw/openclaw) agent on Telegram runs GLM 5.3, with GLM 5.3 Flash for images (5.3 isn't multimodal). I'm thinking about moving to Hermes, but OpenClaw works perfectly and I don't want to be the guy who breaks a working setup for fun (yet).
- Proofreading: English is not my first language (hola! 🇻🇪), so I use Claude a lot for emails, Slack messages and docs.
- Research: Claude is still my faster, friendlier Google.

## The graveyard

RIP 🪦 to the tools that got me here.

- [GSD](https://github.com/gsd-build/get-shit-done): for months this was the core of my workflow, and my [GSD patches](/2026/04/i-patched-gsd-and-why-you-should-patch-it-too/) were the part of this page I was proudest of. Then development went sideways: the project kept adding things that didn't make sense to me, and the founder [allegedly rug-pulled a crypto token tied to the project](https://intellectia.ai/news/crypto/gsd-token-allegedly-rugpulled-after-founder-exit). I tried forking it and tuning it my way, then realized Claude Code and OpenCode were good enough on their own and I didn't need a framework. I rebuilt what I actually used as a handful of skills. The patches are still in my dotfiles; I just don't use them.
- The multi-model adversarial review: six models reviewing every plan in parallel. It caught things, but it made more noise than it was worth. One reviewer with the right context beats six reviewers without it. I might revisit the idea someday.
- [Aider](https://aider.chat/): the sniper. Once every agent works in its own worktree with its own tests, I stopped needing a separate tool for single-file fixes, so it's completely out of my pipeline.
- tmux, Termux, WireGuard and ntfy: replaced by herdr, Moshi and Headscale.
- The overnight crew: my scheduled test, docs and convention jobs are paused, not deleted. They're very useful; my current project just doesn't need them, since everything is test-first and the wiki handles docs. The test gap job was the best one, and I might bring it back.
- The herdr orchestrator: I tried building an agent whose only job was driving herdr panes and taking tickets to PR on its own. It was slow, sluggish, and made a lot of mistakes, so it didn't pan out.
- Devin: we used it at the company for a while, and I ran some tests with it. It's not part of my setup today.

## The before and after

Before AI tools, my workflow was: grab a task, study the code, read tons of documentation, ask teammates for help, confirm my thought process, then code little by little.

On my current project, I'm the only developer on a web front end, an API and a data pipeline. Six weeks in:

- 128 pull requests, 124 of them merged, about 1,300 commits on `main`.
- Planning a ticket takes about 12 minutes. Building it, from plan approval to green CI, takes 27 minutes to a bit under two hours.
- The CI reviewer has reviewed 91 PRs and posted 581 findings (447 of them bugs).
- The median time from PR open to merge is about 18 hours. The slowest step is me running the verification steps, not the agents.

Some of the older numbers from this page still hold too:

- Tickets that used to take a week take a couple of days.
- Tickets that used to take three days can be done in half a day.
- A spike that would have taken me three to five days took one, with way more detail than I could have produced.
- On a past project, three months of work squeezed into one month got done in three weeks.

Speed is only part of it. The kind of work I do changed too: I take on more ambitious tasks, and I spend way more time on architecture than on implementation. A well-architected system can endure messy code much better than a poorly-architected one can endure clean code, and now I have the time to care about the first part.

## The honest stuff

AI is not perfect. Here's what I've learned the hard way:

- AI can't be simple. Ask it to keep things simple and it sometimes goes full steam ahead anyway.
- Frontend got a lot better. This used to say frontend was rough, but now every frontend change gets verified with Playwright CLI and screenshots, so the agent can see what it built, fix itself when something looks wrong, and I can point at a screenshot and say "that". It's in a much better place.
- A reviewer that reproduces its findings never runs out of findings. On one PR, round after round of new edge cases led an agent to add a heuristic for each one, and one of those heuristics caused a real data-loss bug. That's why address rounds are capped at two and why decision records matter: they're what lets an agent say no with evidence.
- Bots can bury humans. At one point the reviewer had written about six times more text on our PRs than the humans had. Hiding superseded summaries and teaching it to review like my teammates and I actually review fixed it.
- A green run can lie. My wiki job reported success eleven times in a row while committing almost nothing. Check that the work actually happened, even when the job exits 0.
- Parallel agents create parallel problems. At one point I had 22 PRs open at once, and three of them claimed the same database migration number. Git didn't flag it; an agent checking every pair did.
- Hallucinations still happen, rarely.
- Your provider can change the rules on you, so always have a fallback.

## Code review for AI-generated code

The CI reviewer doesn't replace me reading the code. When a PR is clear, I still read it and check that the logic makes sense. The reviewer catches bugs; I catch "this works, but it's the wrong idea". The combination catches way more than either one alone.

## The culture at Lazer

We're a very AI-forward company. We have a Slack channel called `#ai-chats` where we discuss workflows, help each other, and share new tools. It's one of the noisiest channels in our Slack (and I've added to that noise a lot haha). Half of what's on this page came from there, including the herdr tip that finally made me switch.

## My golden rule

**Never trust AI 100%.** Verify everything, and make sure whatever it's doing makes sense. It's a tool, and your brain is still the one in charge.

## Advice for getting started

Design your own tools, poke around different models, and keep investigating. I went from a big framework to a handful of markdown files, and my workflow got better, because the files do exactly what I need and nothing else.

If you want something like my setup but my terminal-heavy approach looks like too much, try [Orca](https://www.onorca.dev/). When people ask me what they should use, nine times out of ten that's my answer. It's much friendlier for beginners, and it does most of what I do with herdr through a much nicer interface. My fiancée is a UX/UI designer, not a programmer, and she uses it every day and loves it. I've tried it too, and it works really well; it's just not my jam, because I prefer the terminal and my Moshi + herdr setup is too powerful to give up.

## Where this is going

This is going way up. AI is not going to replace developers, but a developer who uses AI well will replace one who doesn't.

We all got promoted to team leads. We lead a team of agents that handles the bulk of the implementation, and our job is to give them clear direction and verify their work. The developers who thrive here think clearly, architect well, and review carefully. Typing speed stopped mattering a while ago.

## Show me the dotfiles

My general configs are public: [git.rogs.me/rogs/dotfiles](https://git.rogs.me/rogs/dotfiles). You'll find my OpenCode and Claude Code configs, rules, hooks, and the old GSD patches for historical purposes. The ticket skills and the review workflow live inside my client's repo, so they're not in there yet; cleaned-up versions are coming in the pipeline post (see the note in [From ticket to reviewed PR](#from-ticket-to-reviewed-pr)).

## What I'm watching

- GPT-6.1 Sol for everything. If it holds up, it replaces Astra for planning too.
- A test gap reviewer, either as a dedicated reviewer in CI or as the old overnight test job coming back.
- Multi-model review again. It's shelved for now, but I haven't ruled it out.
- Hermes, as a possible replacement for OpenClaw, once I'm brave enough.
- Whatever shows up in `#ai-chats` next week.

---

## Changelog

| Date | Summary |
|------|---------|
| September 30, 2026 | Full rewrite. GSD, Aider, tmux, Termux, WireGuard and ntfy retired. New ticket-to-PR skills pipeline with a dispatcher agent, context-fed CI reviewer, model routing, herdr + worktrunk, Moshi + Headscale for mobile, Opus 5.5 / GPT-6 / GLM 5.3 lineup, new numbers, and a graveyard section. |
| April 4, 2026 | Anthropic third-party ban: OpenClaw moved from Opus 4.6 to GLM-5, CLIProxyAPI deprecated, Emacs tools (forge-llm, magit-gptcommit) migrated to Lazer proxy, added provider diversification warnings. [Archive.org capture](https://web.archive.org/web/20260930133823/https://rogs.me/ai/) |
| April 2026 | Major update: 50/50 Claude/OpenCode split, GSD patches (adversarial review, auto-verify, UI review), usage limits reality check, OpenCode server setup, model landscape overhaul, voice AI with Handy. [Archive.org capture](https://web.archive.org/web/20260404172912/https://rogs.me/ai/) |
| February 2026 | Initial version of this page - [Archive.org capture](https://web.archive.org/web/20260311131024/https://rogs.me/ai/) |

---

_Last updated: September 30, 2026. This page is a living document. I'll keep adding to it as my workflow evolves. If you have questions or want to chat about AI workflows, [hit me up](/contact)!_
