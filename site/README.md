# The BRBuddy website

One static page, no build step: `index.html` (inline CSS and JS, no external requests) plus `img/`.
`.github/workflows/pages.yml` publishes this folder to GitHub Pages whenever `site/` changes on main.

## Preview locally
```bash
cd site && python3 -m http.server 8765
```
Then open http://127.0.0.1:8765.

## Images
- `img/companions/`: rendered from the app's own drawing code, so they always match the app. Regenerate after
  changing a companion: `swift build`, then
  `BRBUDDY_SITE_ART=$PWD/build/site-art .build/debug/BRBuddy` (debug builds only; quit it once the files appear),
  and copy the PNGs you need into `img/companions/` (`battery-badge.png` goes in `img/`).
  Use the bare `.build/debug/BRBuddy`: `Tools/build-app.sh` makes a release build, which leaves the debug renderers out.
- `img/icon-*.png`, `img/favicon-64.png`, `img/apple-touch-icon.png`: `sips -Z <size> Config/AppIcon-1024.png`.
- `img/og.png`: the 1200×630 link preview, a headless-Chrome screenshot of a small card page.

## Promo film
The hero plays `img/promo-wide.mp4` (phones: `img/promo-tall.mp4`) muted and looping, like a GIF but about a tenth
of the size; the button turns the sound on. To remake them after changing the film (`PromoFilm.swift`):

```bash
Tools/promo/make-promo.sh
```

Then make the web copies (720p, smaller) and posters from `build/promo/frames`:

```bash
F=build/promo/frames
ffmpeg -y -framerate 30 -i $F/wide/%04d.png -i $F/soundtrack.wav -vf scale=1280:720:flags=lanczos -c:v libx264 -preset slow -crf 24 -pix_fmt yuv420p -c:a aac -b:a 96k -shortest -movflags +faststart site/img/promo-wide.mp4
ffmpeg -y -framerate 30 -i $F/tall/%04d.png -i $F/soundtrack.wav -vf scale=720:1280:flags=lanczos -c:v libx264 -preset slow -crf 24 -pix_fmt yuv420p -c:a aac -b:a 96k -shortest -movflags +faststart site/img/promo-tall.mp4
ffmpeg -y -i $F/wide/0540.png -vf scale=1280:720 -q:v 4 site/img/promo-poster-wide.jpg
ffmpeg -y -i $F/tall/0540.png -vf scale=720:1280 -q:v 4 site/img/promo-poster-tall.jpg
```

## Going live (once)
1. Repo Settings → Pages → Build and deployment → Source: **GitHub Actions**.
2. Merge to main (or run the **Website** workflow by hand). The site appears at
   `https://dhaataalimited-hub.github.io/brbuddy/` until the custom domain is set. (dhaataa.com belongs to the
   separate `dhaataa` repo's site and isn't affected.)
3. Custom domain: Settings → Pages → Custom domain → the domain (e.g. `brbuddy.app`), then at the registrar add
   - apex: `A` records `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
     (and `AAAA` `2606:50c0:8000::153`, `…8001::153`, `…8002::153`, `…8003::153`)
   - `www`: `CNAME` → `dhaataalimited-hub.github.io`

   Verify the domain for the account first (Settings → Pages on your profile → Add a domain) so nobody else can
   claim it, then tick **Enforce HTTPS** once the certificate is issued.
4. If the domain isn't `brbuddy.app`, update `og:url` and `og:image` at the top of `index.html`.

## Version badge
The hero's version badge (`<b data-version>`) is stamped in by `.github/workflows/pages.yml` from the latest GitHub
release each time the site deploys, and the site redeploys after every successful Release run. The value in
`index.html` is only what a local preview shows.
