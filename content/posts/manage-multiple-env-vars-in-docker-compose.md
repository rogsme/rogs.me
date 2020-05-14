---
title: "How I manage multiple development environments in my Django workflow using Docker compose"
date: 2020-05-13T11:36:48-03:00
lastmod: 2020-05-13T11:36:48-03:00
tags : [ "docker", "programming", "django" ]
---

Hi everyone!

Last week I was searching how to manage multiple development environments with the same docker-compose configuration for my Django workflow. I needed to manage a development and a production environment, so this is what I did. 

Some descriptions on my data:

1) I had around 20 env vars, but some of them where shared among environments.
2) I wanted to do it with as little impact as possible.

# First, docker-compose help command

The first thing I did was run a simple `docker-compose --help`, and it returned this:

```bash
Define and run multi-container applications with Docker.

Usage:
  docker-compose [-f <arg>...] [options] [COMMAND] [ARGS...]
  docker-compose -h|--help

Options:
  -f, --file FILE             Specify an alternate compose file
                              (default: docker-compose.yml)
# more not necessary stuff
  --env-file PATH             Specify an alternate environment file
```

I went with the `-f` flag, because I also wanted to run some docker images for development. By using the `-f` flag I could create a base compose file with the shared env vars (docker-compose.yml) and another one for each of the environments (prod.yml and dev.yml)

So I went to town. I kept the shared variables inside `docker-compose.yml` and added the specific variables and configuration to `prod.yml` and `dev.yml`

`docker-compose.yml`:
```yaml
version: "3"

services:
  app:
    build:
      context: .
    ports:
      - "8000:8000"
    volumes:
      - ./app:/app
    command: >
      sh -c "python manage.py migrate && python manage.py runserver 0.0.0.0:8000"
    environment:
      - myvar1=myvar1
      - myvar2=myvar2
      ...
      - myvarx=myvarx
```

Since I'm going to connect to a remote RDS and a remote Redis, in my `prod.yml`, I don't need to define a Postgres or Redis image:
```yaml

version: "3"
services:
  app:
    environment:
      # DB connections
      - DB_HOST=my-host
      - DB_NAME=db-name
      - DB_USER=db-user
      - DB_PASS=mysupersecurepassword
      ...
```

For `dev.yml` I added the Postgres database image and Redis image:
```yaml
version: "3"

services:
  app:
    depends_on:
      - db
      - redis
    environment:
      # Basics
      - DEBUG=True
      # DB connections
      - DB_HOST=db
      - DB_NAME=app
      - DB_USER=postgres
      - DB_PASS=supersecretpassword
      ...
  db:
    image: postgres:10-alpine
    environment:
      - POSTGRES_DB=app
      - POSRGRES_USER=postgres
      - POSTGRES_PASSWORD=supersecretpassword
    links:
      - redis:redis

  redis:
    image: redis:5.0.7
    expose:
      - "6379"
```

And to run it between environments, all I have to do is:

```bash
# For production
docker-compose -f docker-compose.yml -f prod.yml up 

# For development
docker-compose -f docker-compose.yml -f dev.yml up 
```

That's it! I have multiple `docker-compose` files for all my environments, but I could go even further.

# Improving the solution

## Improving the base docker-compose.yml file

I liked the way it looked, but I knew I could go deeper. A bunch of vars inside the base `docker-compose.yml` looked weird, and made the file a little unreadable. So again, I went to the `docker-compose` documentation and found what I needed: [env files in docker-compose](https://docs.docker.com/compose/environment-variables/#the-env-file).

So I created a file called `globals.env`, and moved all the global env vars to that file:

```yaml
myvar1=myvar1
mivar2=myvar2
...
```
And on the `docker-compose.yml` file I called the `globals.env` file:

```yaml
  app:
    env_file: globals.env
```

This is the final result:

```yaml
version: "3"

services:
  app:
    build:
      context: .
    ports:
      - "8000:8000"
    volumes:
      - ./app:/app
    command: >
      sh -c "python manage.py migrate && python manage.py runserver 0.0.0.0:8000"
    env_file: globals.env
```

## Improving the running command

As I mentioned before, I wanted as little impact as possible, and `docker-compose -f docker-compose.yml -f envfile.yml up` was a bit long for me. So I created a couple of bash files to ease the ingestion of `docker-compose` files:

`prod`: 
```bash
#!/usr/bin/env bash
# Run django as production
docker-compose -f docker-compose.yml -f prod.yml "$@"
```

`dev`:
```bash
#!/usr/bin/env bash
# Run django as development
docker-compose -f docker-compose.yml -f dev.yml "$@"
```

The `"$@"` means "Append all extra arguments here", so if I ran the `dev` command with the `up -d` arguments, the full command would be `docker-compose -f docker-compose.yml -f development.yml up -d`, so it is exactly what I wanted

A quick permissions management:
```bash
chmod +x prod dev 
```

And now I could run my environments as:
```bash
./dev up
./prod up
```

# All good?

I was satisfied with this solution. I could run both environments wherever I want with only one command instead of moving env vars all over the place. I could go even further by moving the environment variables of each file to its own `.env` file, but I don't think that's needed for the time being. At least I like to know that I can do that down the road if it is necessary
