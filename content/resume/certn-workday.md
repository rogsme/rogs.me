+++
title = "Certn - Workday Integration"
author = ["Roger Gonzalez"]
date = 2020-01-14
lastmod = 2023-01-14T14:18:46-03:00
draft = false
weight = 1001
+++

## About the project {#about-the-project}

[Certn](https://certn.co/) is an app that wants to ease the process of background checks for criminal records, education,
employment verification, credit reports, etc.

On Workday I had to work with their client, [Loblaws](https://www.loblaws.ca/), to integrate Certn with their [Workday](https://www.workday.com/) instance. I
quickly realized that their Workday implementation was not standard, so I had to modify multiple
open-source SOAP projects (including [python-zeep](https://github.com/mvantellingen/python-zeep)) to work with their setup.

We had 6 months to finish the project and I was able to finish it in only 3 months, which allowed us to
make changes, improve the security and work on client changes that came up almost at the end of the
project.

This project led to Certn closing a multi-million dollars a year contract with Loblaws.


## Tech Stack {#tech-stack}

-   Python
-   Django
-   Django REST Framework
-   Celery
-   PostgreSQL
-   Docker-docker/compose
-   SOAP
-   OpenSource development
-   Jenkins


## What did I work on? {#what-did-i-work-on}

-   Worked with Loblaws to integrate Certn with their Workday integration.
-   Refactored an old implementation they had for Workday, which didn't work for the latest Workday
    implementation.
-   Developed multiple jobs to pull data from Workday, convert it to what Certn needs and then process it
    on their main application.
