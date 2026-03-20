+++
title = "How I deploy my projects to a single VPS with Gitea, NGINX and Docker"
author = ["Roger Gonzalez"]
date = 2026-03-15
lastmod = 2026-03-20T10:15:04-03:00
tags = ["programming", "selfhosted", "vps", "docker", "nginx", "gitea", "", "devops"]
draft = false
skip_webp_rewrite = true
+++

Hello everyone 👋

A few weeks ago, the team behind [Jmail](https://jmail.world/) (a Gmail-styled interface for browsing
the publicly released Epstein files) shared that they had [racked up a **$46,485
bill on Vercel**](https://x.com/rtwlz/status/2020957597810254052) The site had gone viral with ~450 million pageviews, and
Vercel's pricing structure turned that into a five-figure invoice. Vercel's CEO
ended up covering the bill personally, which is nice, but not exactly a
scalable solution 😅

When I saw that story, my first thought was: _this is an efficiency problem_.
Jmail is essentially a search interface on top of mostly static content. [An SRE
on Hacker News](https://news.ycombinator.com/item?id=46963473) mentioned they handle 200x Jmail's request load on just two
Hetzner servers. The whole thing could have been served from a moderately sized
VPS for a fraction of the cost.

That got me thinking about my own setup. I run **everything** on a single VPS: my
blog, my side projects, my git server, analytics, a wiki, a forum, a secret
sharing tool, and more. The whole thing is held together by NGINX, Gitea, some
bash scripts, and Docker. No Kubernetes, no Terraform, no CI/CD platform with a
$500/month bill. Just a cheap VPS, some config files, and a deployment flow
that's simple enough that I can fix it from my phone at the beach (I've [written
about that before](/2026/02/claude-code-from-the-beach-remote-coding-setup/)).

I get asked about my deployment setup more often than I expected, so I figured
I'd write it all down. Let me walk you through the whole thing.


## The VPS {#the-vps}

I'm running a [Hetzner Cloud](https://www.hetzner.com/cloud/) CPX21 in Nuremberg, Germany. Here are the specs:

| Spec  | Value       |
|-------|-------------|
| vCPUs | 3           |
| RAM   | 4 GB        |
| Disk  | 80 GB SSD   |
| OS    | Ubuntu      |
| Price | ~€7-8/month |

The CPX21 is one of Hetzner's shared vCPU instances. It's cheap, reliable, and
more than enough for what I need. I'm usually sitting at around ~10% CPU and
~2GB RAM, so there's plenty of headroom.

I set up the VPS manually. No Ansible, no configuration management, just plain
old SSH and installing things by hand. I know, I know, "infrastructure as code"
and all that. But for a single server that I manage myself, the overhead of
automating the setup isn't worth it. If the server dies, I can set it up again
in a couple of hours and restore from backups.


## What's running on it {#what-s-running-on-it}

Here's everything running on this single VPS:


### Bare metal (directly on the server) {#bare-metal--directly-on-the-server}

| Service                          | Purpose                    |
|----------------------------------|----------------------------|
| [Gitea](https://git.rogs.me)     | Self-hosted git server     |
| NGINX                            | Web server / reverse proxy |
| Certbot                          | SSL/TLS certificates       |
| PHP-FPM                          | For WordPress sites        |
| [DokuWiki](https://wiki.rogs.me) | Personal wiki              |
| fail2ban                         | Brute force protection     |
| UFW                              | Firewall                   |
| A couple WordPress sites         | Various projects           |


### Docker {#docker}

| Service                                          | Purpose                          |
|--------------------------------------------------|----------------------------------|
| [ntfy](https://ntfy.sh)                          | Push notifications               |
| [shhh](https://github.com/smallwat3r/shhh)       | Secret sharing                   |
| [SearXNG](https://searx.github.io/searx/)        | Privacy-respecting search engine |
| WireGuard                                        | VPN                              |
| [phpBB](https://forum.yams.media)                | YAMS community forum             |
| [Umami](https://umami.is/)                       | Privacy-respecting analytics     |
| Gitea Actions runner                             | CI/CD runner                     |
| [Watchtower](https://containrrr.dev/watchtower/) | Automatic Docker image updates   |


### Static sites (Hugo, served by NGINX) {#static-sites--hugo-served-by-nginx}

| Site                                                   | Purpose                 |
|--------------------------------------------------------|-------------------------|
| [rogs.me](https://rogs.me)                             | This blog!              |
| [montevideo.restaurant](https://montevideo.restaurant) | Restaurant directory    |
| [yams.media](https://yams.media)                       | YAMS documentation site |

That's a lot of stuff for a 4GB VPS. But static sites are basically free in
terms of resources, and the Docker services are all lightweight. The heaviest
things are probably Gitea and the WordPress sites, and even those barely register.


## The web server: NGINX {#the-web-server-nginx}

Every site and service gets its own NGINX config file in `/etc/nginx/conf.d/`.
One file per site, nice and clean. No `sites-available` / `sites-enabled`
symlink dance.

Here's what a typical config looks like for one of my Hugo sites:

```nginx
server {
    root /var/www/rogs.me;
    index index.html;

    server_name rogs.me;

    location / {
        try_files $uri $uri/ =404;
    }

    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/rogs.me/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/rogs.me/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}

server {
    if ($host = rogs.me) {
        return 301 https://$host$request_uri;
    }

    server_name rogs.me;
    listen 80;
    return 404;
}
```

Nothing fancy. Serve files from `/var/www/rogs.me`, redirect HTTP to HTTPS,
done. The SSL bits are all managed by Certbot (more on that later).

For Docker services, the config looks slightly different because NGINX acts as a
reverse proxy:

```nginx
server {
    server_name analytics.rogs.me;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    listen 443 ssl; # managed by Certbot
    # ... SSL config same as above
}
```

Same pattern: one file per service, NGINX handles SSL termination, and proxies
to whatever port the Docker container exposes on localhost.


## SSL/TLS with Let's Encrypt {#ssl-tls-with-let-s-encrypt}

All certificates come from [Let's Encrypt](https://letsencrypt.org/) via Certbot. I installed it with
`apt` and used the NGINX plugin:

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d rogs.me
```

Certbot modifies the NGINX config automatically to add the SSL directives
(that's why you see those `# managed by Certbot` comments).

Certificates auto-renew daily at 3 AM via a cron job:

```bash
0 3 * * * certbot renew -q
```

The `-q` flag keeps it quiet: no output unless something goes wrong. Certbot
is smart enough to only renew certificates that are close to expiring, so
running it daily is fine.


## Self-hosted git with Gitea {#self-hosted-git-with-gitea}

I use [Gitea](https://gitea.com/) as my primary git server. It runs bare metal on the VPS (not in
Docker) and lives at [git.rogs.me](https://git.rogs.me).

**Why Gitea instead of just using GitHub?** I want to own my git infrastructure.
GitHub is great for collaboration, but I like having control over where my code
lives. If GitHub goes down or decides to change their terms, my repos are safe
on my own server.

That said, I mirror everything to both GitHub and GitLab so other people can
collaborate, open issues, and submit PRs. Best of both worlds: I own the
primary, and the mirrors handle the social coding side.


### Gitea Actions {#gitea-actions}

Gitea has a built-in CI/CD system called [Gitea Actions](https://docs.gitea.com/usage/actions/overview) that's compatible with
GitHub Actions workflows. The runner is the official `gitea/act_runner` Docker
image, running on the same VPS. Pretty vanilla setup, no custom configuration.

This is the core of my deployment pipeline. Every time I push to `master`, Gitea
Actions picks up the workflow and deploys the site.


## Deploying Hugo sites {#deploying-hugo-sites}

This is where it all comes together. All three of my Hugo sites follow the exact
same deployment pattern. Here's the flow:

```nil
  ┌──────────┐       push        ┌──────────┐     Gitea Actions    ┌──────────┐
  │   Local   │────────────────▶ │  Gitea   │ ────────────────────▶│  Runner  │
  │  machine  │                  │(git.rogs)│                      │ (Docker) │
  └──────────┘                   └──────────┘                      └────┬─────┘
                                                                        │
                                                            SSH into same VPS
                                                                        │
                                                                        ▼
                                                                 ┌──────────┐
                                                                 │   VPS    │
                                                                 │ git pull │
                                                                 │ build.sh │
                                                                 └────┬─────┘
                                                                      │
                                                              Hugo builds to
                                                             /var/www/domain/
                                                                      │
                                                                      ▼
                                                                 ┌──────────┐
                                                                 │  NGINX   │
                                                                 │  serves  │
                                                                 └──────────┘
```

Yes, the Gitea Actions runner SSHes into the same server it's running on. I know
that's a bit redundant, but I designed it this way on purpose: if I ever move my
hosting somewhere else (or switch back to GitHub Actions), the workflow doesn't
need to change. The SSH target is just a secret, so I swap an IP address and
everything keeps working.


### The Gitea Actions workflow {#the-gitea-actions-workflow}

Here's the workflow file that lives in `.gitea/workflows/deploy.yml` in each
repo:

```yaml
name: deploy

on:
  push:
    branches:
      - master

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          port: ${{ secrets.SSH_PORT }}
          script: |
            cd repo && git stash && git pull --force origin master && ./build.sh
```

It's beautifully simple:

1.  Push to `master` triggers the workflow
2.  The runner uses [appleboy/ssh-action](https://github.com/appleboy/ssh-action) to SSH into the server
3.  On the server: stash any local changes, pull the latest code, and run the
    build script

The `git stash` is there as a safety net. The WebP conversion in the build
script modifies tracked files (more on that in a second), so without the stash,
`git pull` would complain about dirty working tree.

All four secrets (`SSH_HOST`, `SSH_USER`, `SSH_PRIVATE_KEY`, `SSH_PORT`) are
configured in Gitea's repository settings. The SSH key has access to the server
but is locked down to only what the deployment needs.


### The build script {#the-build-script}

Every Hugo site has a `build.sh` in the repo root. Here's the one for this blog:

```bash
#!/bin/bash

# Convert all images to WebP for better performance
for file in $(git ls-files --others --cached --exclude-standard \
    | grep -v '.git' \
    | grep -E '\.(png|jpg|jpeg)$'); do
    cwebp -lossless "$file" -o "${file%.*}.webp"
done

# Update all references from png/jpg/jpeg to webp
for tracked_file in $(git ls-files --others --cached --exclude-standard \
    | grep -v '.git'); do
    sed -i 's/\.png/.webp/g' "$tracked_file"
    sed -i 's/\.jpg/.webp/g' "$tracked_file"
    sed -i 's/\.jpeg/.webp/g' "$tracked_file"
done

# Build the site
hugo -s . -d /var/www/rogs.me/ --minify --cacheDir $PWD/hugo-cache
```

Three things happen here:

1.  **Image optimization**: Every PNG, JPG, and JPEG gets converted to WebP using
    `cwebp` (lossless mode, so no quality loss). WebP files are significantly
    smaller than their originals.
2.  **Reference rewriting**: All file references get updated from `.png` /
    `.jpg` / `.jpeg` to `.webp`. This is why we need `git stash` in the
    workflow; this step modifies tracked files.
3.  **Hugo build**: Generates the static site with minification enabled and outputs
    it directly to `/var/www/rogs.me/`. NGINX is already configured to serve from
    that directory, so the site is live immediately.

The `--cacheDir` flag keeps Hugo's build cache in the repo directory, which
speeds up subsequent builds.

Each site's `build.sh` is essentially identical, just with a different output
path (`montevideo.restaurant`, `yams.media`, etc.).


### Variations across sites {#variations-across-sites}

While the pattern is the same, there are small differences:

-   **yams.media** has a two-job workflow: a `test_build` job runs Hugo in a Docker
    container first to make sure the build succeeds, and only then does the deploy
    job run. This is because the YAMS docs site has more contributors, so I want
    to catch build errors before they hit production.
-   **yams.media** also uses `--cleanDestinationDir` and `--gc` flags for a cleaner
    build output.


## Docker services and Watchtower {#docker-services-and-watchtower}

Most of my non-static services run in Docker with `docker-compose`. Each
service has its own directory in `/opt/`:

```nil
/opt/
├── analytics.rogs.me/    # Umami
│   └── docker-compose.yml
├── ntfy/
│   └── docker-compose.yml
├── shhh/
│   └── docker-compose.yml
├── searx/
│   └── docker-compose.yml
└── ...
```

For updates, I use [Watchtower](https://containrrr.dev/watchtower/). It runs as a Docker container itself and
periodically checks if there are newer images available for my running
containers. If there are, it pulls the new image, stops the old container, and
starts a new one with the same configuration.

```yaml
version: "3"
services:
  watchtower:
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped
```

Is this a bit risky? Sure. An automatic update could break something. But in
practice, it hasn't failed me once, and the services I'm running are stable
enough that breaking changes in Docker images are rare. For a personal setup,
the convenience of never having to manually update containers is worth the small
risk.


## Security {#security}

I'm not running a bank here, but I do take basic security seriously:

-   **UFW (Uncomplicated Firewall)**: Only NGINX ports (80, 443) and SSH are open.
    Everything else is blocked.
-   **fail2ban**: Watches SSH logs and bans IPs after too many failed login
    attempts. Essential if your SSH port is exposed to the internet.
-   **SSH keys only**: Password authentication is disabled. If you don't have the
    key, you're not getting in.
-   **Let's Encrypt everywhere**: Every site and service gets HTTPS. No exceptions.
-   **Docker services on localhost**: All Docker containers bind to `localhost`.
    They're only accessible through the NGINX reverse proxy, which handles SSL
    termination.

<!--listend-->

```bash
# Quick UFW setup
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 'Nginx Full'
sudo ufw allow ssh
sudo ufw enable
```


## DNS {#dns}

All my domains use [Cloudflare](https://www.cloudflare.com/) for DNS. But **only DNS** for most of them. I'm
not using Cloudflare's CDN or proxy features on my main sites. The DNS records
point directly to my VPS IP with the proxy toggle set to "DNS only" (the grey
cloud, not the orange one).

Why Cloudflare for DNS? Two reasons. First, it's free, fast, and the dashboard
is easy to use. Second, and more importantly: if something goes wrong, I can
switch to using Cloudflare's full proxy and DDoS protection **with the flick of a
button**. Just toggle the grey cloud to orange and you're behind Cloudflare's
network instantly.

I've already had to do this once. [forum.yams.media](https://forum.yams.media) (the YAMS community forum)
was getting DDoSed and swarmed by bots constantly. Flipping that toggle to
orange solved the problem immediately. The rest of my sites run without
Cloudflare's proxy because they don't need it, but knowing I can turn it on in
seconds gives me peace of mind.


## Backups {#backups}

This is the part that most people skip. Don't be most people.

My backup strategy has two stages:

```nil
  ┌─────────────┐   11 PM cron    ┌───────────────────┐
  │     VPS     │ ───────────────▶│ /home/backups/     │
  │  (services) │   tar + GPG     │ (encrypted .gpg)   │
  └─────────────┘                 └─────────┬─────────┘
                                            │
                                     midnight cron
                                       (SSH pull)
                                            │
                                            ▼
                                  ┌──────────────────┐
                                  │   Home Server    │
                                  │   (NAS + S3)     │
                                  └──────────────────┘
```


### Stage 1: Backup on the VPS (11 PM) {#stage-1-backup-on-the-vps--11-pm}

Every night at 11 PM, a series of cron jobs run backup scripts for each service.
Each script follows the same pattern:

```bash
#!/bin/bash

BACKUP_DIR="/home/backups/servicename"
TARGET_DIR="/path/to/service"
DATE=$(date +%Y-%m-%d-%s)
BACKUP_FILE="$BACKUP_DIR/backup-servicename-$DATE.tar.zst"
ENCRYPTED_FILE="$BACKUP_FILE.gpg"
LOG_FILE="/var/log/backup_servicename.log"
GPG_RECIPIENT="your-email@example.com"

log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_message "=== Starting backup ==="

mkdir -p "$BACKUP_DIR"

# For Docker services: stop containers first
docker compose stop

# Create compressed archive
tar -caf "$BACKUP_FILE" -C "$TARGET_DIR" .

# Encrypt with GPG
gpg --encrypt --armor -r "$GPG_RECIPIENT" -o "$ENCRYPTED_FILE" "$BACKUP_FILE"
rm -f "$BACKUP_FILE"  # Remove unencrypted version

# For Docker services: restart containers
docker compose up -d

log_message "=== Backup completed ==="
```

Key points:

-   **Compression**: I use `tar.zst` ([Zstandard](https://facebook.github.io/zstd/)) for compression. It's faster than
    gzip and produces smaller files.
-   **Encryption**: Every backup gets GPG-encrypted before it touches the network.
    Even if someone gets access to the backup files, they're useless without my
    private key.
-   **Docker services**: For services running in Docker, the script stops the
    containers before backing up to ensure data consistency, then starts them again.
    This causes a brief downtime (usually a few seconds), which is fine for
    personal services at 11 PM.
-   **Database dumps**: For services with databases (like Gitea, which uses MySQL),
    the script dumps the database separately with `mysqldump` before creating the
    archive.
-   **Logging**: Every step is logged to `/var/log/`, so I can check if something
    went wrong.


### Stage 2: Pull to home server (midnight) {#stage-2-pull-to-home-server--midnight}

At midnight, my home server SSHes into the VPS and pulls all the encrypted
backup files to my local NAS. From there, they also get pushed to an S3 bucket.

This gives me the classic **3-2-1 backup strategy**: 3 copies of the data (VPS,
NAS, S3), on 2 different media types, with 1 offsite copy. If Hetzner's
datacenter burns down, I have everything locally. If my house burns down, I have
everything in S3.


## Monitoring {#monitoring}

I run [Uptime Kuma](https://github.com/louislam/uptime-kuma) on my home server to monitor all my services. It checks
every site and service periodically and sends me a notification (via ntfy,
naturally) if something goes down.

It's not fancy, but it works. I've caught a few issues before anyone else
noticed them, which is the whole point.


## The big picture {#the-big-picture}

Here's what the whole setup looks like:

```nil
  ┌─────────────────────────────────────────────────────────┐
  │                    Hetzner CPX21                         │
  │                                                         │
  │  ┌─────────┐    ┌──────────────────────────────────┐    │
  │  │  Gitea   │    │             NGINX                │    │
  │  │  Actions │    │  ┌──────────┐  ┌──────────────┐  │    │
  │  │  Runner  │    │  │ Static   │  │ Reverse      │  │    │
  │  │ (Docker) │    │  │ sites    │  │ proxy to     │  │    │
  │  └────┬─────┘    │  │/var/www/ │  │ Docker svcs  │  │    │
  │       │          │  └──────────┘  └──────────────┘  │    │
  │       │ SSH      │        ▲              │          │    │
  │       │          └────────┼──────────────┼──────────┘    │
  │       │                   │              │               │
  │       ▼                   │              ▼               │
  │  ┌─────────┐         ┌───────┐    ┌───────────┐         │
  │  │  Git    │──build──│ Hugo  │    │  Docker   │         │
  │  │  repos  │         │ sites │    │  services │         │
  │  └─────────┘         └───────┘    └───────────┘         │
  │                                                         │
  │  ┌─────────────┐  ┌──────────┐  ┌────────────┐         │
  │  │   Gitea     │  │ Certbot  │  │  fail2ban  │         │
  │  │ (bare metal)│  │ (SSL)    │  │  + UFW     │         │
  │  └─────────────┘  └──────────┘  └────────────┘         │
  └─────────────────────────────────────────────────────────┘
```


## Conclusion {#conclusion}

The whole philosophy here is **simplicity**. There's no orchestration tool, no
container registry, no deployment platform. It's just:

1.  Push code to Gitea
2.  A workflow SSHes into the server
3.  Git pull + bash script builds the site
4.  NGINX serves it

Could I make this more sophisticated? Sure. Could I use Ansible to manage the
server config, or Kubernetes to orchestrate the containers, or a proper CI/CD
platform with build artifacts and rollbacks? Absolutely. But for a personal
setup that hosts a blog, some side projects, and a handful of services, this is
more than enough.

The setup has been running for years with minimal maintenance. The most time I
spend on it is writing backup scripts for new services and adding NGINX configs
when I deploy something new. Everything else is automated: deployments, SSL
renewals, Docker updates, backups.

If you're thinking about self-hosting your projects, my advice is: **start
simple**. A VPS, NGINX, and a bash script can take you surprisingly far. You
can always add complexity later if you need it, but in my experience, you
probably won't.

If you have questions about any part of this setup, feel free to reach out on
the [Contact](/contact) page. I'm always happy to help people get started with self-hosting.

See you in the next one!
