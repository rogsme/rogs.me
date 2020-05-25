---
title: "De-Google my blog - How to blog in 2020 without Google"
date: 2020-05-20T10:41:56-03:00
lastmod: 2020-05-25T10:41:56-03:00
tags : [ "degoogle", "devops", "meta", "hugo", ]
---

Hi everyone!

Right now I have Google almost completely out of my life, but some of the top commentaries of my 
posts in [/r/degoogle](https://reddit.com/r/degoogle) and [/r/selfhosted](https://reddit.com/r/selfhosted) were "Your blog still uses google for resources lol", 
so I needed to change that.

In my old blog, the features that used Google where:
  1) Disquss comments
  2) The Ghost theme

**Before we begin, I want to let you know that all these fixes have been applied, so you are currently 
experiencing the final result.**

# Fixing comments

I was using disquss to handle comments, since it is what everyone recommends. I checked the network 
resources on my site and found something horrible: A bunch of random calls to a bunch of external 
addresses, not just Google. Since I care about my reader's privacy, disquss had to go. Someone in 
/r/degoogle suggested "Commento", and it looked like it was exactly what I needed: A free and opensource, 
self-hosted alternative to disquss, and it also had an official docker release!

According to their [documentation](https://docs.commento.io/installation/self-hosting/on-your-server/docker.html):
```yaml
version: '3'

services:
  server:
    image: registry.gitlab.com/commento/commento
    restart: always
    ports:
      - 5000:8080
    environment:
      COMMENTO_ORIGIN: https://commento.rogs.me
      COMMENTO_PORT: 8080
      COMMENTO_POSTGRES: postgres://postgres:mysupersecurepassword@db:5432/commento?sslmode=disable
      COMMENTO_SMTP_HOST: my-mail-host.com
      COMMENTO_SMTP_PORT: 587
      COMMENTO_SMTP_USERNAME: mysmtpusername@mail.com
      COMMENTO_SMTP_PASSWORD: mysmtppassword
      COMMENTO_SMTP_FROM_ADDRESS: mysmtpfromaddress@mail.com
    depends_on:
      - db
  db:
    image: postgres
    restart: always
    environment:
      POSTGRES_DB: commento
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: mysupersecurepassword
    volumes:
      - postgres_data_volume:/var/lib/postgresql/data

volumes:
  postgres_data_volume:
```

I created an NGINX reverse proxy for port 5000 and that was it! Commento was up and running without much 
issue.

![2020-05-20-105918](/2020-05-20-105918.png)

Then, I configured my blog and added the simple universal snippet on my blog posts template pages:

```html
<script defer src="https://commento.rogs.me/js/commento.js"></script>
<div id="commento"></div>
```

# Is that it?

Yes, as easy as that. Comments were up and running in less than 20 mins, with no random external resources. 
*Sweet!*

![2020-05-20-110914](/2020-05-20-110914.png)

I could even import my old disquss comments in Commento! I was a bit sad to lose them, but they were 
just fine! 

![2020-05-21-121039](/2020-05-21-121039.png)

So now that my comments were ready, I could move forward to fixing Ghost

# The Ghost theme

This was quite simple. I forked the git repo for my blog theme and began removing everything regarding 
Google fonts. You can check the final results here: https://git.rogs.me/me/blog.rogs.me-ghost-theme

## But that's not entirely it!

My ghost blog was big and bloated, and I wasn't really enjoying it anymore, so I wanted to move it to something more 
static, fast, and reliable, so I moved everything to Hugo!

## What is [Hugo](https://gohugo.io/)?

According to their website:
> Hugo is one of the most popular open-source static site generators. With its amazing speed and flexibility, Hugo makes building websites fun again.

So it is a static site generator, that uses .md files for content.

## Why did I chose Hugo? 

- Hugo needs no dependencies. I just had to do `sudo pacman -S hugo` and no further dependencies were 
needed
- Hugo doesn't need a database since it is *static*. That means that my blog could load *A LOT* faster 
(and it does!)
- Hugo uses a lot less resources than Ghost. For Ghost I needed a docker running with a database, with Hugo
I just serve the files directly with NGINX, just like a regular plain HTML website.

## And that is what you are seeing right now!

This blog is 100% running with Hugo. Migration was super easy, since Ghost also uses Markdown files. I just needed to match the URLs so old posts wouldn't break and comments worked like they did before. I chose a simple template, migrated, deployed to my server and that was it! 

You can check the code for my blog here: https://git.rogs.me/me/blog.rogs.me

My theme: https://themes.gohugo.io/hugo-theme-m10c/

I was pretty satisfied with the migration and how things were coming along.

# One extra thing: [Matomo Analytics](https://matomo.org/)

For Analytics, of course I wasn't going to use Google Analytics, so Matomo was an easy choice. Here is my 
configuration:

```yaml
version: "3"

services:
  app:
    image: matomo:latest
    restart: always
    links:
      - db
    volumes:
      - "./config:/var/www/html/config:rw"
      - "./logs:/var/www/html/logs"
    ports:
      - "9000:80"

  db:
    image: mariadb:latest
    restart: always
    volumes:
      - "./mysql/runtime2:/var/lib/mysql"
    environment:
      - "MYSQL_DATABASE=matomo"
      - "MYSQL_ROOT_PASSWORD=mysupersecurepassword"
      - "MYSQL_USER=matomo"
      - "MYSQL_PASSWORD=anothersupersecurepassword"
```
Again, another reverse proxy for port `9000` and Matomo was up and running!

![2020-05-20-114330](/2020-05-20-114330.png)
![2020-05-21-121645](/2020-05-21-121645.png)
*My blog stats in Matomo*

Matomo has everything I need, while respecting the users' privacy. If you haven't used it before, you should definitely check it out! I have used Google Analytics before, but Matomo seems more powerful to me.

# Conclusion

It isn't easy to run a website outside of Google, but with a little dedication it is possible. With tools 
like Matomo and Commento you can easily respect your user's privacy and get away from Google's "big 
brotherness".

If you have any further suggestions, I'm always looking for more things to self-host and separate
from big corporations.

Until next time!
