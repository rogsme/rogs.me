#!/usr/bin/env bash

rm -rf ~/code/personal/blog.rogs.me/public/*
hugo
ssh root@cloud.rogs.me "rm -rf /var/www/rogs.me/*"
scp -r ~/code/personal/blog.rogs.me/public/* root@cloud.rogs.me:/var/www/rogs.me
ssh root@cloud.rogs.me "sudo service nginx restart"
