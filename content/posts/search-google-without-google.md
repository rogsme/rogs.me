---
title: "How to search Google without using Google, the self-hosted way"
date: 2020-06-22T10:07:12-03:00
lastmod: 2020-06-22T10:07:12-03:00
tags : [ "degoogle", "selfhosted", "devops" ]
---

Hello everyone! 

Last week I was talking with a friend and he was complaining about how Google knows everything about us,
so I took the chance to recommend some degoogled alternatives: I sent him my blog, recommended DuckDuckGo,
Nextcloud, Protonmail, etc. He really liked my suggestions and promised to try DuckDuckGo. A couple of 
days later he came to me a little defeated, because he didn't like the search results on DuckDuckGo and 
felt bad going back to Google.

So that got me thinking: **Are there some degoogled search engines that use Google as the backend but 
respect our privacy?**

So I went looking and found a couple of really interesting options.

# [Startpage.com](https://startpage.com/)

According to their [Wikipedia](https://en.wikipedia.org/wiki/Startpage.com):

> Startpage is a web search engine that highlights privacy as its distinguishing feature. Previously, it 
> was known as the metasearch engine Ixquick

> ...

> On 7 July 2009, Ixquick launched Startpage.com to offer its service at a URL that is both easier to 
> remember and spell. In contrast to Ixquick.eu, **Startpage.com fetches results from the Google search 
> engine**. This is done **without saving user IP addresses or giving any personal user information to 
> Google's servers**.

and their own [website](https://startpage.com/):

> You can’t beat Google when it comes to online search. So we’re paying them to use their brilliant
> search results in order to remove all trackers and logs. The result: The world’s best and most private
> search engine. Only now you can search without ads following you around, recommending products you’ve
> already bought. And no more data mining by companies with dubious intentions. We want you to dance like
> nobody’s watching and search like nobody’s watching.

![2020-06-18-110253](/2020-06-18-110253.png)

So this was a good solution for my friend: He could still keep his Google search results while using a
search engine that respects his privacy

But that wasn't enough for me. You know I love self-hosting, so I wanted to find a solution I could run
inside my own server because that's the only way I can be 100% sure that my searches are private and no
logs are kept on my searches, So I went to my second option: Searx

# [Searx](https://searx.me/)

According to their [Wikipedia](https://en.wikipedia.org/wiki/Searx)

> searx (/sɜːrks/) is a free metasearch engine, available under the GNU Affero General Public License
> version 3, with the aim of protecting the privacy of its users. To this end, searx does not share
> users' IP addresses or search history with the search engines from which it gathers results. Tracking
> cookies served by the search engines are blocked, preventing user-profiling-based results modification.
> By default, searx queries are submitted via HTTP POST, to prevent users' query keywords from appearing
> in webserver logs. searx was inspired by the Seeks project, though it does not implement Seeks'
> peer-to-peer user-sourced results ranking.

> ...

> Any user **may run their own instance of searx, which can be done to maximize privacy**, to avoid
> congestion on public instances, to preserve customized settings even if browser cookies are cleared, to
> allow auditing of the source code being run, etc.

And that's what I wanted: To host my own Searx instance on my server. And nicely enough, they supported
[Docker out of the box](https://github.com/asciimoo/searx#installation) :) 

So I created my own `docker-compose` based on their `docker-compose`:

```yml
version: '3.7'

services:

  filtron:
    container_name: filtron
    image: dalf/filtron
    restart: always
    ports:
      - 4040:4040
      - 4041:4041
    command: -listen 0.0.0.0:4040 -api 0.0.0.0:4041 -target 0.0.0.0:8082
    volumes:
      - ./rules.json:/etc/filtron/rules.json:rw
    read_only: true
    cap_drop:
      - ALL
    network_mode: host

  searx:
    container_name: searx
    image: searx/searx:latest
    restart: always
    command: -f
    volumes:
      - ./searx:/etc/searx:rw
    environment:
      - BIND_ADDRESS=0.0.0.0:8082
      - BASE_URL=https://myurl.com/
      - MORTY_URL=https://myurl.com/
      - MORTY_KEY=mysupersecretkey
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
      - DAC_OVERRIDE
    network_mode: host

  morty:
    container_name: morty
    image: dalf/morty
    restart: always
    ports:
      - 3000:3000
    command: -listen 0.0.0.0:3000 -timeout 6 -ipv6
    environment:
      - MORTY_KEY=mysupersecretkey
    logging:
      driver: none
    read_only: true
    cap_drop:
      - ALL
    network_mode: host

  searx-checker:
    container_name: searx-checker
    image: searx/searx-checker
    restart: always
    command: -cron -o html/data/status.json http://localhost:8082
    volumes:
      - searx-checker:/usr/local/searx-checker/html/data:rw
    network_mode: host

volumes:
  searx-checker:
```

And that was it! I had my own Searx instance, that uses Google, Bing, Yahoo, DuckDuckGo and many other
sources to search around the web. 

![2020-06-18-124302](/2020-06-18-124302.png)
![2020-06-18-124707](/2020-06-18-124707.png)

## Don't want to host your own instance? Use a public one!

Searx has a lot of public instances on their website, in case you don't want to self-host your instance
but still want all the benefits of using Searx. You can check the list here: https://searx.space/

# Conclusion

I really like DuckDuckGo. I think it is a very good project that takes privacy to the hands of
non-technical people, but I also know that "You can’t beat Google when it comes to online search"[^1].
It is definitely possible to get good search results using privacy oriented alternatives, and in the end,
it is a very cool and rewarding experience.

I seriously recommend you to use https://startpage.com, one of the instances listed in
https://searx.space, or better yet, if you have the knowledge and the resources, to self-host your own
Searx instance and start searching the web without a big corporation watching every move you make.

Stay private.

[^1]: Taken from the Startpage website
