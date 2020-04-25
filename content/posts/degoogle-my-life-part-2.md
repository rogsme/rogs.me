---
title: "De-Google my life - Part 2 of ¯\_(ツ)_/¯: Servers and Emails"
url: "/2019/03/22/de-google-my-life-part-2-of-_-tu-_-servers-and-emails"
date: 2019-03-22T21:03:00-04:00
lastmod: 2020-04-25T12:35:53-03:00
tags : [ "degoogle", "devops" ]
---

Hello everyone! Welcome to the second post of this blog series that aims to de-google my life as much as possible. If you haven't read the first one, you should [definitely check it out](https://blog.rogs.me/2019/03/15/de-google-my-life-part-1-of-_-tu-_-why-how/). On this delivery we'll focus more on code and configurations so I promise you it won't be as boring :)

# Servers configuration

As I mentioned on the previous post, I'll be using two servers that are going to be configured almost the same, so I'm going to explain it only one time. In order to host my servers I'm using [DigitalOcean](https://m.do.co/c/cf0ff9cae16a) because I'm very used to their UI, their prices are excelent and they accept Paypal. If you haven't yet, you should check them out.

To start, I'm using their $5 server which at the time of this writing includes:

*   Ubuntu 18.04 64 bits
*   1GB RAM
*   1 CPU
*   1000 GB of monthly transfers

## Installation

On my first SSH to the server I perform basic tasks such as updating and upgrading the server:

    sudo apt update && sudo apt ugrade - y

Then I install some essentials like Ubuntu Common Properties (used to add new repositories using `add-apt-repository`) NGINX, HTOP, GIT and Emacs, the best text editor in this planet <small>vim sucks</small>

    sudo apt install software-properties-common nginx htop git emacs

For SSL certificates I'm going to use Certbot because it is the most simple and usefull tool for it. This one requires some extra steps:

    sudo add-apt-repository ppa:certbot/certbot -y
    sudo apt update
    sudo apt install python-certbot-nginx -y

By default DigitalOcean servers have no `swap`, so I'll add it by pasting some [DigitalOcean boilerplate](https://www.digitalocean.com/community/tutorials/how-to-add-swap-space-on-ubuntu-18-04) on to the terminal:

    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    sudo cp /etc/fstab /etc/fstab.bak
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    sudo sysctl vm.swappiness=10
    sudo sysctl vm.vfs_cache_pressure=50
    sudo echo "vm.swappiness=10" >> /etc/sysctl.conf
    sudo echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf

This adds 2GB of `swap`

Then I set up my firewall with UFW:

    sudo ufw allow 22 #SSH
    sudo ufw allow 80 #HTTP
    sudo ufw allow 443 #HTTPS
    sudo ufw allow 25 #IMAP 
    sudo ufw allow 143 #IMAP 
    sudo ufw allow 993 #IMAPS
    sudo ufw allow 110 #POP3 
    sudo ufw allow 995 #POP3S
    sudo ufw allow 587 #SMTP
    sudo ufw allow 465 #SMTPS
    sudo ufw allow 4190 #Manage Sieve

    sudo ufw enable

Finally, I install `docker` and `docker-compose`, which are going to be the main software running on both servers.

    # Docker
    curl -sSL https://get.docker.com/ | CHANNEL=stable sh
    systemctl enable docker.service
    systemctl start docker.service

    # Docker compose
    curl -L https://github.com/docker/compose/releases/download/$(curl -Ls https://www.servercow.de/docker-compose/latest.php)/docker-compose-$(uname -s)-$(uname -m) > /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

Now that everything is done, we can continue configuring the first server!

# Server #1: Mailcow

For my email I chose Mailcow. Why?

*   It checks all of my "challenges list" items from last week's post ([open source and dockerized](https://github.com/mailcow/mailcow-dockerized)).
*   The documentation is fantastic, explaining each detail one by one.
*   It has a huge community behind it.

## Installation & Setup

Installation was simple, first I followed the instructions on their [official documentation](https://mailcow.github.io/mailcow-dockerized-docs/i_u_m_install/)

    cd /opt
    git clone https://github.com/mailcow/mailcow-dockerized
    cd mailcow-dockerized
    ./generate_config.sh
    # The process will ask you for your FQDN to automatically configure NGINX.
    # Mine is mail.rogs.me, but yours might be whatever you want

I pointed my subdomain (an A record in Cloudflare) and I finally opened my browser and visited [https://mail.rogs.me](https://mail.rogs.me) and there it was, beautiful as I was expecting.

![Captura-de-pantalla-de-2019-03-20-17-20-49](/Captura-de-pantalla-de-2019-03-20-17-20-49.png)  
<small>What a beautiful cow</small>

After that I just followed the documentation to [configure their Let's Encrypt docker image](https://mailcow.github.io/mailcow-dockerized-docs/firststeps-ssl/), [added more records on my DNS](https://mailcow.github.io/mailcow-dockerized-docs/prerequisite-dns/) and tested a lot with [https://www.mail-tester.com/](https://www.mail-tester.com/) until I got a good score

![Captura-de-pantalla-de-2019-03-20-17-25-14](/Captura-de-pantalla-de-2019-03-20-17-25-14.png)  
<small>My actual score. Everything is perfect in self-hosted-mail-land</small>

I know that sometimes that score doesn't mean much, but at least is nice to know my email is completely configured.

## Backups

Since I keep all my emails local, I didn't want a huge backup solution for this server, so I went with the DigitalOcean backup, which costs $1 per month. Cheap, reliable and it just works.

## Edit Nov 23-26 2019

As of now, I'm not using PIA anymore because [they where bought by Kape Technologies, which is known for sending malware through their software and for being scummy in general.](https://www.reddit.com/r/homelab/comments/e05ce4/psa_piaprivateinternetaccess_has_been_bought_by/). I'm now using [Mullvad](https://mullvad.net/), [which really focuses on security](https://mullvad.net/es/help/no-logging-data-policy/). If you were using PIA, I really recommend you change providers.

# Conclusion

With all of this my first server was done, but it was also the easiest. This one was a pretty straightforward installation with nothing fancy going on: No backups, no NGINX configuration, nothing much. On the good side, I had my email working really quick and it was a very satisfying and rewarding experience. This is when the "selfhost everything" bug bit me and this project really started ramp up in speed. On the next post we will talk about the second server, which includes fun stuff as [Nextcloud](https://nextcloud.com/), [Collabora](https://www.collaboraoffice.com/), [Dokuwiki](https://www.dokuwiki.org/dokuwiki) and many more.

Stay tuned!

[Click here for part 3](https://blog.rogs.me/2019/03/29/de-google-my-life-part-3-of-_-tu-_-nextcloud-collabora/)  
[Click here for part 4](https://blog.rogs.me/2019/11/20/de-google-my-life-part-4-of-_-tu-_-dokuwiki-ghost/)  
[Click here for part 5](https://blog.rogs.me/2019/11/27/de-google-my-life-part-5-of-_-tu-_-backups/)
