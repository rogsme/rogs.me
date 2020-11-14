+++
title = "Volition"
author = ["Roger Gonzalez"]
date = 2020-07-01
lastmod = 2020-11-14T14:02:31-03:00
draft = false
weight = 1003
+++

## About the project {#about-the-project}

Volition is an app that wants to be the top selling place for a certain kind of
product. In order to achieve that, we had to develop a series of crawlers for
different vendors, in order to get all the data so the storefront could be
created .


## Tech Stack {#tech-stack}

-   JavaScript
-   TypeScript
-   NodeJS
-   PuppeteerJS
-   Docker/docker-compose
-   PostgreSQL
-   Google Cloud
-   Kubernetes
-   Bash
-   ELK (ElasticSearch, LogStash, Kibana)


## What did I work on? {#what-did-i-work-on}

-   Team lead
-   Moved the entire project to docker and docker-compose. Before it, the
    development environment has pretty tricky to setup.
-   Improved the old code, introducing standards with esLint and smoke tests.
-   Configured a VPN and an Ubuntu VNC session in docker to help with the proxy
    and the non-headless browser.
-   Created new crawlers for the new vendors.
-   Configured the new Kibana dashboard.
-   Created a gatekeeper to check the crawlers status before going out to the
    internet.
-   Monitored and ran many crawlers.
