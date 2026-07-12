# Repository Guide

## Build and Preview

- This is a single Hugo site. CI pins Hugo Extended `0.161.1`; use that version when investigating version-specific failures.
- Match CI with `hugo --minify`. For a local server, use `hugo server --buildDrafts`.
- `./build.sh` is deployment-only: it converts images with `cwebp`, rewrites `.png`/`.jpg`/`.jpeg` references across repository files, and publishes to `/var/www/rogs.me`. Do not use it for routine verification.
- There is no separate test, lint, format, or typecheck task. A successful Hugo build is the automated verification performed on pull requests.

## Source Layout

- `config.toml` owns site metadata, menus, project lists, and shortcode data.
- `content/` contains rendered Hugo Markdown. `posts.org` and `resume.org` are ox-hugo source documents for many matching files under `content/posts/` and `content/resume/`; when a page has a matching `EXPORT_FILE_NAME`, update the Org source and exported Markdown together rather than letting them drift.
- `static/` contains root-served assets; `/image.png` maps to `static/image.png`.
- `layouts/` contains site-level shortcodes and the RSS override. The remaining templates and all CSS live in the tracked, locally modified `themes/archie/` directory; it is not a submodule or disposable dependency.
- `public/`, `resources/_gen/`, and `.hugo_build.lock` are generated and ignored. Do not edit or commit them.

## Site-Specific Behavior

- Production deployment runs only from `master`: Gitea CI first runs `hugo --minify`, then SSHes to the server and executes `./build.sh`.
- `build.sh` rewrites image extensions unless the file contains `skip_webp_rewrite`. Preserve that marker for content that must show literal `.png`/`.jpg`/`.jpeg` text, such as command examples.
- The root `layouts/_default/rss.xml` intentionally emits full post content and restricts feed items to the `posts` section.
- Goldmark unsafe rendering is enabled, and existing content relies on raw HTML plus custom shortcodes under `layouts/shortcodes/`.
