#!/bin/bash

find ./ -type f -name '*.png' -not -path '*/.git/*' -exec sh -c 'cwebp -lossless $1 -o "${1%.png}.webp"' _ {} \;
find ./ -type f -name '*.jpg' -not -path '*/.git/*' -exec sh -c 'cwebp -lossless $1 -o "${1%.jpg}.webp"' _ {} \;
find ./ -type f -name '*.jpeg' -not -path '*/.git/*' -exec sh -c 'cwebp -lossless $1 -o "${1%.jpeg}.webp"' _ {} \;

# Rewrite image references to .webp, skipping files marked with "skip_webp_rewrite"
find . -type f -not -path '*/.git/*' -exec grep -L 'skip_webp_rewrite' {} + | while read -r file; do
    sed -i -e 's/\.png/\.webp/g' -e 's/\.jpg/\.webp/g' -e 's/\.jpeg/\.webp/g' "$file"
done

hugo -s . -d /var/www/rogs.me/ --minify --cacheDir $PWD/hugo-cache
