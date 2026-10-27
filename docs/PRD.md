# mini-player: Product Requirements Document

**Status:** Draft v1 · **Date:** 2026-10-27 · **Platform:** macOS 26 only · **License:** MIT (public GitHub repo)

## 1. Problem Statement

People who care about how their desktop looks (wallpaper, widgets, rice) have no good way to show what music is playing as part of that look. macOS Control Center's Now Playing card is a transient popover. To my knowledge the built-in desktop widgets don't offer this kind of live, customizable now-playing display, and a browser tab playing a YouTube mix has no presence on the desktop at all.

mini-player is a **read-only, click-through Liquid Glass card that sits on the wallpaper** and shows the current track as decoration. It is a personal tool built and run locally by its author. It is open-sourced under MIT so others can fork or build it.

**Evidence from the discovery spikes (2026-10-27, macOS 26.6.2):**
- The system now-playing feed is readable from a browser tab (Chrome playing a 3h57m YouTube mix). Title, artist, duration, elapsed time, play state and artwork all came through.
- A direct call to the private MediaRemote API returns `nil` on this OS. The restriction is real, so the product depends on a workaround (see §6).
- A borderless `NSGlassEffectView` window at `desktopWindow + 1` renders on the desktop between the wallpaper and the icons.

## 2. Goals

| # | Goal | How we'll know |
|---|---|---|
| G1 | The widget faithfully mirrors the OS Now Playing card's content (artwork, title, artist, progress, times) for any player, including browsers. | Side by side with Control Center, the same track and times are shown. |
| G2 | It reads as decoration, not as an app. It never takes a click, never appears in the Dock or app switcher, and disappears when nothing is playing. | Click-through works. Idle hides the card. |
| G3 | The author can restyle it live, without editing code, through settings. | Every v1 setting changes the on-desktop widget in under 1 second. |
| G4 | It is unobtrusive to run: negligible CPU and memory, and it survives login, sleep and display changes. | Targets in §7. |
| G5 | A stranger can build and run it from the README on macOS 26. | Clean-clone build succeeds in the documented steps. |

## 3. Non-Goals

| Non-goal | Why |
|---|---|
| Playback controls (play, pause, skip, seek) | Click-through decoration, and non-functional buttons look broken. This also removes the whole write path of the adapter. |
| Real audio-reactive waves | Needs an audio-capture permission and continuous capture. v1 uses simulated waves behind an interface. |
| Multiple themes or skins, user-made skins | One theme with deep customization is enough. The JSON config is the seed for later sharing. |
| Rearranging elements or extra layouts | Fixed horizontal layout (artwork + text). Only the artwork side is switchable. |
| Support for macOS earlier than 26, App Store, signing or notarization | Personal tool. Native Liquid Glass only. Local build. |
| Lyrics, multi-display profiles, auto-hide during screen share | Parked ideas. Not required for the core effect. |

## 4. User Stories

**The owner/author (desktop customizer)**
- As a desktop customizer, I want a glass card on my wallpaper showing the current track so that my desktop reflects what I'm listening to.
- As a desktop customizer, I want it to work with YouTube in a browser so that my everyday listening shows up, not only Music or Spotify.
- As a desktop customizer, I want the card to disappear when nothing is playing so that my wallpaper stays clean.
- As a desktop customizer, I want to unlock it, drag it where I like, and lock it again so that it sits exactly where it looks best.
- As a desktop customizer, I want to tweak size, glass, color, font, waves and visible elements, and see the result immediately, so that I can match my wallpaper.
- As a desktop customizer, I want it to launch at login so that I never think about it.

**An open-source user (builder)**
- As a developer, I want clear build steps and honest notes about the private-API dependency so that I can build it and know what might break after an OS update.
- As a developer, I want to share my look as a single JSON config so that others can reproduce it.

## 5. Requirements

### 5.1 Must-Have (P0)

**R1. Now-playing data**
- Subscribe to the system now-playing stream through the adapter (event-driven, no polling).
- Held state is built by merging diff events, since only changed keys arrive.
- Detect a track change from title + artist + duration. **Do not use `contentItemIdentifier`**, which changes on every pause and resume.
- Acceptance:
  - [ ] Given Chrome plays a YouTube video, the card shows its title, artist and artwork within 1s of the track starting.
  - [ ] Given I pause and resume, the card does not treat it as a new track (no marquee or artwork reset).
  - [ ] Given the adapter's `test` command fails at launch, the menu bar shows "Now playing unavailable on this macOS version" and the widget stays hidden. No crash.

**R2. Card content**
- Artwork, title, artist, progress bar, elapsed time, remaining time, wave indicator.
- Time format matches Control Center: `m:ss` under an hour, `h:mm:ss` from one hour, remaining prefixed with `-`.
- Progress and times tick locally at 1 Hz using `elapsedTime + (now − timestamp) × playbackRate`. The stream sends no per-second events.
- Artwork slot accepts any aspect ratio, because artwork can be 16:9 and low-resolution (150×83 was observed). It offers fit or fill. Soft artwork is a known limitation.
- Live streams or items with no duration behave as Control Center does for that case. **Exact behavior TBD (see Open Questions).**
- Acceptance:
  - [ ] A 3h57m track shows remaining time in the same format as Control Center (e.g. `-03:56:57`) and a correctly proportioned bar.
  - [ ] Progress stays within 1s of Control Center over 5 minutes of playback.
  - [ ] Missing artwork shows a neutral placeholder, not a blank gap.

**R3. Marquee**
- A title or artist wider than its slot scrolls horizontally. A title that fits does not move.
- Acceptance:
  - [ ] A 60-character title scrolls smoothly and loops with a pause at the start.
  - [ ] A short title is static.

**R4. Wave indicator (simulated)**
- Rounded bars replace the transport buttons. Animation is procedural and driven only by play state:
  - Playing: smooth animated bars.
  - Paused: bars ease to a flat resting line.
- The wave source sits behind an interface (`WaveSource`), so a real audio-reactive source can be added later without touching the view.
- Acceptance:
  - [ ] Bars animate at 30fps or better with no visible stutter.
  - [ ] Pausing flattens the bars within 500ms. Resuming restarts them.

**R5. States**

| State | Trigger | Behavior |
|---|---|---|
| Playing | `playing: true` | Card visible, waves animate, progress ticks |
| Paused | `playing: false` | Card visible, dimmed, waves flat, progress frozen |
| Idle | Empty payload, no session, or 30s after pause | Card fades out (300ms) and is fully hidden |
| Edit | User turns on Edit mode | Card always visible with **demo content** (sample track, artwork, animated waves) regardless of playback |

- The paused-to-idle timeout is **30s**. It starts at the `playing:false` event and is cancelled by resuming.
- "Edit mode" (unlocked) and "Idle" (hidden because nothing plays) are the two terms used everywhere in code, UI and docs.
- Acceptance:
  - [ ] Pause for 29s and resume: the card never disappeared.
  - [ ] Pause for 31s: the card has faded out.
  - [ ] Close the playing tab: the card hides.
  - [ ] With nothing playing, Edit mode shows demo content, and leaving Edit mode hides the card again.

**R6. Desktop window behavior**
- Borderless, transparent window using `NSGlassEffectView`, at level `desktopWindow + 1` (above the wallpaper, below desktop icons).
- Click-through by default. Visible on all Spaces. Not in the Dock, app switcher or Mission Control window list.
- **Finder owns a full-screen window at the desktop-icon level, above the card's resting level.** So at rest the card can never receive a click: it is click-through by construction (verified from the window layers: Finder `-2147483603`, card `-2147483622`). The same layering means Edit mode **cannot** work at the resting level: while Edit mode is on, the card floats above all windows (`.floating`), and it drops back to the resting level when Edit mode ends. A dashed outline marks Edit mode.
- Acceptance:
  - [x] At rest the card sits below Finder's desktop window, so clicks reach the desktop (layer order verified).
  - [ ] Right-clicking the card with Edit mode off opens the desktop context menu (by-eye check).
  - [x] Edit mode raises the card to the floating level and a drag moves it (verified with a synthesized drag: moved by exactly the drag delta, position kept after locking).
  - [ ] The card is visible after switching Spaces.
  - [ ] The app has no Dock icon.
  - [ ] Behavior under Show Desktop and Stage Manager is checked and documented.

**R7. Legibility over any wallpaper**
- Text and bars must stay readable on light, dark and busy wallpapers. The spike showed that plain white text on glass can wash out.
- Approach is open (see Open Questions), but the requirement is fixed.
- Acceptance:
  - [ ] Checked by eye on a light, a dark, and a high-detail wallpaper. Title and times are readable in all three.

**R8. Menu bar app**
- Items: Show/Hide widget, Edit mode (on/off), Settings…, Quit.
- Acceptance:
  - [ ] Hide removes the card immediately and persists across relaunch.
  - [ ] Edit mode on makes the card draggable. Edit mode off locks it and saves its position.

**R9. Positioning**
- In Edit mode: drag freely and snap to screen corners with a configurable margin.
- The position is saved relative to a display. If that display is missing at launch, fall back to the main display with the same relative position.
- Acceptance:
  - [ ] The position survives quit and relaunch.
  - [ ] Unplugging the saved display does not place the card off-screen.

**R10. Customization (live)**
- One default theme with these settings, each applied to the real widget immediately (no separate preview pane):

| Group | Settings |
|---|---|
| Card | Scale, corner radius, glass tint and opacity, artwork side (left or right), artwork fit or fill and size |
| Color | Accent: auto from artwork, or manual |
| Text | Font family and size |
| Elements | Show or hide: artwork, artist, progress bar, times, wave indicator |
| Waves | Bar count, thickness, gap, max height, corner roundness, shape (bars, mirrored, dots), baseline (bottom or center), placement within the card plus offset, color |
| Position | Snap, margin, display |

- Acceptance:
  - [ ] Dragging any slider updates the on-desktop widget within 1s, with no relaunch.
  - [ ] "Reset to default" restores the factory look.
  - [ ] Hiding all optional elements still shows a valid card (the title remains).

**R11. Config file**
- All settings live in one human-readable JSON file at `~/Library/Application Support/mini-player/config.json`. The settings UI reads and writes it.
- Unknown keys are ignored. Missing keys take defaults. An unparseable file falls back to defaults, and the bad file is kept as `config.json.bak` and not overwritten silently.
- A hand edit is picked up while the app runs.
- Acceptance:
  - [ ] Editing a value in the JSON changes the widget without a restart.
  - [ ] A corrupted file does not crash the app, and the original is preserved.

**R12. Launch at login**
- On by default. The setting lives in the settings pane.
- Acceptance:
  - [ ] After a reboot, the widget runs without opening the app.

**R13. Open-source readiness**
- MIT `LICENSE`. A `THIRD_PARTY_LICENSES` file with the adapter's BSD-3 notice. A README with build steps, a screenshot, the macOS 26 requirement, and an honest note that the now-playing read uses a private-API workaround that can break on OS updates.
- Acceptance:
  - [ ] A clean clone builds and runs by following only the README.

### 5.2 Nice-to-Have (P1)

- Menu bar icon reflects state (playing, paused, idle).
- Respect "Reduce Motion": no marquee (truncate instead) and no wave animation.
- Opt-in "fall back to showing last track while paused" instead of dimming, as a setting.
- Settings import and export (copy and paste the JSON).

### 5.3 Future Considerations (P2)

Designed for, not built:
- **Real audio-reactive waves** via a Core Audio tap or similar, behind the existing `WaveSource` interface, with a clear "needs permission" toggle.
- **Skins** as separate packs of the same JSON-defined parameters plus assets, and sharing them.
- **Alternative layouts** (vertical, compact).
- **Per-display profiles.**
- **Screen-share and call awareness** (auto-hide).

## 6. Technical Notes

**Data source.** `ungive/mediaremote-adapter` (BSD-3). It runs through `/usr/bin/perl`, which has the entitlement, and loads a small helper framework that prints JSON events. Built with CMake. The framework and the test client are bundled in the app. The framework is **not linked**, only passed to the script as a path.

**Observed stream behavior (spike):**
- The first event can be an empty payload. This means no media.
- A full snapshot follows, then diff events (changed keys only).
- Pause arrives as `playing:false`, then `playbackRate:0` with a frozen `elapsedTime`. Resume mirrors it.
- `elapsedTime + (now − timestamp) × rate` matched real playback (47.4s of media over 47s of wall time).
- Use `--no-artwork` for pure state if needed. Artwork should only be decoded when it changes.

**Suggested structure:**
`AdapterProcess` (spawns perl, parses JSON lines) → `NowPlayingStore` (merges diffs, derives state) → `StateMachine` (Playing, Paused, Idle, Edit; owns the 30s timer) → `CardView` (SwiftUI over `NSGlassEffectView`) with `WaveSource` and `ConfigStore` (JSON) as injected dependencies.

**Risks:**
- **Private-API fragility.** An OS update can break the adapter. Mitigation: run the adapter's `test` at launch and show a clear unavailable state. The README discloses the dependency. The adapter is actively maintained.
- **Legibility** on arbitrary wallpapers (R7).
- **Adapter process lifecycle.** It must restart if the subprocess dies, and must be terminated with the app. No orphaned perl processes.

## 7. Success Metrics

This is a personal tool without telemetry, so metrics are engineering and self-assessed targets.

**Leading (first two weeks)**

| Metric | Target |
|---|---|
| CPU while Playing (waves + ticking) | Average under 3% of one core |
| CPU while Idle or hidden | Under 0.5% |
| Memory | Under 100 MB resident |
| Track-change to card update | Under 1s |
| Pause to Paused look | Under 500ms |
| Manual restarts needed | 0 over 14 days of daily use (including sleep and wake) |

**Lagging (one to three months)**
- The author still has it running on their desktop after the first macOS point update.
- Clean-clone build succeeds for someone other than the author.
- Any GitHub issues about "stopped working" are traceable to the adapter, not to app bugs.

## 8. Open Questions

| # | Question | Owner | Blocking? |
|---|---|---|---|
| Q1 | What does Control Center show for a live stream with no duration (empty bar, hidden bar, label)? Mirror it. | Author (check on a live stream) | No, resolve before R2 sign-off |
| Q2 | How to guarantee legibility: system vibrancy label colors, an adaptive text color sampled from the wallpaper, or an adaptive dark scrim? | Author (prototype over 3 wallpapers) | **Yes, before the UI is final** |
| Q3 | Does `SMAppService` login-item registration work for a locally built, ad-hoc-signed app on macOS 26? | Author (spike) | No, fallback is a LaunchAgent plist |
| Q4 | What does the stream emit when the playing tab closes, and on seek? Idle must trigger on the former. | Author (run `stream` and test both) | No, but needed for R5 |
| Q5 | Does the card behave correctly under Show Desktop and Stage Manager (stays visible, stays below windows)? | Author (manual test) | No |
| Q6 | Does the Swift toolchain's x86_64 target matter? The adapter builds for x86_64 and arm64. Confirm the app builds as a universal binary or for the host only. | Author | No |

## 9. Timeline and Phasing

No external deadlines. Suggested order, each step independently usable:

1. **Walking skeleton:** menu bar app, adapter subprocess, merged state, plain glass card with title and artist. Resolve Q2 here.
2. **Full card:** artwork, progress and times, marquee, waves, the four states with the 30s timer, Edit mode with demo content and dragging.
3. **Customization:** settings pane, JSON config with live reload, snapping and per-display position, launch at login.
4. **Open-source polish:** README with screenshot, LICENSE and third-party notices, build script, clean-clone test (R13).
5. **P1 items**, then revisit P2 (real audio waves is the likeliest first).
