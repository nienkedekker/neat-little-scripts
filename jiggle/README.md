# Jiggle

Menu bar app that nudges the cursor 1px and back every 30 seconds so macOS never
marks you idle. Holds a power assertion too, so the display won't sleep while it runs.
Skips the nudge if you've moved the mouse yourself since the last tick.

## Build

```sh
./build.sh          # compiles into ~/Applications/Jiggle.app
open ~/Applications/Jiggle.app
```

Grant it Accessibility on first launch (System Settings → Privacy & Security →
Accessibility). Without that, the synthetic mouse events are silently dropped.

## Use

Menu bar icon: Start/Stop, "Run for" (15m / 30m / 1h / 2h / until stopped),
"Open at login". `⌘J` toggles while the menu is open.

It remembers whether it was jiggling and resumes on launch, so a restart or a
rebuild doesn't quietly leave you idle. A timed run resumes with a full duration
rather than the leftover minutes — quitting mid-countdown is rare enough that
the simpler behaviour wins.

## Icons

`assets/` holds the menu bar glyphs — a cursor leaving crumbs, one at rest when idle
and three tapering off when active. SVGs are the source; the PNGs (1x and @2x) are
what ship. `build.sh` copies them into `Contents/Resources`.

They're template images: pure black on transparent, recolored by the menu bar.
If you replace them, keep the `Template` suffix in the filename and keep them
black-on-alpha, or they'll render as solid blobs on a dark menu bar.

## Alfred

Package the workflow and double-click it to import:

```sh
cd alfred && zip -r ../Jiggle.alfredworkflow . && open ../Jiggle.alfredworkflow
```

Then:

- `jiggle` — toggle
- `jiggle on` / `jiggle off` — explicit

It shells out to the URL scheme, which works from anywhere:

```sh
open -g "jiggle://toggle"
open -g "jiggle://on"
open -g "jiggle://off"
```

## Also here

`jiggle-cli` — the standalone terminal version, if you'd rather watch it print
nudges. `./jiggle-cli [interval_seconds] [duration_minutes]`. Symlink it onto your
PATH (e.g. `ln -s "$PWD/jiggle-cli" ~/bin/jiggle`) to run it as `jiggle`.
