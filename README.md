# NotchIsland 2.0

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

**Closed (live activities beside the notch)**
- Now playing: album art and a visualizer (bars or wave) tinted with the album's colours
- Timer countdown, including a paused state
- Alerts that pop out briefly: charger connected, low battery, timer done, calendar event starting soon, files added to the shelf
- A shelf badge showing how many files are parked

**Expanded (hover or click)**
- **Home tab**
  - Now Playing: large artwork with a glow, title and artist, a progress bar you can click or drag to seek, and previous / play-pause / next buttons
  - Timer widget: a progress ring, pause/resume, +1 min, stop, and three preset buttons you can change
  - Calendar widget: today's date and your next event (calendar colour, "in 12 min", "Now · until 3:00")
- **Shelf tab:** drag files onto the notch to park them, then drag them back out, double-click to open, right-click to show in Finder or copy the path, or **AirDrop** them all
- Battery status and a settings button sit beside the notch

## Customisation (Settings window, styled like System Settings)
| Pane | Options |
|---|---|
| General | Launch at login, menu bar icon, open on hover or click, hover and close delays, haptics, which display, show over full-screen apps, reset all settings |
| Appearance | Live preview, **Notch Black or Liquid Glass**, accent colour (from album art, system accent or a custom colour), expanded width, corner radius, shadow, rounded font, visualizer style, album art in the closed island |
| Live Activities | Turn each activity and alert on or off, low-battery level, how many minutes before an event to alert |
| Widgets | Battery in the header and its percentage, calendar on/off and access, timer on/off, three timer presets, timer sound with preview |
| Media | Preferred player (automatic, Apple Music or Spotify), progress bar, artwork glow, shortcut to the permission settings |
| File Shelf | Turn the shelf on or off, open it automatically when dragging files, clear it |

You can open Settings from the gear in the island, the capsule icon in the menu bar, or by opening the app again.

## Permissions
- **Automation (Music / Spotify):** to show and control what's playing. macOS asks the first time.
- **Calendars:** for the calendar widget and event alerts. Optional.

## Notes
- Now Playing works with **Music and Spotify**. Apple blocks third-party apps from system-wide now-playing info on macOS 15.4 and later, so browser audio can't be shown.
- Requires macOS 14 or later. The Liquid Glass style needs macOS 26 or later and an app built with Xcode 26; older systems get a frosted blur instead.
- The app isn't signed with a developer certificate. Because of that, macOS may ask for permissions again after you rebuild.

## Project layout
```
Sources/NotchIsland/
  App/        NotchIslandApp.swift (app delegate, menu bar, settings window), IslandWindowController.swift (notch panel, hover and drag tracking)
  Model/      IslandModel.swift (state, geometry, alerts, timer), Preferences.swift, Utilities.swift
  Services/   MediaController, BatteryMonitor, CalendarService, ShelfStore
  Views/      IslandView (closed island), ExpandedView (home and widgets), ShelfView, Components (shape, glass, visualizer, buttons)
  Settings/   SettingsView.swift
Resources/AppIcon.icns, Info.plist, build.sh, Install.command
```
