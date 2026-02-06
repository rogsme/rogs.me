+++
title = "Introducing: YAMS (Yet Another Media Server)!"
author = ["Roger Gonzalez"]
date = 2023-01-20T09:57:48-03:00
lastmod = 2026-02-05T21:30:22-03:00
tags = ["programming", "docker", "dockercompose", "announcements", "opensource"]
draft = false
+++

Hello internet 😎

I'm here with a **big** announcement: I have created a bash script that installs my entire media server,
fast and easy 🎉

{{< figure src="https://yams.media/install-yams.gif" >}}


## TL;DR {#tl-dr}

I've created YAMS. A full media server that allows you to download and categorize your shows/movies.

Go to YAMS's website here: <http://yams.media> or check it on Gitlab here: <https://gitlab.com/rogs/yams>.


## A little history {#a-little-history}

When I first set up my media server, it took me ~2 weeks to install, configure and understand how it's
supposed to work: Linking Sonarr, Radarr, Jackett together, choosing a good BitTorrent downloader,
understanding all the moving pieces, choosing Emby, etc. My plan with YAMS is to make it easier
for noobs (and lazy people like me) to set up their media servers super easily.

I have been working on YAMS for ~2 weeks. The docker-compose file has existed for almost 2 years but
without any configuration instructions. Basically, you had to do everything manually, and if you didn't
have any experience with docker, docker-compose, or any of the services included, it was very cumbersome
to configure and understand how everything worked together.

So basically, I'm encapsulating my experience for anyone that wants to use it. If you don't like it, at
least you might learn something from my experience, YAMS's [docker-compose file](https://git.rogs.me/yams.git/tree/docker-compose.example.yaml) or its [configuration
tutorial](https://yams.media/config/).

This is my first (and hopefully not last!) piece of open source software. I know it's just a [bash script](https://git.rogs.me/yams.git/tree/install.sh)
that sets up a [docker-compose](https://git.rogs.me/yams.git/tree/docker-compose.example.yaml) file, but seeing how my friends are using it and giving me feedback is
exciting and addictive!


## Why? {#why}

In 2019 I wanted a setup that my non-technical girlfriend could use without any problems, so I started
designing my media server using multiple open source projects and running them on top of docker.

Today I would like to say it works very well 😎 And most importantly, I accomplished my goal: My
girlfriend uses it regularly and I even was able to expand it to my mother, who lives 5000kms from me.

But then, my friends saw my setup...

On June 2022 I had a small "party" with my work friends at my apartment, and all of them were very
impressed with my home server setup:

-   "Sonarr" to index shows.
-   "Radarr" to index movies.
-   "qBittorrent" to download torrents.
-   "Emby" to serve the server.

They kept telling me to create a tutorial, or just teach them how to set one up themselves.

I tried to explain the full setup to one of them, but explaining how everything connected and worked
together was a big pain. That is what led me to create this script and configuration tutorial, so anyone
regardless of their tech background and knowledge could start a basic media server.

So basically, my friends pushed me to build this script and documentation, so they (and now anyone!)
could build it on their own home servers.


## Ok, sounds cool. What did you do then? {#ok-sounds-cool-dot-what-did-you-do-then}

[A bash script](https://git.rogs.me/yams.git/tree/install.sh) that asks basic questions to the user and sets up the ultimate media server, with
[configuration instructions included](https://yams.media/config/)! (That's the part I really **REALLY** enjoyed!)


## What's included with YAMS? {#what-s-included-with-yams}

This script installs the following software:

-   [Sonarr](https://sonarr.tv/)
-   [Radarr](https://radarr.video/)
-   [Emby](https://emby.media/)
-   [qBittorrent](https://www.qbittorrent.org/)
-   [Bazarr](https://www.bazarr.media/)
-   [Jackett](https://github.com/Jackett/Jackett)
-   [gluetun](https://github.com/qdm12/gluetun)

This combination allows you to create a fully functional media server that is going to download,
categorize, subtitle, and serve your favorite shows and movies.


## Features {#features}

In no particular order:

-   **Automatic shows/movies download**: Just add your shows and movies to the watch list and it should
    automatically download the files when they are available.
-   **Automatic classification and organization**: Your media files should be completely organized by default.
-   **Automatic subtitles download**: Self-explanatory. Your media server should automatically download
    subtitles in the languages you choose if they are available.
-   **Support for Web, Android, iOS, Android TV, and whatever that can support Emby**: Since we are
    using Emby, you should be able to watch your favorite media almost anywhere.


## Conclusion {#conclusion}

You can go to YAMS's website here: <https://yams.media>.

I'm **very** proud of how YAMS is turning out! If you end up using it on your server, I just want to tell
you **THANK YOU** 🙇 from the bottom of my heart. You are ****AWESOME!****

Feedback is GREATLY appreciated (the VPN was added from the feedback!). I'm here to support YAMS for the
long run, so I would like suggestions on how to improve the setup/website/configuration steps.

You can always submit [issues](https://gitlab.com/rogs/yams/-/issues/new) on Gitlab if you find any problems, or you can [contact](/contact) me directly (email
preferred!).
