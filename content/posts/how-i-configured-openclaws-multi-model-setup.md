+++
title = "How I configured OpenClaw's multi-model setup (so you don't have to)"
author = ["Roger Gonzalez"]
date = 2026-04-08
lastmod = 2026-04-08T19:40:25-03:00
tags = ["programming", "openclaw", "ai", "llm", "selfhosted"]
draft = false
+++

---
**A heads up before we start:** over 95% of this blog post was written by my OpenClaw bot running GLM-5. I reviewed, edited, and approved everything, but credit where it's due: Tepui ⛰️ (yes, I named my AI) did most of the heavy lifting.

---
I need to vent, but in a good way this time.

Last week I vented about [Anthropic pushing away paying customers](/2026/04/anthropic-is-pushing-away-its-paying-customers/). After that third-party ban hit, I had to rip out Claude Opus 4.6 from my [OpenClaw](https://openclaw.ai/) setup and find alternatives. So I rebuilt the whole thing from scratch.

This time, I did it right.


## What I wanted {#what-i-wanted}

I use OpenClaw as my personal AI assistant. It connects to my Telegram, manages my calendar, runs cron jobs, helps with research, and generally makes my life easier. Before the ban, it was running Claude Opus 4.6. After the ban, I needed alternatives.

My requirements were simple:

-   Free or cheap ([Lazer's LiteLLM proxy](https://lazertechnologies.com/) gives us free access to certain models)
-   A text model for daily use (fast, capable reasoning)
-   A vision model for images and PDFs (I send screenshots, receipts, documents)
-   Image generation (sometimes I need to create images)
-   A fallback if something breaks

What I got was so much more.


## The journey {#the-journey}

The whole process took about two hours. I started with a simple question: "What's the best model to use with OpenClaw?"

First thing I did was pull the model catalog from [models.dev](https://models.dev/). If you're not familiar, it's a JSON file maintained by the OpenAI-compatible API community that lists every model from every provider with their specs: context window, token limits, pricing, capabilities, everything. I pulled it to `/tmp/models.dev.json` and started digging.

```bash
curl -s https://models.dev/api.json > /tmp/models.dev.json
```

Then I checked the Lazer proxy to see what models were actually available. Lazer Technologies (where I work) gives employees free access to a curated set of models through their LiteLLM proxy. The API is OpenAI-compatible, so you just query `/v1/models`:

```bash
curl -s https://llm.lazertechnologies.com/v1/models \
  -H "Authorization: Bearer $LAZER_API_KEY"
```

The big ones available through Lazer:

-   **[GLM-5](https://huggingface.co/zai-org/GLM-5)** : Open source, 200K context, reasoning-enabled, competitive with frontier models
-   **GLM-4.6V** : Vision model (text + images), also reasoning-enabled
-   **GPT-OSS-120b-Turbo** : Fast, cheap, reasoning model
-   **Kimi-K2.5-Turbo** : Multimodal (text + image + video)

These are all free for Lazer employees. If you don't have that luxury, the same models are available through [DeepInfra](https://deepinfra.com/) or [OpenRouter](https://openrouter.ai/) at reasonable prices.


## The problem with my existing setup {#the-problem-with-my-existing-setup}

My OpenClaw config was bare. I had:

-   A primary model: MiniMax M2.7 through OpenRouter
-   No fallback model configured
-   No image model configured
-   No image generation model
-   No PDF model

And the MiniMax model was timing out on my cron jobs. The Montevideo Events Report job was failing because MiniMax M2.7 was too slow for complex reasoning tasks. I needed something faster, and free through Lazer.


## The realization about model slots {#the-realization-about-model-slots}

This is where I learned something new. OpenClaw doesn't just have one "model" config. It has six:

1.  `agents.defaults.model` : Primary text model (plus fallbacks)
2.  `agents.defaults.imageModel` : For image input (when primary can't accept images)
3.  `agents.defaults.pdfModel` : For PDF parsing (falls back to imageModel)
4.  `agents.defaults.imageGenerationModel` : For creating images (not just viewing them)
5.  `agents.defaults.musicGenerationModel` : For music generation
6.  `agents.defaults.videoGenerationModel` : For video generation

I was only using slot #1. No wonder images weren't working right.


## What I configured {#what-i-configured}

After some back-and-forth with Tepui (yes, I named my AI), here's what we landed on:

| Role                    | Model                  | Provider   | Cost (per 1M tokens) |
|-------------------------|------------------------|------------|----------------------|
| Primary text            | GLM-5                  | Lazer      | $0.80 / $2.56        |
| Fallback                | GLM-5                  | OpenRouter | $0.80 / $2.56        |
| Image/PDF input         | GLM-4.6V               | Lazer      | $0.30 / $0.90        |
| Image generation        | Gemini 3.1 Flash Image | OpenRouter | $0.50 / $3.00        |
| Quick tasks (reserve)   | GPT-OSS-120b-Turbo     | Lazer      | $0.15 / $0.60        |
| Video-capable (reserve) | Kimi-K2.5-Turbo        | Lazer      | $0.60 / $3.00        |

I'm putting actual prices in because Lazer's proxy is free for me, but I want to track costs as if I were paying. That way I know the real value of what I'm using.


## Why these choices? {#why-these-choices}

**GLM-5 for text.** It's the best open-source reasoning model available. 200K context window, MIT licensed, competitive with GPT-4 on agentic tasks. I tested it with quick prompts and it's snappy.

**GLM-5 via OpenRouter as fallback.** Same model, different provider. If the Lazer proxy goes down, OpenClaw keeps working through OpenRouter with the exact same model. No quality drop, just a different route. I also kept MiniMax M2.7 in the allowlist so I can switch to it manually if I ever need to.

**GLM-4.6V for images and PDFs.** This was the key insight. GLM-5 is text-only. For images and PDFs, I needed a vision model. GLM-4.6V handles both, and it's on the same Lazer proxy. This means my cron jobs can parse images (like parking receipts) without hitting paid APIs.

Fun fact: I actually added the GLM-4.6V model to my config from my car while waiting for my girlfriend to finish her driving classes. I was using my [OpenCode server](/2026/04/opencode-as-a-server-ai-agents-that-work-while-i-sleep/) running at home, connected through WireGuard on my phone. Pulled the model specs from models.dev, updated the config, tested it with a screenshot. All from the car. That's the beauty of having your tools always running and always accessible.

**Gemini 3.1 Flash Image for generation.** I didn't have any image generation set up. Tepui suggested Flux.2 Pro (free on OpenRouter) but I wanted something more capable. Gemini 3.1 Flash Image generates high-quality images for about $3 per million output tokens. Worth it for occasional use.


## The config changes {#the-config-changes}

Here's what I actually changed in `~/.openclaw/openclaw.json`:

```javascript
// Primary model with fallback
agents.defaults.model: {
  primary: "lazer/deepinfra/zai-org/GLM-5",
  fallbacks: ["openrouter/zai-org/GLM-5"]
}

// Vision for images and PDFs
agents.defaults.imageModel: {
  primary: "lazer/deepinfra/zai-org/GLM-4.6V"
}
agents.defaults.pdfModel: {
  primary: "lazer/deepinfra/zai-org/GLM-4.6V"
}

// Image generation
agents.defaults.imageGenerationModel: {
  primary: "openrouter/google/gemini-3.1-flash-image-preview"
}
```

I also added all the models to the allowlist with aliases so I can switch easily:

```javascript
agents.defaults.models: {
  "openrouter/minimax/minimax-m2.7": { alias: "MiniMax" },
  "openrouter/zai-org/GLM-5": { alias: "GLM-5-OR" },
  "lazer/deepinfra/zai-org/GLM-5": { alias: "GLM-5" },
  "lazer/deepinfra/zai-org/GLM-4.6V": { alias: "GLM-4.6V" },
  "lazer/deepinfra/openai/gpt-oss-120b-Turbo": { alias: "GPT-OSS" },
  "lazer/deepinfra/moonshotai/Kimi-K2.5-Turbo": { alias: "Kimi" },
  "openrouter/google/gemini-3.1-flash-image-preview": { alias: "Gemini-Image" }
}
```

The aliases make it easy to switch with `/model` commands in chat.


## Testing it {#testing-it}

I tested everything:

-   Sent a picture of my car's steering wheel. Correctly identified the Mitsubishi logo.
-   Sent a parking receipt from the airport. Correctly parsed it (and Tepui correctly identified it was my grandma's flight, not my girlfriend's, by checking my calendar).
-   Sent a screenshot of my Spotify. Correctly identified the band (High Fade playing "Gossip").

The vision model works. The text model works. The fallback is there if something breaks.


## What I learned {#what-i-learned}

**GLM-5 doesn't support images.** The model name sounds like it should be the successor to GLM-4.6V, but it's text-only. For vision, you need GLM-4.6V specifically.

**Model config fields are strict.** OpenClaw's schema only accepts certain fields: `id`, `name`, `input`, `contextWindow`, `maxTokens`, `reasoning`, `cost`, `api`. Things like `tool_call` and `temperature` get rejected.

**models.dev is the source of truth.** Don't rely on memory or provider docs. Pull the JSON and check the specs yourself.

**OpenClaw model slots matter.** If you're only configuring one model, you're missing out on image parsing, PDF reading, and image generation. Set up all six slots.

**Pricing matters even when free.** I have free access through Lazer, but I still track prices. It helps me understand the cost of what I'm doing and compare alternatives.


## The result {#the-result}

My OpenClaw setup is now:

-   **Free** through the Lazer proxy for everyday use
-   **Fast** with GLM-5 for reasoning tasks
-   **Vision-capable** with GLM-4.6V for images and PDFs
-   **Image-generating** with Gemini for when I need to create visuals
-   **Resilient** with GLM-5 fallback through OpenRouter (same model, different provider)

And the cron jobs that were timing out? They're running fine now. The Montevideo Events Report takes 23 seconds instead of timing out at 75 seconds.

Not bad for two hours of work.


## What's next {#what-s-next}

I kept GPT-OSS-120b-Turbo and Kimi-K2.5-Turbo in reserve. GPT-OSS is cheaper than GLM-5 for quick tasks, so I might use it as a second fallback. Kimi has video support, which could be useful if I ever need to analyze video frames.

But for now, this setup covers everything I need. Text, images, PDFs, generation, fallbacks. All configured properly with the right models in the right slots.

If you're running OpenClaw (or any AI assistant), do yourself a favor: check your model config. Make sure you're using the right slots. Pull the specs from [models.dev](https://models.dev/). Track your actual costs. And test everything with real inputs.

It's worth the two hours.

See you in the next one!
