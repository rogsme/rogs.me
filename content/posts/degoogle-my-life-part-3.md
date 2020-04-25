---
title: "De-Google my life - Part 3 of ¯\_(ツ)_/¯: Nextcloud & Collabora"
url: "/2019/03/29/de-google-my-life-part-3-of-_-tu-_-nextcloud-collabora"
date: 2019-03-28T19:07:00-04:00
lastmod: 2020-04-25T12:35:53-03:00
tags : [ "degoogle", "devops" ]
---

<div class="kg-card-markdown">

Hello everyone! Welcome to the third post of my blogseries "De-Google my life". If you haven't read the other ones you definitely should! ([Part 1](https://blog.rogs.me/2019/03/15/de-google-my-life-part-1-of-_-tu-_-why-how/), [Part 2](https://blog.rogs.me/2019/03/22/de-google-my-life-part-2-of-_-tu-_-servers-and-emails/)). Today we are moving forward with one of the most important apps I'm running on my servers: [Nextcloud](https://nextcloud.com/). A big part of my Google usage was Google Drive (and all it's derivate apps). With Nextcloud I was looking to replace:

*   Docs
*   Drive
*   Photos
*   Contacts
*   Calendar
*   Notes
*   Tasks
*   More (?)

I also wanted some new features, like connecting to a S3 bucket directly from my server and have a web interface to interact with it.

The first step is to set up the server. I'm not going to explain that again, but if you want to read more about that, I explain it a bit better on the [second post](https://blog.rogs.me/2019/03/22/de-google-my-life-part-2-of-_-tu-_-servers-and-emails/)

# Nextcloud

## Installation

For my Nextcloud installation I went straight to the [official docker documentation](https://github.com/nextcloud/docker) and extracted this docker compose:

    version: '2'

    volumes:
      nextcloud:
      db:

    services:
      db:
        image: mariadb
        command: --transaction-isolation=READ-COMMITTED --binlog-format=ROW
        restart: always
        volumes:
          - db:/var/lib/mysql
        environment:
          - MYSQL_ROOT_PASSWORD=my_super_secure_root_password
          - MYSQL_PASSWORD=my_super_secure_password
          - MYSQL_DATABASE=nextcloud
          - MYSQL_USER=nextcloud

      app:
        image: nextcloud
        ports:
          - 8080:80
        links:
          - db
        volumes:
          - nextcloud:/var/www/html
        restart: always

**Some mistakes were made**  
I forgot to mount the volumes and Docker automatically mounted them in /var/lib/docker/volumes/. This was a small problem I haven't solved yet because it hasn't bringed any serious issues. If someone knows if this is going to be problematic in the long run, please let me know. I didn't wanted to fix this just for the posts, I'm writing about my experience and of course it wasn't perfect.

I created the route `/opt/nextcloud` to keep my docker-compose file and finally ran:

    docker-compose pull
    docker-compose up -d

It was that simple! The app was running on port 8080! But that is not what I wanted. I wanted it running on port 80 and 443\. For that I used a reverse proxy with NGINX and Let's Encrypt

## NGINX configuration

Configuring NGINX is dead simple. Here is my configuration

`/etc/nginx/sites-available/nextcloud:`

    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name myclouddomain.com;
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl;
        server_name myclouddomain.com;
        add_header Strict-Transport-Security "max-age=15552000; includeSubDomains" always;

        ssl on;
        ssl_certificate /etc/letsencrypt/live/myclouddomain.com/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/myclouddomain.com/privkey.pem;

        location / {
            proxy_pass http://127.0.0.1:8080;
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forward-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_redirect off;
            proxy_read_timeout 5m;
        }

        location = /.well-known/carddav {
          return 301 $scheme://$host/remote.php/dav;
        }
        location = /.well-known/caldav {
          return 301 $scheme://$host/remote.php/dav;
        }
       # Set the client_max_body_size to 1000M so NGINX doesn't cut uploads
        client_max_body_size 1000M; 
    }

Then I created a soft link from the configuration file to the "sites enabled" folder:

    ln -s /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled

and that was it!

In this configuration you will see that I'm already referencing the SSL certificates even though they don't exist yet. We are going to create them on the next step.

## Let's Encrypt configuration

To generate the SSL certificates first you need to point your domain/subdomain to your server. Every DNS manager is different, so you will have to figure that out. The command I will use throught this blog series to create certificates is the following:

    sudo -H certbot certonly --nginx-d mydomain.com

The first time you run Let's Encrypt, you have to configure some stuff. They will ask you for your email and some questions. Input that information and finish the process.

To enable automatic SSL certificates renovation, create a new cron job (`crontab -e`) with the following information:

    0 3 * * * certbot renew -q

This will run every morning at 3AM and check if any of your domains needs to be renewed. If they do, it will renew it.

At the end, you should be able to visit [https://myclouddomain.com](https://myclouddomain.com) and be greeted with a nice NextCloud screen:

![Captura-de-pantalla-de-2019-03-28-10-51-04](/Captura-de-pantalla-de-2019-03-28-10-51-04.png)  
<small>Beautiful yet frustrating blue screen</small>

## Nextcloud configuration

In this part I got super stuck. I had everything up and running, but I couldn't get my database to connect. It was SUPER FRUSTRATING. This is why I had failed:

Since in my docker-compose file I called the MariaDB docker `db`, the database host was not `localhost` but `db`.

Once that was fixed, Nextcloud was 100% ready to be used!

![Captura-de-pantalla-de-2019-03-28-16-19-13](/Captura-de-pantalla-de-2019-03-28-16-19-13.png)

After that I went straight to "Settings/Basic settings" and noticed that my background jobs were set to "Ajax". That's not good, because if I don't open the site, the tasks will never run. I changed it to "Cron" and created a new cron on my server with the following information:

    */15 * * * * /usr/bin/docker exec --user www-data nextcloud_app_1 php cron.php

This will run the Nextcloud cronjob in the docker machine every 15 mins.

Then, in "Settings/Overview" I noticed a bunch of errors on the "Security & setup warnings" part. Those were very easy to fix, but since all installations aren't the same I won't go deep into this. [DuckDuckGo](https://duckduckgo.com/) is your friend.

## Extra stuff

The Nextcloud apps store is filled with some interesting applications. The ones I have installed are:

*   [Contacts](https://apps.nextcloud.com/apps/contacts)
*   [Calendar](https://apps.nextcloud.com/apps/calendar)
*   [Notes](https://apps.nextcloud.com/apps/notes)
*   [Tasks](https://apps.nextcloud.com/apps/tasks)
*   [Markdown editor](https://apps.nextcloud.com/apps/files_markdown)
*   [PhoneTrack](https://apps.nextcloud.com/apps/phonetrack)

But you can add as many as you want! You can check them out [here](https://apps.nextcloud.com/)

# Collabora

Now that NextCloud was up and running, I needed my "Google Docs" part. Enter Collabora!

## Installation

If you don't know what it is, Collabora is like Google Docs / Sheets / Slides but free and open source. You can check more about the project [here](https://nextcloud.com/collaboraonline/)

This was a very easy installation. I ran it directly with docker:

    docker run -t -d -p 127.0.0.1:9980:9980 -e 'domain=mynextclouddomain.com' --restart always --cap-add MKNOD collabora/code

Created a new NGINX reverse proxy

`/etc/nginx/sites-available/collabora`:

    # Taken from https://icewind.nl/entry/collabora-online/
    server {
        listen       443 ssl;
        server_name  office.mydomain.com;

        ssl_certificate /etc/letsencrypt/live/office.mydomain.com/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/office.mydomain.com/privkey.pem;

        # static files
        location ^~ /loleaflet {
            proxy_pass https://localhost:9980;
            proxy_set_header Host $http_host;
        }

        # WOPI discovery URL
        location ^~ /hosting/discovery {
            proxy_pass https://localhost:9980;
            proxy_set_header Host $http_host;
        }

       # main websocket
       location ~ ^/lool/(.*)/ws$ {
           proxy_pass https://localhost:9980;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection "Upgrade";
           proxy_set_header Host $http_host;
           proxy_read_timeout 36000s;
       }

       # download, presentation and image upload
       location ~ ^/lool {
           proxy_pass https://localhost:9980;
           proxy_set_header Host $http_host;
       }

       # Admin Console websocket
       location ^~ /lool/adminws {
           proxy_pass https://localhost:9980;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection "Upgrade";
           proxy_set_header Host $http_host;
           proxy_read_timeout 36000s;
       }
    }

Created the SSL certificate for the collabora installation:

    sudo -H certbot certonly --nginx-d office.mydomain.com

And finally I created a soft link from the configuration file to the "sites enabled" folder:

    ln -s /etc/nginx/sites-available/collabora /etc/nginx/sites-enabled

Pretty easy stuff.

## Nextcloud configuration

In Nextcloud I installed "Collabora" from the "Apps" menu. On "Settings/Collabora Online" I added my Collabora URL, applied it and voila!

![Captura-de-pantalla-de-2019-03-28-14-53-08](/Captura-de-pantalla-de-2019-03-28-14-53-08.png)  
<small>Sweet Libre Office feel</small>

# S3 bucket

One of my biggest motivation for this project was a cheap, long term storgage solution for some files I don't interact with every day. I'm talking music, movies, videos, ISOS, etc. I used to have a bunch of HDD's but because of all the power outages in Venezuela, almost all my HDDs have died, and new ones are very expensive here, not to say all the issues we have with importing them from the US.

I wanted to look for something S3 like, but as cheap as possible.

In my investigations I found [Wasabi](https://wasabi.com/). Not only it was S3 like, but it was **dirt cheap**. $6 per month for 1TB of data. 1TB OF DATA FOR $6!! I could not believe it!

I created an account and installed the "external storage support" plugin in Nextcloud. After it was installed, I went to "Settings/External Storages" and filled up the information:

![Captura-de-pantalla-de-2019-03-28-15-32-50](/Captura-de-pantalla-de-2019-03-28-15-32-50.png)  
![Captura-de-pantalla-de-2019-03-28-15-34-18](/Captura-de-pantalla-de-2019-03-28-15-34-18.png)  
<small>My bucket name is "long-term-storage" and my local folder name is "Long term storage". You will need to generate API keys for the connection.</small>

I applied the changes and that was it! I could not believe how simple it was, so I uploaded a file just to test:

![Captura-de-pantalla-de-2019-03-28-15-38-38](/Captura-de-pantalla-de-2019-03-28-15-38-38.png)  
![Captura-de-pantalla-de-2019-03-28-15-39-12](/Captura-de-pantalla-de-2019-03-28-15-39-12.png)  
<small>[Classic _noice_ meme](https://knowyourmeme.com/memes/noice) uploaded in Nextcloud, ready to download in Wasabi. _toungue sound_ **Nice**</small>

# Conclusion

The project is looking good! In one sitting I have replaced almost every Google product and even added a humungus amount of storage (virtually infinite!) to the project. For the next delivery I'll add new and fun stuff I always wanted to host myself, like a Wiki, a [Blog](https://blog.rogs.me) (this very same blog!) and many more!

Stay tuned.

[Click here for part 4](https://blog.rogs.me/2019/11/20/de-google-my-life-part-4-of-_-tu-_-dokuwiki-ghost/)  
[Click here for part 5](https://blog.rogs.me/2019/11/27/de-google-my-life-part-5-of-_-tu-_-backups/)

</div>
