# IPLoc

Native macOS menu bar app for displaying the current public IP address, DB-IP geolocation, and local LAN IP.

## Download

Download the latest DMG from https://github.com/Enmming/iploc/releases/latest, open it, and drag `IPLoc.app` to Applications.

The app does not bundle the DB-IP City Lite database. On first launch, it asks before downloading the database to `~/Library/Application Support/IPLoc/`.

## Behavior

- Shows a system template location icon and country code in the macOS menu bar once location data is loaded.
- Shows the app icon and loading text in the menu bar while loading, refreshing, downloading, or updating.
- Shows public IP, location, LAN IP, database version, update cadence, refresh, database update, database deletion, and quit in the menu.
- Does not bundle the DB-IP City Lite database.
- Prompts on first launch before downloading the DB-IP City Lite MMDB file to `~/Library/Application Support/IPLoc/`.
- Refreshes on launch, on macOS network path changes, and every 60 seconds to catch VPN or public IP changes.

## Development

```bash
swift test
scripts/package_app.sh
open dist/IPLoc.app
```

## Release

GitHub Releases are built from tags. To publish a new DMG release:

```bash
git push origin main
git tag v0.1.0
git push origin v0.1.0
```

The release workflow runs tests, builds a universal macOS app, creates `IPLoc-v0.1.0-macos.dmg`, and uploads it to the GitHub Release.

To build a DMG locally:

```bash
scripts/package_dmg.sh v0.1.0
open dist/IPLoc-v0.1.0-macos.dmg
```

The app uses DB-IP City Lite data from https://db-ip.com/db/download/ip-to-city-lite. Geolocation data by DB-IP.com.
