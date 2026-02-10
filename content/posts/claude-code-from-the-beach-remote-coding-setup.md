+++
title = "Claude Code from the beach: My remote coding setup with mosh, tmux and ntfy"
author = ["Roger Gonzalez"]
date = 2026-02-10
lastmod = 2026-02-10T11:42:22-03:00
tags = ["programming", "claude", "remotedev", "tmux", "mosh", "ntfy"]
draft = false
+++

{{< img class="beach" src="/1000121647.jpg" caption="The view two blocks from my apartment" >}}

I recently read [this awesome post](https://granda.org/en/2026/01/02/claude-code-on-the-go/) by Granda about running Claude Code from a
phone, and I thought: _I need this in my life_. The idea is simple: kick off a
Claude Code task, pocket the phone, go do something fun, and get a notification
when Claude needs your help or finishes working. Async development from anywhere.

But my setup is a bit different from his. I'm not using Tailscale or a cloud VM.
I already have a WireGuard VPN connecting my devices, a home server, and a
self-hosted ntfy instance. So I built my own version, tailored to my
infrastructure.

Here's the high-level architecture:

```nil
┌──────────┐      mosh       ┌─────────────┐      ssh        ┌─────────────┐
│  Phone   │───────────────▶ │ Home Server │───────────────▶ │   Work PC   │
│ (Termux) │    WireGuard    │  (Jump Box) │      LAN        │(Claude Code)│
└──────────┘                 └─────────────┘                 └──────┬──────┘
      ▲                                                             │
      │                          ntfy (HTTPS)                       │
      └─────────────────────────────────────────────────────────────┘
```

The loop is: I'm at the beach, I type `cc` on my phone, I land in a tmux session
with Claude Code. I give it a task, pocket the phone, and go back to whatever I
was doing. When Claude has a question or finishes, my phone buzzes. I pull it
out, respond, pocket it again. Development fits into the gaps of the day.

And here's what the async development loop looks like in practice:

```nil
  📱 Phone                    💻 Work PC                   🔔 ntfy
    │                            │                           │
    │──── type 'cc' ────────────▶│                           │
    │──── give Claude a task ───▶│                           │
    │                            │                           │
    │   ┌─────────────────┐      │                           │
    │   │ pocket phone    │      │                           │
    │   └─────────────────┘      │                           │
    │                            │                           │
    │                            │── hook fires ────────────▶│
    │◀── "Claude needs input" ───────────────────────────────│
    │                            │                           │
    │──── respond ──────────────▶│                           │
    │                            │                           │
    │   ┌─────────────────┐      │                           │
    │   │ pocket phone    │      │                           │
    │   └─────────────────┘      │                           │
    │                            │                           │
    │                            │── hook fires ────────────▶│
    │◀── "Task complete" ────────────────────────────────────│
    │                            │                           │
    │──── review, approve PR ───▶│                           │
    │                            │                           │
```


## Why not just use the blog post's setup? {#why-not-just-use-the-blog-post-s-setup}

Granda's setup uses Tailscale for VPN, a Vultr cloud VM, Termius as the mobile
terminal, and Poke for notifications. It's clean and it works. But I had
different constraints:

-   I already have a **WireGuard VPN** running `wg-quick` on a server that connects all my devices. No need
    for Tailscale.
-   I didn't want to pay for a cloud VM. My work PC is more than powerful enough to
    run Claude Code.
-   I self-host **ntfy** for notifications, so no need for Poke or any external
    notification service.
-   I use **Termux** on Android, not Termius on iOS.

If you don't have this kind of infrastructure already, Granda's approach is
probably simpler. But if you're the kind of person who already has a WireGuard
mesh and self-hosted services, this guide is for you.


## The pieces {#the-pieces}

| Component   | Purpose                             | Alternatives                     |
|-------------|-------------------------------------|----------------------------------|
| WireGuard   | VPN to reach home network           | Tailscale, Zerotier, Nebula      |
| mosh        | Network-resilient shell (phone leg) | Eternal Terminal (et), plain SSH |
| SSH         | Secure connection (LAN leg)         | mosh (if you want it end-to-end) |
| tmux        | Session persistence                 | screen, zellij                   |
| Claude Code | The actual work                     | —                                |
| ntfy        | Push notifications                  | Pushover, Gotify, Poke, Telegram |
| Termux      | Android terminal emulator           | Termius, JuiceSSH, ConnectBot    |
| fish shell  | Shell on all machines               | zsh, bash                        |

The key insight is that you need **two different types of resilience**: mosh
handles the flaky mobile connection (WiFi to cellular transitions, dead zones,
phone sleeping), while tmux handles session persistence (close the app, reopen
hours later, everything's still there). Together they make mobile development
actually viable.


## Why the double SSH? Why not make the work PC a WireGuard peer? {#why-the-double-ssh-why-not-make-the-work-pc-a-wireguard-peer}

You might be wondering: if I already have a WireGuard network, why not just add
the work PC as a peer and mosh straight into it from my phone?

The short answer: **it's my employer's machine**. It has monitoring software
installed: screen grabbing, endpoint policies, the works. Installing WireGuard
on it would mean running a VPN client that tunnels traffic through my personal
infrastructure, which is the kind of thing that raises flags with IT security. I
don't want to deal with that conversation.

SSH, on the other hand, is standard dev tooling. An openssh-server on a Linux
machine is about as unremarkable as it gets.

So instead, my home server acts as a jump box. My phone connects to the home
server over WireGuard (that's all personal infrastructure, no employer
involvement), and then the home server SSHs into the work PC over the local
network. The work PC only needs an SSH server, no VPN client, no weird tunnels,
nothing that would make the monitoring software blink.

```nil
    ┌──────────────────────────────────────────────────┐
    │               My Infrastructure                  │
    │                                                  │
    │  ┌───────────┐    WireGuard   ┌──────────────┐   │
    │  │   Phone   │◀──────────────▶│ WG Server    │   │
    │  │  (peer)   │    tunnel      │              │   │
    │  └─────┬─────┘                └──────┬───────┘   │
    │        │                             │           │
    │        │ mosh            WireGuard   │           │
    │        │ (through tunnel)  tunnel    │           │
    │        │                             │           │
    │        ▼                             ▼           │
    │  ┌──────────────┐                                │
    │  │ Home Server  │◀───────────────────────────────│
    │  │   (peer)     │                                │
    │  └──────┬───────┘                                │
    │         │                                        │
    └─────────┼────────────────────────────────────────┘
              │
              │ ssh (LAN)
              │
    ┌─────────┼────────────────────────────────────────┐
    │         ▼                                        │
    │  ┌────────────┐                                  │
    │  │ Work PC    │                                  │
    │  │ (SSH only) │        Employer Infrastructure   │
    │  └────────────┘                                  │
    └──────────────────────────────────────────────────┘
```

As a bonus, this means the work PC has zero exposure to the public internet. It
only accepts SSH from machines on my local network. Defense in depth.


## Phase 1: SSH server on the work PC {#phase-1-ssh-server-on-the-work-pc}

My work PC is running Ubuntu 24.04. First thing: install and harden the SSH
server.

```bash
sudo apt update && sudo apt install -y openssh-server
sudo systemctl enable ssh
```

Note: on Ubuntu 24.04 the service is called `ssh`, not `sshd`. This tripped me
up.

Then harden the config. I created `/etc/ssh/sshd_config` with:

```bash
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AllowAgentForwarding no
X11Forwarding no
UsePAM yes
MaxAuthTries 3
ClientAliveInterval 60
ClientAliveCountMax 3
```

Key-only auth, no root login, no password auth. Since the machine is only
accessible through my local network, this is plenty secure.


### Setting up SSH keys for the home server → work PC connection {#setting-up-ssh-keys-for-the-home-server-work-pc-connection}

On the **home server**, generate a key pair if you don't already have one:

```bash
ssh-keygen -t ed25519 -C "homeserver->workpc"
```

Accept the default path (`/.ssh/id_ed25519`). Then copy the public key to the
work PC:

```bash
ssh-copy-id roger@<work-pc-ip>
```

Now restart sshd:

```bash
sudo systemctl restart ssh
```

**Important**: Test the SSH connection from your home server _before_ closing your
current session. Don't lock yourself out.

```bash
# From the home server
ssh roger@<work-pc-ip>
```

If it drops you into a shell without asking for a password, you're golden.


### Alternative: Tailscale {#alternative-tailscale}

If you don't have a WireGuard setup, [Tailscale](https://tailscale.com/) is the easiest way to get a
private network going. Install it on your phone and your work PC, and they can
see each other directly. No jump host needed, no port forwarding, no firewall
rules. It's honestly magic for this kind of thing. The only reason I don't use it
is because I already had WireGuard running before Tailscale existed.


## Phase 2: tmux + auto-attach {#phase-2-tmux-plus-auto-attach}

The idea here is simple: every time I SSH into the work PC, I want to land
directly in a tmux session. If the session already exists, attach to it. If not,
create one.

First, `~/.tmux.conf`:

```bash
# mouse support (essential for thumbing it on the phone)
set -g mouse on

# start window numbering at 1 (easier to reach on phone keyboard)
set -g base-index 1
setw -g pane-base-index 1

# status bar
set -g status-style 'bg=colour235 fg=colour136'
set -g status-left '#[fg=colour46][#S] '
set -g status-right '#[fg=colour166]%H:%M'
set -g status-left-length 30

# longer scrollback
set -g history-limit 50000

# reduce escape delay (makes editors snappier over SSH)
set -sg escape-time 10

# keep sessions alive
set -g destroy-unattached off
```

Mouse support is **essential** when you're using your phone. Being able to tap to
select panes, scroll with your finger, and resize things makes a massive
difference.

Then in `~/.config/fish/config.fish` on the work PC:

```fish
if set -q SSH_CONNECTION; and not set -q TMUX
    tmux attach -t claude 2>/dev/null; or tmux new -s claude -c ~/projects/my-app
end
```

This checks for `SSH_CONNECTION` so it only auto-attaches when I'm remoting in.
When I'm physically at the machine, I use the terminal normally without tmux.
This distinction becomes important later for notifications.


## Phase 3: Claude Code hooks + ntfy {#phase-3-claude-code-hooks-plus-ntfy}

This is the fun part. Claude Code has a [hook system](https://docs.anthropic.com/en/docs/claude-code/hooks) that lets you run commands
when certain events happen. We're going to hook into three events:

-   **AskUserQuestion**: Claude needs my input. High priority notification.
-   **Stop**: Claude finished the task. Normal priority.
-   **Error**: Something broke. High priority.


### The notification script {#the-notification-script}

First, the script that sends notifications. I created
`~/.claude/hooks/notify.sh`:

```bash
#!/usr/bin/env bash

# Only notify if we're in an SSH-originated tmux session
if ! tmux show-environment SSH_CONNECTION 2>/dev/null | grep -q SSH_CONNECTION=; then
    exit 0
fi

EVENT_TYPE="${1:-unknown}"
NTFY_URL="https://ntfy.example.com/claude-code"
NTFY_TOKEN="tk_your_token_here"

EVENT_DATA=$(cat)

case "$EVENT_TYPE" in
    question)
        TITLE="🤔 Claude needs input"
        PRIORITY="high"
        MESSAGE=$(echo "$EVENT_DATA" | jq -r '.tool_input.question // .tool_input.questions[0].question // "Claude has a question for you"' 2>/dev/null)
        ;;
    stop)
        TITLE="✅ Claude finished"
        PRIORITY="default"
        MESSAGE="Task complete"
        ;;
    error)
        TITLE="❌ Claude hit an error"
        PRIORITY="high"
        MESSAGE=$(echo "$EVENT_DATA" | jq -r '.error // "Something went wrong"' 2>/dev/null)
        ;;
    *)
        TITLE="Claude Code"
        PRIORITY="default"
        MESSAGE="Event: $EVENT_TYPE"
        ;;
esac

PROJECT=$(basename "$PWD")

curl -s \
    -H "Authorization: Bearer $NTFY_TOKEN" \
    -H "Title: $TITLE" \
    -H "Priority: $PRIORITY" \
    -H "Tags: computer" \
    -d "[$PROJECT] $MESSAGE" \
    "$NTFY_URL" > /dev/null 2>&1
```

```bash
chmod +x ~/.claude/hooks/notify.sh
```

The `SSH_CONNECTION` check at the top is crucial: it prevents notifications from
firing when I'm sitting at the machine. Since I only use tmux when SSHing in
remotely, the tmux environment will only have `SSH_CONNECTION` set when I'm
remote. Neat trick.


### Claude Code settings {#claude-code-settings}

Then in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/notify.sh question"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/notify.sh stop"
          }
        ]
      }
    ]
  }
}
```

This is the global settings file. If your project also has a
`.claude/settings.json`, they'll be merged. No conflicts.


### ntfy setup {#ntfy-setup}

I'm self-hosting ntfy, so I created a topic and an access token:

```bash
# Inside your ntfy server/container
ntfy token add --expires=30d your-username
ntfy access your-username claude-code rw
ntfy access everyone claude-code deny
```

ntfy topics are created on demand, so just subscribing to one creates it. On the
Android ntfy app, I pointed it at my self-hosted instance and subscribed to the
`claude-code` topic.

You can test the whole thing works with:

```bash
echo '{"tool_input":{"question":"Should I refactor this?"}}' | ~/.claude/hooks/notify.sh question
echo '{}' | ~/.claude/hooks/notify.sh stop
echo '{"error":"ModuleNotFoundError: No module named foo"}' | ~/.claude/hooks/notify.sh error
```

Three notifications, three different priorities. Very satisfying.


### Alternative notification systems {#alternative-notification-systems}

If you don't want to self-host ntfy, here are some options:

-   **[ntfy.sh](https://ntfy.sh)**: The public instance of ntfy. Free, no setup, just pick a
    random-ish topic name. The downside is that anyone who knows your topic name
    can send you notifications.
-   **[Pushover](https://pushover.net/)**: $5 one-time purchase per platform. Very reliable, nice API. The
    notification script would be almost identical, just a different curl call.
-   **[Gotify](https://gotify.net/)**: Self-hosted like ntfy, but uses WebSockets instead of HTTP. Good if
    you're already running it.
-   **[Telegram Bot API](https://core.telegram.org/bots/api)**: Free, easy to set up. Create a bot with BotFather, get
    your chat ID, and curl the sendMessage endpoint.
-   **[Poke](https://poke.dev/)**: What Granda uses in his post. Simple webhook-to-push service.


## Phase 4: Termux setup {#phase-4-termux-setup}

Termux is the terminal emulator on my Android phone. Here's how I set it up.

```bash
pkg update && pkg install -y mosh openssh fish
```


### SSH into your phone (for easier setup) {#ssh-into-your-phone--for-easier-setup}

Configuring all of this on a phone keyboard is painful. I set up sshd on Termux
so I could configure it from my PC.

In `~/.config/fish/config.fish`:

```fish
sshd 2>/dev/null
```

This starts sshd every time you open Termux. If it's already running, it
silently fails. Termux runs sshd on port 8022 by default.

First, set a password on Termux (you'll need it for the initial key copy):

```bash
passwd
```

Then from your PC, copy your key and test the connection:

```bash
ssh-copy-id -p 8022 <phone-ip>
ssh -p 8022 <phone-ip>
```

Now you can configure Termux comfortably from your PC keyboard.


### Generating SSH keys on the phone {#generating-ssh-keys-on-the-phone}

On Termux, generate a key pair:

```bash
ssh-keygen -t ed25519 -C "phone"
```

Then copy it to your home server:

```bash
ssh-copy-id <your-user>@<home-server-wireguard-ip>
```

This gives you passwordless `phone → home server`. Since we already set up
`home server → work PC` keys in Phase 1, the full chain is now passwordless.


### SSH config {#ssh-config}

The SSH config is where the magic happens. On Termux:

```nil
Host home
    HostName <home-server-wireguard-ip>
    User <your-user>

Host work
    HostName <work-pc-ip>
    User roger
    ProxyJump home
```

`ProxyJump` is the key: `ssh work` automatically hops through the home server.
No manual double-SSHing.


### Fish aliases {#fish-aliases}

These are the aliases that make everything a one-command operation:

```fish
# Connect to work PC, land in tmux with Claude Code ready
alias cc="mosh home -- ssh -t work"

# New tmux window in the claude session
alias cn="mosh home -- ssh -t work 'tmux new-window -t claude -c \$HOME/projects/my-app'"

# List tmux windows
alias cl="ssh work 'tmux list-windows -t claude'"
```

`cc` is all I need to type. Mosh handles the phone-to-home-server connection
(surviving WiFi/cellular transitions), SSH handles the home-server-to-work-PC
hop over the LAN, and the fish config on the work PC auto-attaches to tmux.


### Alternative: Termius {#alternative-termius}

If you're on iOS (or just prefer a polished app), [Termius](https://termius.com/) is what Granda uses.
It supports mosh natively and has a nice UI. The downside is it's a subscription
for the full features. Termux is free and gives you a full Linux environment, but
it's Android-only and definitely more rough around the edges.

Other options: [JuiceSSH](https://juicessh.com/) (Android, no mosh), [ConnectBot](https://connectbot.org/) (Android, no mosh).
Mosh support is really the killer feature here, so Termux or Termius are the
best choices.


## Phase 5: The full flow {#phase-5-the-full-flow}

Here's what my actual workflow looks like:

1.  I'm at the beach/coffee shop/couch/wherever 🏖️
2.  Open Termux, type `cc`
3.  I'm in my tmux session on my work PC
4.  Start Claude Code, give it a task: "add pagination to the user dashboard API
    and update the tests"
5.  Pocket the phone
6.  Phone buzzes: "🤔 Claude needs input — Should I use cursor-based or
    offset-based pagination?"
7.  Pull out phone, Termux is still connected (thanks mosh), type "cursor-based,
    use the created_at field"
8.  Pocket the phone again
9.  Phone buzzes: "✅ Claude finished — Task complete"
10. Review the changes, approve the PR, go back to the beach

The key thing that makes this work is the combination of **mosh** (connection
survives me pocketing the phone) + **tmux** (session survives even if mosh dies) +
**ntfy** (I don't have to keep checking the screen). Without any one of these
three, the experience breaks down.


## Security considerations {#security-considerations}

A few things to keep in mind:

-   **SSH keys only**: No password auth anywhere in the chain. Keys are easier to
    manage and impossible to brute force.
-   **WireGuard**: The work PC is only accessible through my local network. No ports
    exposed to the public internet.
-   **ntfy token auth**: The notification topic requires authentication. No one else
    can send you fake notifications or read your Claude Code questions.
-   **Claude Code in normal mode**: Unlike Granda's setup where he runs permissive
    mode on a disposable VM, my work PC is _not_ disposable. Claude asks before
    running dangerous commands, which pairs nicely with the notification system.
-   **tmux SSH check**: Notifications only fire when I'm remote. When I'm at the
    machine, no unnecessary pings.


## Conclusion {#conclusion}

The whole setup took me about an hour to put together. The actual configuration
is pretty minimal: an SSH server, a tmux config, a notification script, and some
fish aliases.

What I love about this setup is that it's **all stuff I already had**. WireGuard
was already running, ntfy was already self-hosted, Termux was already on my
phone. I just wired them together with a few scripts and some Claude Code hooks.

If you have a similar homelab setup, you can probably get this running in 30
minutes. If you're starting from scratch, Granda's [cloud VM approach](https://granda.org/en/2026/01/02/claude-code-on-the-go/) is probably
easier. Either way, async coding from your phone is genuinely a game changer.

See you in the next one!
