+++
title = "Running Headscale on my own infra (and finally killing my WireGuard setup)"
author = ["Roger Gonzalez"]
date = 2026-08-03
lastmod = 2026-08-03T08:38:19-03:00
tags = ["selfhosted", "vpn", "headscale", "tailscale", "docker", "nginx", "pihole"]
draft = false
+++

Hello everyone 👋

This one started in the dumbest possible way: I wanted to check on my 3D printer
from outside my house.

I have a Bambu printer running in LAN-only mode, and I use [OctoApp](https://octoapp.eu/) to control it
from my phone. Works great at home. Useless the moment I leave. The usual answer
is OctoEverywhere, which is a lovely project, but it means my printer traffic
goes through someone else's servers, and I already run enough infrastructure
that this felt silly.

So I went looking for a way to just... have my home network with me. And I ended
up rebuilding my entire remote access setup in an afternoon.


## What I had before {#what-i-had-before}

My old setup was, in hindsight, a bit of a Rube Goldberg machine:

-   A Hetzner VPS running WireGuard
-   A node at home connected to that WireGuard tunnel
-   Nginx Proxy Manager on that node
-   A Pi-hole for the WireGuard side, resolving things to `10.0.0.x` addresses
-   _Another_ Pi-hole for my actual home network, resolving to `192.168.0.x`

Two Pi-holes. Two address ranges. Two mental models of "where am I right now".
It worked, but every time I added a service I had to think about which side of
the tunnel it lived on.

What I actually wanted was much simpler: when I'm away, I want my phone to
behave exactly like it's sitting on my home WiFi. Same IPs, same DNS, no
difference at all.

That's a mesh VPN, and the nicest one is Tailscale.


## I don't trust free {#i-don-t-trust-free}

Tailscale is excellent. I want to say that first, because what follows
is going to sound like criticism and it isn't. The client is great, the free
tier is generous, and for most people it's the right answer.

But every time I look at a free tier this good, I catch myself doing the same
mental arithmetic: someone is paying for this, and it isn't me. Tailscale is a
venture-funded company. Free tiers built on top of venture funding have a
well-documented lifecycle, and the last chapter is rarely "and it stayed free
and generous forever". The limits shrink, or a device cap appears that you're
already over, or the company gets acquired by someone with different ideas.

I'm not predicting that Tailscale does any of this. I have no reason to think
they will. But I built my remote access on a WireGuard tunnel I control, and
moving to something where a company I don't control holds the keys to my entire
home network felt like a downgrade, even if the software is better.

I've also been burned recently enough that I'm not in a trusting mood. I wrote a
[whole angry post](/2026/04/anthropic-is-pushing-away-its-paying-customers/) a few months ago about paying $100 a month for a service and
getting less than 24 hours of notice before it changed underneath me. That was a
_paid_ tier. If that's what happens when I'm a customer, I'm not going to build
my house on a free one.

So: I like the idea, I don't trust the arrangement. Which is exactly the
situation self-hosting exists for.

Enter [Headscale](https://headscale.net/).


## What Headscale actually is {#what-headscale-actually-is}

Headscale is an open source implementation of the Tailscale control server. Your
devices still run the official Tailscale client, they just point at your server
instead of Tailscale's.

The important thing to understand is what the control server does and doesn't
do. It handles key exchange, device registration, ACLs, and DNS settings. It
does _not_ sit in the middle of your traffic. Once two devices know about each
other, they talk directly. So Headscale being a small container on a cheap VPS
is completely fine.

I put it on the same Hetzner box that was already running WireGuard, because it
already has a public IP and I was going to be deleting the WireGuard side
anyway.


## The Docker Compose setup {#the-docker-compose-setup}

Headscale is CLI-first, which is fine, but I got tired of typing
`docker exec headscale headscale ...` within about four minutes. So I also added
[Headplane](https://headplane.net/), a web UI for it.

Directory structure first:

```bash
mkdir -p ~/headscale/config/{headscale,headplane}
cd ~/headscale
wget -O config/headscale/config.yaml https://raw.githubusercontent.com/juanfont/headscale/main/config-example.yaml
wget -O config/headplane/config.yaml https://raw.githubusercontent.com/tale/headplane/main/config.example.yaml
```

And the compose file:

```yaml
services:
  headplane:
    image: ghcr.io/tale/headplane:latest
    container_name: headplane
    restart: unless-stopped
    ports:
      - "3003:3000"
    volumes:
      - ./config/headplane/config.yaml:/etc/headplane/config.yaml
      - ./config/headplane/lib:/var/lib/headplane
      # Shared path to the Headscale config. This has to match
      # `headscale.config_path` in the Headplane config.
      - ./config/headscale/config.yaml:/etc/headscale/config.yaml
      - /var/run/docker.sock:/var/run/docker.sock:ro

  headscale:
    image: headscale/headscale:latest
    container_name: headscale
    restart: unless-stopped
    command: serve
    labels:
      # Absolutely necessary for Headplane to find Headscale.
      me.tale.headplane.target: headscale
    ports:
      - "8083:8080"
    volumes:
      # Same host path in both containers. This matters.
      - ./config/headscale/config.yaml:/etc/headscale/config.yaml
      - ./config/headscale/lib:/var/lib/headscale
```

Nginx handles TLS and public exposure, same as every other service on that box.
If you're not putting a firewall in front of these, bind the ports to
`127.0.0.1` instead (`"127.0.0.1:8083:8080"`), otherwise Docker happily opens
them to the internet and walks around UFW while it's at it.

Note the `me.tale.headplane.target` label on the Headscale container. That's how
Headplane finds it, and it's how Headplane restarts Headscale when you change
DNS settings from the UI. Note also that both containers mount the Headscale
config from the same host path. Headplane reads it directly, so if the paths
drift you get a UI that shows you stale settings.


## Headscale config {#headscale-config}

The parts of `config/headscale/config.yaml` that matter:

```yaml
server_url: https://headscale.example.com
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 127.0.0.1:9090

database:
  type: sqlite3
  sqlite:
    path: /var/lib/headscale/db.sqlite

dns:
  magic_dns: true
  base_domain: ts.example.com
  override_local_dns: true
  nameservers:
    global:
      - 1.1.1.1
```

Leave `nameservers.global` pointing at a public resolver for now. We'll swap it
for the Pi-hole later, once the Pi-hole has joined the network and has an
address to point at.

`base_domain` has to be different from your `server_url` domain, otherwise
Headscale refuses to start.


## Headplane config {#headplane-config}

In `config/headplane/config.yaml`:

```yaml
server:
  host: "0.0.0.0"
  port: 3000
  base_url: "https://headplane.example.com"
  cookie_secret: "<32 char random string>"
  cookie_secure: true
  data_path: "/var/lib/headplane"

headscale:
  url: "http://headscale:8080"
  config_path: "/etc/headscale/config.yaml"
  api_key: ""
```

Generate the cookie secret with `openssl rand -hex 32`.

The `url` is the _internal_ Docker address: container name, container port. Not
whatever port you mapped on the host. The two containers talk over the compose
network.

Then start Headscale on its own, create a user and an API key:

```bash
docker compose up -d headscale
docker exec headscale headscale users create myuser
docker exec headscale headscale apikeys create --expiration 90d
```

Paste that key into `api_key` and bring up Headplane. The key is only shown
once, so if you lose it, just make another one. `apikeys list` only shows the
prefix.


## Nginx {#nginx}

Two vhosts, nothing exotic. But the Headscale one needs WebSocket passthrough,
and this is the first place I lost time (more on that below):

```nginx
location / {
    proxy_pass http://127.0.0.1:8083;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_redirect off;
    proxy_read_timeout 5m;
}
```

Headplane is a boring proxy block, no special headers needed. Certbot for certs,
as usual.


## Pi-hole as the tailnet DNS {#pi-hole-as-the-tailnet-dns}

This is my favourite part of the whole setup, and the reason I bothered.

Join your home Pi-hole to the network like any other device:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --login-server https://headscale.example.com
tailscale ip -4
```

Take that `100.x.x.x` address, put it in Headscale's `dns.nameservers.global`,
and restart the container.

Now every device on the tailnet uses my home Pi-hole for _all_ DNS. Which means:

-   `sonarr.example.casa` and every other internal domain resolves from anywhere,
    because Pi-hole's Local DNS Records answer for them
-   My phone gets Pi-hole ad blocking on cellular data, not just at home

Neither of those is new, I had both with the old WireGuard setup. The difference
is that I now get them from one Pi-hole instead of two, and I didn't have to
think about it. The Pi-hole joined the tailnet, I pointed Headscale at it, and
every device I add from now on inherits both for free.

`override_local_dns: true` is what forces this. Without it, your phone keeps
using whatever DNS the carrier hands it, the tunnel works fine, and your
internal domains silently fail to resolve.


## The subnet router {#the-subnet-router}

A mesh VPN only connects the devices that are _on_ it. My printer can't run a
Tailscale client. Neither can most of the stuff I care about.

The fix is a subnet router: one device on your LAN that advertises the whole
network to everyone else. I used the Pi-hole box, since it was already joined:

```bash
sudo tailscale up --login-server https://headscale.example.com \
  --advertise-routes=192.168.0.0/24
```

Two things have to happen after this or nothing works, and I hit both.

First, IP forwarding:

```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
```

Second, and this is the one that got me: routes are **double opt-in**. The node
advertises, and then the control server has to approve. Advertising alone does
nothing.

```bash
docker exec headscale headscale nodes list-routes
docker exec headscale headscale nodes approve-routes --identifier 1 --routes 192.168.0.0/24
```

The moment I ran that second command, everything worked. Printer, internal
domains, random machines on my LAN, all reachable from my phone on cellular.


## Clients {#clients}

You don't need a special app. The official Tailscale clients all support custom
control servers.

On Android, install from Play Store or F-Droid, go to "Accounts", tap the kebab
menu, and select "Use an alternate server". Enter your Headscale URL and log in.

On iOS it's slightly more buried: install from the App Store, tap the account
icon, "Log in", then use the options menu to pick "Use custom coordination
server".

macOS is the one with a real trap. Use the standalone build, not the Mac App
Store one, because the App Store version is sandboxed and fights you on custom
control servers. `brew install tailscale` works, or grab the standalone package
from Tailscale's download page. Then:

```bash
sudo tailscale up --login-server https://headscale.example.com
tailscale set --accept-routes
```

That `--accept-routes` is easy to forget. Without it the client joins fine and
then can't see anything on your LAN.


## The gotchas that cost me the most time {#the-gotchas-that-cost-me-the-most-time}

Four things ate most of my afternoon. All of them had error messages that
pointed somewhere other than the actual problem.


### Headscale listening on 127.0.0.1 inside its own container {#headscale-listening-on-127-dot-0-dot-0-dot-1-inside-its-own-container}

Headplane kept logging this:

```nil
Error while validating API key: [object Object]
```

I regenerated that API key three times. The key was fine. The real problem was
one line above in the Headscale logs:

```nil
INF listening and serving HTTP on: 127.0.0.1:8080
```

`127.0.0.1` inside a container means _that container only_. Not the compose
network, not the other container sitting right next to it. Headplane literally
could not open a connection, so it couldn't validate anything, and reported that
as an auth failure.

Set `listen_addr: 0.0.0.0:8080` in the Headscale config. Your host port mapping
is a separate concern and keeps working the same.


### Nginx eating the WebSocket upgrade {#nginx-eating-the-websocket-upgrade}

Clients wouldn't connect, and Headscale said:

```nil
WRN no upgrade header in TS2021 request. If headscale is behind a reverse proxy,
make sure it is configured to pass WebSockets through.
```

At least this error tells you exactly what's wrong. My nginx config was a
copy-paste of the same reverse proxy block I use for every other service on that
box, which has no `Upgrade` handling because nothing else needs it.

The commonly recommended fix uses a `map` block in the `http` context:

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}
```

The idea is that plain HTTP requests to the same vhost get `Connection: close`
instead of a bogus `Connection: upgrade`. If you put that map somewhere nginx
doesn't load it into the `http` context, you get
`unknown "connection_upgrade" variable` and nothing starts.

I'll be honest: I got that error, commented the `Connection` line out entirely
to keep moving, and it worked. It's on my list to go back and do properly,
because "it worked when I removed the correctness" is not a state I enjoy
leaving things in.


### The routes CLI moved {#the-routes-cli-moved}

Every guide and blog post out there tells you to run:

```bash
headscale routes list
headscale routes enable -r 1
```

On 0.29 that gives you `unknown command "routes"`. It's now under `nodes`:

```bash
headscale nodes list-routes
headscale nodes approve-routes --identifier 1 --routes 192.168.0.0/24
```

Related: `--user` wants a numeric ID now, not a username. `headscale users list`
gives you the number.

When in doubt, `headscale --help` is more current than anything you'll find in a
search result. I lost a few minutes to blog posts written against older versions
before I just asked the binary.


### Pi-hole ignoring the tailnet {#pi-hole-ignoring-the-tailnet}

Tunnel up, subnet routes approved, `ping 1.1.1.1` working, and
`google.com` resolving to nothing.

Pi-hole's default interface listening behaviour doesn't answer queries arriving
on the `tailscale0` interface. Settings, then DNS, then set it to listen on all
interfaces and permit all origins. Or scope it to the tailnet CIDR if you want
to be tidier about it than I was.


## The bash alias {#the-bash-alias}

Small thing, big quality of life improvement:

```bash
alias headscale='docker exec headscale headscale'
```

Now every command in every tutorial you find online works verbatim, without
mentally prefixing the docker part every time. Just remember it's there if you
ever install the real binary on the same box, or you'll spend an entertaining
twenty minutes wondering why the local install ignores your config file.


## What I still need to do {#what-i-still-need-to-do}

I'm not going to pretend this is finished.

The old WireGuard tunnel and its dedicated Pi-hole are still running. Headscale
does everything they did, but I'm leaving them up until I've gone through the
Nginx Proxy Manager config and confirmed nothing still points at a `10.0.0.x`
address. Deleting infrastructure at 2 AM after a successful afternoon is how you
learn what depended on it.


## Was it worth it? {#was-it-worth-it}

Yes, and for reasons beyond the printer.

The setup collapsed two Pi-holes and two IP ranges into one mental model. My
phone now behaves identically at home and on cellular. Every internal service I
add from now on works remotely for free, without port forwarding or a new proxy
host or any thought about which side of a tunnel it lives on.

And no ports are open to my LAN. The only publicly reachable thing is the
Headscale control server, which hands out keys and doesn't carry traffic.

The total cost was one afternoon, most of which was spent on four error messages
that pointed at the wrong thing. Hopefully this post saves you those.

If you want to check the printer thing specifically: Bambu printers in LAN-only
mode expose MQTT on 8883 and FTPS on 990. There's no web UI, so don't waste time
typing the IP into a browser like I did. Once you're on the tailnet, OctoApp
just takes the same local IP and access code you use at home.

See you in the next one!
