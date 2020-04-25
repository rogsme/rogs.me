---
title: "De-Google my life - Part 1 of ¯\_(ツ)_/¯: Why? How?"
url: "/2019/03/15/de-google-my-life-part-1-of-_-tu-_-why-how"
date: 2019-03-15T15:59:00-04:00
lastmod: 2020-04-25T12:35:53-03:00
tags : [ "degoogle", "devops" ]
---

Hi everyone! I'm here with my first project of the year. It is almost done, but I think it is time to start documenting everything.

One day I was hanging out with my girlfriend looking for trips to japan online and found myself bombarded by ads that were disturbingly specific. We realized at the moment that Google knows A LOT of us, and we were not happy about that. With my tech knowledge, I knew that there were a lot of alternatives to Google, but first I needed to answer a bigger question:

# Why?

I told my techie friends about the craziness I was trying to accomplish and they all answered in unison: Why?

So I came up with the following list:

*   **Privacy**. The internet is a scary place if you don't know what you are doing. I don't like big corporations knowing everything about me just to sell ads or use my data for whatever they want. I have learned that if something is free it's because [**you** are the product](https://twitter.com/rogergonzalez21/status/1067816233125494784) **EXCEPT** in opensource (thanks to [/u/SnowKissedBerries](https://www.reddit.com/user/SnowKissedBerries) for that clarification.
*   **Security**. I live in a very controlled country (Venezuela). Over here, almost every government agency is looking at you, so using selfhosted alternatives and a VPN is a peace of mind for me and my family.
*   **To learn**. Learning all these skills are going to be good for my career as a Backend / DevOps engineer.
*   **Because I can and it is fun**. Narrowing it all down, I'm doing this because I can. It might be overkill, dumb, unreliable **but** it is really fun. Learning new skills is always a good, fun experience, for me at least.

Perfect! I have all the "Whys" detailed, but how am I going to achieve all of this?

# How?

First of all, I went to the experts (shout out to [/r/selfhosted!](https://www.reddit.com/r/selfhosted)) and read all the interesting topics over there that I could use for my selfhostable endeavours. After 1 week of reading and researching, I came with the following setup:

2 servers, each one with the following stack:

*   **Server 1: Mail server**  
    Mailcow for my SMTP / IMAP email server
*   **Server 2: Everything-else server**  
    Nextcloud for my files, calendar, tasks and contacts  
    Some other apps (?) (More on that for the following posts)

I chose DigitalOcean for the hosting because it is cheap and I have a ton of experience with those servers (I have setup more than 100 servers on their platform).

For VPN I chose [PIA](https://www.privateinternetaccess.com/pages/buy-a-vpn/1218buyavpn?invite=U2FsdGVkX1_cGyzYzdmeUMjhrUAwTzDBCMY-PsW-pXA%2CSawh3XnBRwlSt_9084reCHGX1Kk). The criteria for this decision was that one of my friends borrowed me his account for ~2 weeks and it worked super quick. Sometimes I didn't realize I was connected to the VPN on because the internet was super fast.

# Some self-imposed challenges

I knew this wasn't going to be easy, so of course I added more challenges just because <s>I'm dumb</s>.

*   **Only use open source software**  
    I wasn't going to install more proprietary software on my servers. I wanted free and open source alternatives for my setup.
*   **Only use Docker**  
    I had "Learn docker" in my backlog for too long, so I used this opportunity to learn it the hard way.
*   **Use a cheap but reliable backup solution**  
    One of the parts that scared me about having my own servers was the backups. If one of the servers goes down, almost all of my work goes with it, so I needed to have a reliable but cheap backup solution.

# Conclusion

This is only the first part, but I'm planning on this being a long and very cool project. I hope I didn't bore you to death with all my yapping, I promise my next post will be more entertaining with code, server configurations, and all of that good stuff.

[Click here for part 2](https://blog.rogs.me/2019/03/22/de-google-my-life-part-2-of-_-tu-_-servers-and-emails/)  
[Click here for part 3](https://blog.rogs.me/2019/03/29/de-google-my-life-part-3-of-_-tu-_-nextcloud-collabora/)  
[Click here for part 4](https://blog.rogs.me/2019/11/20/de-google-my-life-part-4-of-_-tu-_-dokuwiki-ghost/)  
[Click here for part 5](https://blog.rogs.me/2019/11/27/de-google-my-life-part-5-of-_-tu-_-backups/)
