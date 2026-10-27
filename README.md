# mini-player

A read-only Liquid Glass card that sits on your macOS desktop wallpaper and shows what is playing. It is decoration, with no controls, and it is click-through. See [docs/PRD.md](docs/PRD.md).

> **Status: v0.2 (step 2 of the plan in the PRD).** The card shows artwork, a scrolling title and artist, animated wave bars, and a progress bar with elapsed and remaining time. It has the menu bar item, the Playing/Paused/Idle/Edit states, the 30s pause timeout, and Edit mode with demo content and dragging. The settings pane and JSON config are not built yet, so the look is fixed for now.

**Requires macOS 26 and the Xcode command line tools.**

## Build and run

Reading now-playing info on macOS 15.4+ relies on [`ungive/mediaremote-adapter`](https://github.com/ungive/mediaremote-adapter) (BSD-3), which runs through the entitled `/usr/bin/perl`. This is a private-API workaround and can break on an OS update. The app checks it at launch and shows "Now playing unavailable" in the menu if it does not work.

```sh
brew install cmake            # once
scripts/build-adapter.sh      # fetches and builds the pinned adapter into vendor/
scripts/build-app.sh          # assembles build/MiniPlayer.app (ad-hoc signed)
open build/MiniPlayer.app
```

Use the waveform icon in the menu bar to hide or show the card and to enter Edit mode (drag the card where you want it, then turn Edit mode off to lock it).

## Develop

```sh
swift test                    # core logic tests
swift build                   # then run .build/debug/MiniPlayer with the adapter paths set:
```

Without an app bundle, point at a built adapter checkout:

```sh
A=vendor/mediaremote-adapter
MINIPLAYER_ADAPTER_SCRIPT=$A/bin/mediaremote-adapter.pl \
MINIPLAYER_ADAPTER_FRAMEWORK=$A/build/MediaRemoteAdapter.framework \
MINIPLAYER_ADAPTER_TESTCLIENT=$A/build/MediaRemoteAdapterTestClient \
.build/debug/MiniPlayer
```

## License

MIT for this project (a `LICENSE` file is still to be added). The bundled adapter is BSD-3-Clause, and its license is copied into the app bundle.
