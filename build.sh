#!/bin/bash

find ./ -type f -name '*.png' -not -path '*/.git/*' -exec sh -c 'cwebp -lossless $1 -o "${1%.png}.webp"' _ {} \;
find . -type f -not -path '*/.git/*' -exec sed -i -e 's/\.png/\.webp/g' {} \;
rm -rf /var/www/rogs.me/*
hugo -s . -d /var/www/rogs.me/
