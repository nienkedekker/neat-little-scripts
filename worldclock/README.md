# WorldClock

Menu bar clock that shows your local time next to Amsterdam time:

```
🇮🇩 16:42  🇳🇱 10:42
```

The local side follows the Mac's time zone, flag included, so it keeps working
when you travel. Amsterdam goes through `Europe/Amsterdam`, which means summer and
winter time switch over on their own.

The menu shows the full date in both places (handy when they're on different days)
and how far ahead or behind Amsterdam is, plus "Open at login" and Quit.

## Build

```sh
./build.sh          # compiles into ~/Applications/WorldClock.app and starts it
```

No permissions needed. Tick "Open at login" in the menu to keep it around.

## Another city

Change `remote` and `remoteFlag` at the top of `WorldClock.swift`, plus the
"Amsterdam" strings in `refresh()`, then rebuild.
