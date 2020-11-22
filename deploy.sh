#!/usr/bin/env bash

rm -rf ~/code/personal/rogs.me/public/*
hugo
rsync -vru ~/code/personal/rogs.me/public/* root@cloud.rogs.me:/var/www/rogs.me
ssh root@cloud.rogs.me "sudo service nginx restart"
