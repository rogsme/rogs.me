+++
title = "Use your Claude Max subscription as an API with CLIProxyAPI"
author = ["Roger Gonzalez"]
date = 2026-02-13
lastmod = 2026-02-13T12:12:55-03:00
tags = ["programming", "claude", "llm", "selfhosted", "emacs"]
draft = false
+++

So here's the thing: I'm paying $100/month for Claude Max. I use it a lot, it's
worth it. But then I wanted to use my subscription with my Emacs packages —
specifically [forge-llm](https://gitlab.com/rogs/forge-llm) (which I wrote!) for generating PR descriptions in Forge,
and [magit-gptcommit](https://github.com/douo/magit-gptcommit) for auto-generating commit messages in Magit. Both packages
use the [llm](https://elpa.gnu.org/packages/llm.html) package, which supports OpenAI-compatible endpoints.

The problem? Anthropic blocks OAuth tokens from being used directly with
third-party API clients. You _have_ to pay for API access separately. 🤔

That felt wrong. I'm already paying for the subscription, why can't I use it
however I want?

Turns out, there's a workaround. The Claude Code CLI _can_ use OAuth tokens.
So if you put a proxy in front of it that speaks the OpenAI API format, you can
use your Max subscription with basically anything that supports OpenAI
endpoints. And that's exactly what [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) does.

```nil
Your App (Emacs llm package, scripts, whatever)
         ↓
    HTTP Request (OpenAI format)
         ↓
    CLIProxyAPI
         ↓
    OAuth Token (from your Max subscription)
         ↓
    Anthropic API
         ↓
    Response → OpenAI format → Your App
```

No extra API costs. Just your existing subscription. Sweet!


## Why CLIProxyAPI and not something else? {#why-cliproxyapi-and-not-something-else}

I actually tried [claude-max-api-proxy](https://github.com/atalovesyou/claude-max-api-proxy) first. It worked! But the model list was
outdated (no Opus 4.5, no Sonnet 4.5), it's a Node.js project that wraps the
CLI as a subprocess, and it felt a bit... abandoned.

CLIProxyAPI is a completely different story:

-   **Single Go binary**. No Node.js, no Python, no runtime dependencies. Just
    download and run.
-   **Actively maintained**. Like, _very_ actively. Frequent releases, big
    community, ecosystem tools everywhere (desktop GUI, web dashboard, AUR
    package, Docker images, the works).
-   **Multi-provider**. Not just Claude: it also supports Gemini, OpenAI Codex,
    Qwen, and more. You can even round-robin between multiple OAuth accounts.
-   **All the latest models**. It uses the full dated model names (e.g.,
    `claude-sonnet-4-20250514`), so you're always up to date.


## What you'll need {#what-you-ll-need}

-   An active **Claude Max subscription** ($100/month). Claude Pro works too, but
    with lower rate limits.
-   A machine running **Linux** or **macOS**.
-   A web browser for the OAuth flow (or use `--no-browser` if you're on a
    headless server).


## Installation {#installation}


### Linux {#linux}

There's a community installer that does everything for you: downloads the latest
binary to `~/cliproxyapi/`, generates API keys, creates a systemd service:

```bash
curl -fsSL https://raw.githubusercontent.com/brokechubb/cliproxyapi-installer/refs/heads/master/cliproxyapi-installer | bash
```

If you're on Arch (btw):

```bash
yay -S cli-proxy-api-bin
```


### macOS {#macos}

Homebrew. Easy:

```bash
brew install cliproxyapi
```


## Authenticating with Claude {#authenticating-with-claude}

Before the proxy can use your subscription, you need to log in:

```bash
# Linux
cd ~/cliproxyapi
./cli-proxy-api --claude-login

# macOS (Homebrew)
cliproxyapi --claude-login
```

This opens your browser for the OAuth flow. Log in with your Claude account,
authorize it, done. The token gets saved to `~/.cli-proxy-api/`.

If you're on a headless machine, add `--no-browser` and it'll print the URL for
you to open elsewhere:

```bash
./cli-proxy-api --claude-login --no-browser
```


## Configuration {#configuration}

The installer generates a `config.yaml` with random API keys. These are keys
that _clients_ use to authenticate to your proxy, not Anthropic keys.

Here's what I'm running:

```yaml
# Bind to localhost only since I'm using it locally
host: "127.0.0.1"

# Server port
port: 8317

# Authentication directory
auth-dir: "~/.cli-proxy-api"

# No client auth needed for local-only use
api-keys: []

# Keep it quiet
debug: false
```

The important bit is `api-keys: []`. Setting it to an empty list disables
client authentication, which means any app on your machine can hit the proxy
without needing a key. This is fine if you're only using it locally.

If you're exposing the proxy to your network (e.g., you want to hit it from
your phone or another machine), **keep the generated API keys** and also set
`host: ""` so it binds to all interfaces. You don't want random people on your
network burning through your subscription.


## Starting the service {#starting-the-service}


### Linux (systemd) {#linux--systemd}

The installer creates a systemd user service for you:

```bash
systemctl --user enable --now cliproxyapi.service
systemctl --user status cliproxyapi.service
```

Or just run it manually to test first:

```bash
cd ~/cliproxyapi
./cli-proxy-api
```


### macOS (Homebrew) {#macos--homebrew}

```bash
brew services start cliproxyapi
```


## Testing it {#testing-it}

Let's make sure everything works:

```bash
# List available models
curl http://localhost:8317/v1/models

# Chat completion
curl -X POST http://localhost:8317/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "messages": [{"role": "user", "content": "Say hello in one sentence."}]
  }'

# Streaming (note the -N flag to disable curl buffering)
curl -N -X POST http://localhost:8317/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "messages": [{"role": "user", "content": "Say hello in one sentence."}],
    "stream": true
  }'
```

If you get a response from Claude, you're golden. 🎉


## Using it with Emacs {#using-it-with-emacs}

This is the fun part. Both forge-llm and magit-gptcommit use the [llm](https://elpa.gnu.org/packages/llm.html) package
for their LLM backend. The `llm` package has an OpenAI-compatible provider, so
we just need to point it at our proxy.


### Setting up the llm provider {#setting-up-the-llm-provider}

First, make sure you have the `llm` package installed. Then configure an OpenAI
provider that points to CLIProxyAPI:

```emacs-lisp
(require 'llm-openai)

(setq my/claude-via-proxy
      (make-llm-openai-compatible
       :key "not-needed"
       :chat-model "claude-sonnet-4-20250514"
       :url "http://localhost:8317/v1"))
```

That's it. That's the whole LLM setup. Now we can use it everywhere.


### forge-llm (PR descriptions) {#forge-llm--pr-descriptions}

I wrote [forge-llm](https://gitlab.com/rogs/forge-llm) to generate PR descriptions in Forge using LLMs. It
analyzes the git diff, picks up your repository's PR template, and generates a
structured description. To use it with CLIProxyAPI:

```emacs-lisp
(use-package forge-llm
  :after forge
  :config
  (forge-llm-setup)
  (setq forge-llm-llm-provider my/claude-via-proxy))
```

Now when you're creating a PR in Forge, you can hit `SPC m g` (Doom) or run
`forge-llm-generate-pr-description` and Claude will write the description based
on your diff. Using your subscription. No API key needed.


### magit-gptcommit (commit messages) {#magit-gptcommit--commit-messages}

[magit-gptcommit](https://github.com/douo/magit-gptcommit) does the same thing but for commit messages. It looks at your
staged changes and generates a conventional commit message. Setup:

```emacs-lisp
(use-package magit-gptcommit
  :after magit
  :config
  (setq magit-gptcommit-llm-provider my/claude-via-proxy)
  (magit-gptcommit-mode 1)
  (magit-gptcommit-status-buffer-setup))
```

Now in the Magit commit buffer, you can generate a commit message with Claude.
Again, no separate API costs.


### Any other llm-based package {#any-other-llm-based-package}

The beauty of the `llm` package is that any Emacs package that uses it can
benefit from this setup. Just pass `my/claude-via-proxy` as the provider. Some
other packages that use `llm`: [ellama](https://github.com/s-kostyaev/ellama), [ekg](https://github.com/ahyatt/ekg), [llm-refactoring](https://github.com/akirak/llm-refactoring). They'll all
work with your Max subscription through the proxy.


## Using it with other tools {#using-it-with-other-tools}

Since CLIProxyAPI speaks the OpenAI API format, it works with anything that
supports custom OpenAI endpoints. The magic three settings are always the same:

-   **Base URL**: `http://localhost:8317/v1`
-   **API key**: `not-needed` (or your proxy key if you have auth enabled)
-   **Model**: `claude-sonnet-4-20250514`, `claude-opus-4-20250514`, etc.

Here's a Python example using the OpenAI SDK:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8317/v1",
    api_key="not-needed"
)

response = client.chat.completions.create(
    model="claude-sonnet-4-20250514",
    messages=[{"role": "user", "content": "Hello!"}]
)

print(response.choices[0].message.content)
```


## Available models {#available-models}

CLIProxyAPI exposes all models available through your subscription. The names
use the full dated format. You can always check the list with:

```bash
curl -s http://localhost:8317/v1/models | jq '.data[].id'
```

At the time of writing, you'll get Claude Opus 4, Sonnet 4, Sonnet 4.5,
Haiku 4.5, and whatever else Anthropic has made available to Max subscribers.


## How much does this save? {#how-much-does-this-save}

If you're already paying for Claude Max, this is basically free API access.
For context:

| Usage                    | API Cost    | With CLIProxyAPI |
|--------------------------|-------------|------------------|
| 1M input tokens/month    | ~$15        | $0 (included)    |
| 500K output tokens/month | ~$37.50     | $0 (included)    |
| **Monthly Total**        | **~$52.50** | **$0 extra**     |

And those numbers add up quick when you're generating PR descriptions and
commit messages all day. I was getting to the point where my API costs were
approaching the subscription price, which is silly when you think about it.


## Conclusion {#conclusion}

The whole setup took me about 10 minutes. Download binary, authenticate, edit
config, start service, point my Emacs `llm` provider at it. That's it.

What I love about CLIProxyAPI is that it's exactly the kind of tool I
appreciate: a single binary, a YAML config, does one thing well, and gets out
of your way. No magic, no framework, no runtime dependencies. And since it's
OpenAI-compatible, it plays nicely with the entire `llm` package ecosystem in
Emacs.

The project is at <https://github.com/router-for-me/CLIProxyAPI> and the
community is very active. If you run into issues, their GitHub issues are
responsive.

See you in the next one!
