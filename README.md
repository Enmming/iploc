# iploc

Native macOS menu bar app for displaying the current public IP address, DB-IP geolocation, and local LAN IP.

## Behavior

- Shows a system template location icon and country code in the macOS menu bar once location data is loaded.
- Shows the app icon and loading text in the menu bar while loading, refreshing, downloading, or updating.
- Shows public IP, location, LAN IP, database version, update cadence, refresh, database update, database deletion, and quit in the menu.
- Does not bundle the DB-IP City Lite database.
- Prompts on first launch before downloading the DB-IP City Lite MMDB file to `~/Library/Application Support/IPLoc/`.
- Refreshes on launch, on macOS network path changes, and every 60 seconds to catch VPN or public IP changes.

## Build

```bash
swift test
scripts/package_app.sh
open dist/IPLoc.app
```

The app uses DB-IP City Lite data from https://db-ip.com/db/download/ip-to-city-lite. Geolocation data by DB-IP.com.
