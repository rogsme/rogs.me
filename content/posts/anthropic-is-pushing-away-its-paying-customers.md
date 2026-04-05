+++
title = "Anthropic is pushing away its paying customers"
author = ["Roger Gonzalez"]
date = 2026-04-04
lastmod = 2026-04-04T21:43:35-03:00
tags = ["programming", "claude", "llm", "anthropic", "rant"]
draft = false
+++

I need to vent.

I want to start by saying this is my opinion and doesn't reflect the views of my employers or anyone else.

I've been paying $100/month for [Claude Max](https://claude.ai/) because Claude is, without question, the best model for programming. I've built my entire [AI workflow](/ai) around it. I've written blog posts about it. I've recommended it to colleagues, friends, and strangers on the internet. I've been a loyal, paying customer.

And Anthropic keeps making it harder to stay.


## The third-party ban {#the-third-party-ban}

On the night of April 3, 2026, Anthropic sent an email to subscribers announcing that third-party harnesses like [OpenClaw](https://openclaw.ai/) can no longer use Claude Max subscription limits. Starting April 4 at 12pm PT. That's less than 24 hours of notice.

{{< img class="beach" src="/anthropic-email.png" caption="Ouch." >}}

Let that sink in. Less than 24 hours to rip out and replace the model powering my personal AI assistant, my Emacs tooling, and potentially other parts of my workflow.

My OpenClaw setup was running Opus 4.6 for personal tasks: managing my calendar, maintaining my open source projects, doing research, all through Telegram. It was perfect. Now if I want to keep using Claude with OpenClaw, I need to pay _extra_ on top of my $100/month subscription through their new "extra usage" pay-as-you-go option.

This also killed [CLIProxyAPI](/2026/02/use-your-claude-max-subscription-as-an-api-with-cliproxyapi/), which I wrote about _two months ago_. That tool let me use my Max subscription with Emacs packages like [forge-llm](https://gitlab.com/rogs/forge-llm) and [magit-gptcommit](https://github.com/douo/magit-gptcommit). I wrote an entire blog post about it, shared my config, helped people set it up. Dead now. Two months.

And it's not just OpenClaw and CLIProxyAPI. [GSD 2](https://github.com/gsd-build/gsd-2), the next generation of the tool I use for all my heavy development work, is built on the Pi SDK, the same foundation OpenClaw uses. I'm over 90% sure it's also affected. That's the tool I've been watching closely and testing on weekends for my personal projects. If GSD 2 can't use my subscription, that's yet another thing Anthropic broke.

Their email said these tools "put an outsized strain on our systems" and that they need to "prioritize customers using core products". I'm paying $100/month. I _am_ a customer. But apparently I'm not using the product the "right way."


## The notice was insulting {#the-notice-was-insulting}

We'd been hearing rumblings for a while. Rumors that Anthropic didn't like users accessing Claude through third-party tools. Reports on Reddit of people getting banned for using OpenClaw too aggressively. But nothing official.

Then, with less than 24 hours of notice, they made it policy.

Yes, they offered a one-time credit equal to your monthly subscription price. Yes, they're offering discounts on pre-purchased usage bundles. Yes, they're offering refunds. But none of that changes the fact that they gave paying customers less than a day to restructure their workflows.

A consumer-forward company would have given weeks of notice, not hours. A consumer-forward company would have opened a dialogue with the community before dropping the hammer. Instead, we got an email at night and a deadline the next morning.


## The usage limits are a mess {#the-usage-limits-are-a-mess}

This isn't even the first time Anthropic has frustrated me recently. The usage limits on Claude Code have been a disaster since late March.

Sessions that used to last hours started burning through in under 90 minutes. I'd start in the morning and hit the limit in about 45 minutes doing the same kind of work that used to last all morning. This week, I hit 50% of my weekly usage by Tuesday. My usage resets on Friday. That's terrifying when you depend on the tool for your daily work.

Anthropic acknowledged the issue. An engineer [confirmed on X](https://x.com/trq212/status/2037254607001559305) that limits drain faster during peak hours to "manage growing demand." A [GitHub issue](https://github.com/anthropics/claude-code/issues/38335) has been accumulating reports. Reddit threads are flooded with complaints. Someone reverse-engineered the Claude Code binary and found bugs that break prompt caching, silently inflating costs by 10-20x.

And through all of this, Anthropic has been mostly silent. [I see tweets from employees saying they're working on it](<https://x.com/lydiahallie/status/2038686571676008625>), but I don't see results. Meanwhile, their leadership seems more focused on shipping new features than making sure what they already have actually works. They keep shipping and shipping and not fixing what's broken.

For comparison, I've been using OpenAI's models through OpenCode as my fallback, and I have yet to hit a 5-hour usage limit. Not once. The experience is night and day.


## What I did about it {#what-i-did-about-it}

I moved everything to [Lazer's LiteLLM proxy](https://lazertechnologies.com/) (a perk we have as employees at Lazer Technologies). OpenClaw now runs [GLM-5](https://huggingface.co/zai-org/GLM-5), which is a legitimately great model: open source, MIT licensed, and competitive with frontier models on agentic tasks. My Emacs tools (forge-llm, magit-gptcommit) also moved to the Lazer proxy with GLM-5 and Qwen3 Coder 480B Turbo respectively. If you don't have access to a company proxy, [OpenRouter](https://openrouter.ai/) is a solid alternative, or you can use your own API keys directly.

The migration wasn't hard. It took a couple of hours. But that's not the point. The point is that I shouldn't have had to do it. I was paying for a service and they changed what I was paying for.


## Where I stand {#where-i-stand}

I'm very close to canceling my subscription and moving back to ChatGPT. I've been using OpenAI's models for programming through OpenCode, and they're getting really good. A little too verbose, and not quite at Opus level, but more than good enough for my workflow. And crucially, OpenAI isn't pulling the rug out from under me every other week.

Claude is still the best model for coding. I'm not going to pretend otherwise. But the best model doesn't matter if you can't use it reliably, if the limits drain in 45 minutes, and if the company keeps changing the terms on paying customers without adequate notice.

Here's where I am right now:

-   If Anthropic fixes the usage limits and stops making hostile changes, I'll stay. The model quality is worth it.
-   If they don't improve and someone else comes in with a competitive model and a better deal, I'm gone.
-   Either way, I'm never again putting all my eggs in one provider's basket. That's the lesson here.

The decisions coming out of Anthropic lately feel like corporate decisions that shaft users, not decisions made by a company that cares about its customers. And that's frustrating, because the engineering team clearly builds incredible stuff. It's the business side that's letting them down.

I updated my [AI Toolbox page](/ai) with all the changes. If you want to see my current setup (post-Anthropic-rug-pull), that's the place to look.

See you in the next one. Hopefully less angry.
