+++
title = "Certn - ADA DINER (Adverse Data Aggregator Data INgestER)"
author = ["Roger Gonzalez"]
date = 2020-11-01
lastmod = 2023-01-02T18:43:13-03:00
draft = false
weight = 1001
+++

## About the project {#about-the-project}

[Certn](https://certn.co) is an app that wants to ease the process of background checks for criminal
records, education, employment verification, credit reports, etc. On
ADA DINER we are working on an app that triggers crawls on demand, to check
criminal records for a certain person.


## Tech Stack {#tech-stack}

-   Python
-   Django
-   Django REST Framework
-   Celery
-   PostgreSQL
-   Docker-docker/compose
-   Swagger
-   Github Actions
-   Scrapy/Scrapyd
-   Jenkins


## What did I work on? {#what-did-i-work-on}

-   Dockerized the old app so the development could be more streamlined
-   Refactor of old Django code to DRF
-   Developed multiple scrapers for multiple police sites in Canada and Interpol
-   Created the Github Actions and Jenkins CI configurations
