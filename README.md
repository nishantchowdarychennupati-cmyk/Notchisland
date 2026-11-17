# NotchIsland 3.0

A refined Dynamic Island–style app for notched MacBooks, built for the **MacBook Air M4 15"**. It sits over the notch and blends into it. It expands with spring animations, shows live activities, and uses **Liquid Glass** on macOS 26 and later.

## Install (pick one)

### A. One command on your Mac (easiest)
1. Unzip `NotchIsland.zip`.
2. Open **Terminal** and run:
   ```bash
   bash ~/Downloads/NotchIsland/Install.command
   ```
   If the folder is somewhere else, use that path instead.
   The first time, macOS may ask you to install Apple's developer tools. Click **Install**, then run the command again.

This builds the app, puts **NotchIsland.app** in Applications and launches it. It also makes `build/NotchIsland.dmg`, which you can keep or give to friends.

### B. Downloadable DMG from GitHub (no tools needed on your Mac)
1. Push this folder to a GitHub repository.
2. The included workflow (`.github/workflows/build.yml`) builds the app on a Mac in the cloud.
3. Download **NotchIsland.dmg** from the run's *Artifacts*. If you push a tag like `v2.0`, it also appears on the *Releases* page.
4. The app isn't notarized, so the first time you open it go to **System Settings → Privacy & Security** and click **Open Anyway**.

## Features

**Closed island (beside the notch)**
- Now playing: album art (can spin like a record) and a visualizer (bars, wave, pulse or static) tinted with the album's colours
- **HUDs:** volume and brightness sliders, plus a pop-up when AirPods, headphones or speakers connect
- Timer and Focus (Pomodoro) countdown, a recording indicator while dictating, and a shelf badge
- Alerts: charger connected, low battery, timer done, Focus/Break, event starting soon, new song, shortcut finished

**Expanded island tabs** (each can be switched off)
| Tab | What it does |
|---|---|
| 🎵 Now Playing | Music only: large artwork, title/artist/album, seeking, play controls and a volume slider (Apple Music, Spotify, Cider) |
| ⏱ Timer | Quick timers with 3 presets and **Focus/Pomodoro** sessions with a large progress ring and round tracker |
| 📅 Agenda | Upcoming events and today's reminders; tick reminders off from the notch |
| 🗂 File Shelf | Drop files on the notch, drag them out later, AirDrop them all |
| 📋 Clipboard | History of copied text, links, colours and files; pin items; reusable snippets; optional direct paste |
| 🖥 System | Volume and brightness sliders, output device, live CPU (with graph), GPU, memory, network, battery time left, thermal state |
| 📷 Mirror | Front camera check; turns off the moment the island closes |
| ✨ Shortcuts & Dictation | Run pinned Siri Shortcuts; on-device voice-to-text that copies the result for you |

## Customisation
- **Appearance:** Notch Black or Liquid Glass, accent colour (album art, system, preset swatches or any colour), width, corner radius, shadow, rounded font, visualizer style
- **Animation:** Snappy, Bouncy, Smooth or Gentle springs (with a live demo), border glow (accent or animated rainbow), grow on hover, bouncing alert icons, spinning album art, Reduce Motion support
- **Tabs:** choose which tabs appear and which one opens first
- **Live Activities & HUDs:** turn each alert and HUD on or off
- **Timer & Calendar:** timer presets and sound, Pomodoro lengths and rounds, reminders
- **Clipboard:** history size, ignore passwords, keep history after quitting, direct paste, snippets
- **Battery & Performance:** when the visualizer animates, Low Power Mode behaviour, stats refresh rate

## Battery efficiency
- Mouse tracking reacts to mouse events; nothing runs while the mouse is still
- Music and Spotify announce track changes, so nothing polls them. Cider is checked only while it's running
- Volume, output device and battery changes come directly from macOS notifications
- Camera, system stats and Shortcuts run only while their tab is open
- Clipboard and brightness checks pause while the screen is asleep or locked
- Timers use tolerance so macOS can group wake-ups. Animations can be limited to when you're charging, or turned off in Low Power Mode

## Permissions (all optional, asked only when you use the feature)
- **Automation (Music / Spotify):** to show and control what's playing
- **Calendars and Reminders:** for the Agenda tab, calendar widget and event alerts
- **Camera:** for the Mirror tab
- **Microphone and Speech Recognition:** for dictation
- **Accessibility:** only if you turn on "paste directly" for the clipboard

## Notes
- Now Playing works with **Apple Music, Spotify and Cider**. Apple blocks third-party apps from system-wide now-playing info on macOS 15.4 and later, so browser audio can't be shown.
- Requires macOS 14 or later. The Liquid Glass style needs macOS 26 or later and an app built with Xcode 26; older systems get a frosted blur instead.
- macOS may still show its own small volume/brightness indicator next to NotchIsland's HUD. Hiding the system one isn't possible for third-party apps.
- The app isn't signed with a developer certificate. Because of that, macOS may ask for permissions again after you rebuild.

## Project layout
```
Sources/NotchIsland/
  App/        app delegate, menu bar, settings window; IslandWindowController (notch panel, event-driven hover and drag)
  Model/      IslandModel (state, geometry, alerts, service lifecycle), Preferences, QuickTimer (timer and Pomodoro), Utilities
  Services/   Media, Battery, Calendar/Reminders, Shelf, Clipboard, SystemAudio, Brightness, SystemStats, Camera,
              Shortcuts, Dictation, PowerManager
  Views/      IslandView (closed island and HUDs), ExpandedView (header and tabs), Components, Tabs/ (one file per tab)
  Settings/   SettingsView (all settings panes)
Resources/AppIcon.icns, Info.plist, build.sh, Install.command
```
