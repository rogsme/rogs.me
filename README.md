# rogs.me

Source for [rogs.me](https://rogs.me/), a personal site and blog built with [Hugo](https://gohugo.io/) and a locally customized copy of the [Archie](https://github.com/athul/archie) theme.

## Requirements

- Hugo Extended `0.161.1`, matching CI
- Emacs with ox-hugo when editing the Org source documents
- `cwebp` only for production deployment

## Local Development

Preview the site, including drafts:

```bash
hugo server --buildDrafts
```

Run the same build check used by CI:

```bash
hugo --minify
```

There are no separate test, lint, format, or typecheck commands.

## Editing the Site

- `config.toml` contains site metadata, navigation, social links, webrings, and project data.
- `content/` contains Hugo Markdown pages and posts.
- `posts.org` and `resume.org` are ox-hugo sources for pages with matching `EXPORT_FILE_NAME` properties. Keep the Org source and exported Markdown in sync.
- `static/` contains files served from the site root. For example, `static/me.png` is available as `/me.png`.
- `layouts/` contains site-level shortcodes and the custom RSS template.
- `themes/archie/` contains the tracked, locally modified theme templates and CSS. It is not a submodule, so site design changes should be made there directly.

Generated files under `public/`, `resources/_gen/`, and `.hugo_build.lock` are ignored and should not be committed.

## Deployment

Pushes and pull requests targeting `master` run `hugo --minify` in Gitea Actions. A successful push to `master` then deploys over SSH and runs `./build.sh` on the server.

`build.sh` is deployment-only. It converts repository images to WebP, rewrites `.png`, `.jpg`, and `.jpeg` references in repository files, and publishes to `/var/www/rogs.me`. Do not use it as a local build command.

Files containing literal image extensions that must not be rewritten need the `skip_webp_rewrite` marker. See `content/posts/how-i-deploy-my-projects-to-a-single-vps.md` and its matching entry in `posts.org` for an example.
