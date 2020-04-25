---
title: "De-Google my life - Part 5 of ¯\_(ツ)_/¯: Backups"
url: "/2019/11/27/de-google-my-life-part-5-of-_-tu-_-backups"
date: 2019-11-27T19:30:00-04:00
lastmod: 2020-04-25T12:35:53-03:00
tags : [ "degoogle", "devops" ]
---

Hello everyone! Welcome to the fifth post of my blog series "De-Google my life". If you haven't read the other ones you definitely should! ([Part 1](https://blog.rogs.me/2019/03/15/de-google-my-life-part-1-of-_-tu-_-why-how/), [Part 2](https://blog.rogs.me/2019/03/22/de-google-my-life-part-2-of-_-tu-_-servers-and-emails/), [Part 3](https://blog.rogs.me/2019/03/29/de-google-my-life-part-3-of-_-tu-_-nextcloud-collabora/), [Part 4](https://blog.rogs.me/2019/11/20/de-google-my-life-part-4-of-_-tu-_-dokuwiki-ghost/)).

At this point, our server is up and running and everything is working 100% fine, but we can't always trust that. We need a way to securely backup everything in a place where we can restore quickly if needed.

# Backup location

My backups location was an easy choice. I already had a Wasabi subscription, so why not use it to save my backups as well?

I created a new bucket on Wasabi, just for my backups and that was it.

![Captura-de-pantalla-de-2019-11-24-18-13-55](/Captura-de-pantalla-de-2019-11-24-18-13-55.png)  
<small>There is my bucket, waiting for my _sweet sweet_ backups</small>

# Security

Just uploading everything to Wasabi wasn't secure enough for me, so I'm encrypting my tar files with GPG.

## What is GPG?

From their website:

> GnuPG ([GNU Privacy Guard](https://gnupg.org/)) is a complete and free implementation of the OpenPGP standard as defined by RFC4880 (also known as PGP). GnuPG allows you to encrypt and sign your data and communications; it features a versatile key management system, along with access modules for all kinds of public key directories. GnuPG, also known as GPG, is a command-line tool with features for easy integration with other applications. A wealth of frontend applications and libraries are available. GnuPG also provides support for S/MIME and Secure Shell (ssh).

So, by using GPG I can encrypt my files before uploading to Wasabi, so if for any reason there is a leak, my files will still be protected by my GPG password.

# Script

## Nextcloud

    #!/bin/sh

    # Nextcloud
    echo "======================================"
    echo "Backing up Nextcloud"
    cd /var/lib/docker/volumes/nextcloud_nextcloud/_data/data/roger

    NEXTCLOUD_FILE_NAME=$(date +"%Y_%m_%d")_nextcloud_backup
    echo $NEXTCLOUD_FILE_NAME

    echo "Compressing"
    tar czf /root/$NEXTCLOUD_FILE_NAME.tar.gz files/

    echo "Encrypting"
    gpg --passphrase-file the/location/of/my/passphrase --batch -c /root/$NEXTCLOUD_FILE_NAME.tar.gz 

    echo "Uploading"
    aws s3 cp /root/$NEXTCLOUD_FILE_NAME.tar.gz.gpg s3://backups-cloud/Nextcloud/$NEXTCLOUD_FILE_NAME.tar.gz.gpg --endpoint-url=https://s3.wasabisys.com

    echo "Deleting"
    rm /root/$NEXTCLOUD_FILE_NAME.tar.gz /root/$NEXTCLOUD_FILE_NAME.tar.gz.gpg

### A breakdown

    #!/bin/sh

This is to specify this is a shell script. The standard for this type of scripts.

    # Nextcloud
    echo "======================================"
    echo "Backing up Nextcloud"
    cd /var/lib/docker/volumes/nextcloud_nextcloud/_data/data/roger

    NEXTCLOUD_FILE_NAME=$(date +"%Y_%m_%d")_nextcloud_backup
    echo $NEXTCLOUD_FILE_NAME

Here, I `cd`ed to where my Nextcloud files are located. On [De-Google my life part 3](https://blog.rogs.me/2019/03/29/de-google-my-life-part-3-of-_-tu-_-nextcloud-collabora/) I talk about my mistake of not setting my volumes correctly, that's why I have to go to this location. I also create a new filename for my backup file using the current date information.

    echo "Compressing"
    tar czf /root/$NEXTCLOUD_FILE_NAME.tar.gz files/

    echo "Encrypting"
    gpg --passphrase-file the/location/of/my/passphrase --batch -c /root/$NEXTCLOUD_FILE_NAME.tar.gz 

Then, I compress the file into a `tar.gz` file. After, it is where the encryption happens. I have a file located somewhere in my server with my GPG password, it is used to encrypt my files using the `gpg` command. The command then returns a "filename.tar.gz.gpg" file, which is then uploaded to Wasabi.

    echo "Uploading"
    aws s3 cp /root/$NEXTCLOUD_FILE_NAME.tar.gz.gpg s3://backups-cloud/Nextcloud/$NEXTCLOUD_FILE_NAME.tar.gz.gpg --endpoint-url=https://s3.wasabisys.com

    echo "Deleting"
    rm /root/$NEXTCLOUD_FILE_NAME.tar.gz /root/$NEXTCLOUD_FILE_NAME.tar.gz.gpg

Finally, I upload everything to Wasabi using `awscli` and delete the file, so I keep my filesystem clean.

## Is that it?

This is the basic setup for backups, and it is repeated among all my apps, with few variations

## Dokuwiki

    # Dokuwiki
    echo "======================================"
    echo "Backing up Dokuwiki"
    cd /data/docker

    DOKUWIKI_FILE_NAME=$(date +"%Y_%m_%d")_dokuwiki_backup

    echo "Compressing"
    tar czf /root/$DOKUWIKI_FILE_NAME.tar.gz dokuwiki/

    echo "Encrypting"
    gpg --passphrase-file the/location/of/my/passphrase --batch -c /root/$DOKUWIKI_FILE_NAME.tar.gz 

    echo "Uploading"
    aws s3 cp /root/$DOKUWIKI_FILE_NAME.tar.gz.gpg s3://backups-cloud/Dokuwiki/$DOKUWIKI_FILE_NAME.tar.gz.gpg --endpoint-url=https://s3.wasabisys.com

    echo "Deleting"
    rm /root/$DOKUWIKI_FILE_NAME.tar.gz /root/$DOKUWIKI_FILE_NAME.tar.gz.gpg

Pretty much the same as the last one, so here is a quick explanation:

*   `cd` to a folder
*   tar it
*   encrypt it with gpg
*   upload it to a Wasabi bucket
*   delete the local files

## Ghost

    # Ghost
    echo "======================================"
    echo "Backing up Ghost"
    cd /root

    GHOST_FILE_NAME=$(date +"%Y_%m_%d")_ghost_backup

    docker container cp ghost_ghost_1:/var/lib/ghost/ $GHOST_FILE_NAME
    docker exec ghost_db_1 /usr/bin/mysqldump -u root --password=my-secure-root-password ghost > /root/$GHOST_FILE_NAME/ghost.sql

    echo "Compressing"
    tar czf /root/$GHOST_FILE_NAME.tar.gz $GHOST_FILE_NAME/

    echo "Encrypting"
    gpg --passphrase-file the/location/of/my/passphrase --batch -c /root/$GHOST_FILE_NAME.tar.gz

    echo "Uploading"
    aws s3 cp /root/$GHOST_FILE_NAME.tar.gz.gpg s3://backups-cloud/Ghost/$GHOST_FILE_NAME.tar.gz.gpg --endpoint-url=https://s3.wasabisys.com

    echo "Deleting"
    rm -r /root/$GHOST_FILE_NAME.tar.gz $GHOST_FILE_NAME /root/$GHOST_FILE_NAME.tar.gz.gpg

## A few differences!

    docker container cp ghost_ghost_1:/var/lib/ghost/ $GHOST_FILE_NAME
    docker exec ghost_db_1 /usr/bin/mysqldump -u root --password=my-secure-root-password ghost > /root/$GHOST_FILE_NAME/ghost.sql

Something new! Since on Ghost I didn't mount any volumes, I had to get the files directly from the docker container and then get a DB dump for safekeeping. Nothing too groundbreaking, but worth explaining.

# All done! How do I run it automatically?

Almost done! I just need to run everything automatically, so I can just set it and forget it. Just like before, whenever I want to run something programatically, I will use a cronjob:

    0 0 * * 1 sh /opt/backup.sh

This means:  
_Please, can you run this script every Monday at 0:00? Thanks, server :_*

# Looking good! Does it work?

Look for yourself :)

![Captura-de-pantalla-de-2019-11-24-19-26-45](/Captura-de-pantalla-de-2019-11-24-19-26-45.png)  
<small>Nextcloud</small>

![Captura-de-pantalla-de-2019-11-24-19-28-09](/Captura-de-pantalla-de-2019-11-24-19-28-09.png)  
<small>Dokuwiki</small>

![Captura-de-pantalla-de-2019-11-24-19-29-04](/Captura-de-pantalla-de-2019-11-24-19-29-04.png)  
<small>Ghost</small>

# Where do we go from here?

I don't know, I only know this project is not over. I have other apps running (Wallabag, Matomo and Commento), but I don't find them as interesting for a new post (of course, if you still want to read about it I will gladly do it).

I hope you all learned from and enjoyed this experience with me because I sure have! I've had amazing feedback from the community and that's what always kept this project on my mind.

A big thank you to [/r/selfhosted](https://reddit.com/r/selfhosted) and more recently [/r/degoogle](https://www.reddit.com/r/degoogle), I learned A LOT from those communities. If you liked these series, you will definitely like those subreddits.

I'm looking to transform all this knowledge to educational talks soon, so if you are in the Montevideo area, stay tuned for a _possible_ meetup! (I know this is a longshot in a country of around 4 million people, but worth trying hehe).

Again, thank you for joining me on this journey and stay tuned! There is more content coming :)
