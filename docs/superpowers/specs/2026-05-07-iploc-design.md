# IPLoc Design

## Goal

Build a native macOS menu bar app that shows the current public IP address, country/region, and city, while also showing the local LAN IP in the menu.

## Decisions

- The app is a native Swift/AppKit menu bar app.
- The geolocation source is DB-IP City Lite MMDB.
- The DB-IP database is not bundled in the app.
- On first launch, the app prompts the user before downloading the database to `~/Library/Application Support/IPLoc/`.
- The app includes an explicit menu command to update the database.
- The status bar display uses the public IP for geolocation. Private LAN IPs are shown separately and are not geolocated.
- The app must detect IP changes without requiring a restart.

## Runtime Behavior

On launch, the app checks whether the local DB-IP MMDB file exists. If it is missing, the app shows a download prompt explaining that the DB-IP City Lite database is about 125 MB and is required for offline geolocation. After the user confirms, the app downloads the latest monthly `.mmdb.gz`, decompresses it, stores it in Application Support, and refreshes the status bar.

The app refreshes IP state in three ways:

- immediately on launch after the database is available,
- whenever macOS reports a network path change,
- periodically every 60 seconds to catch public IP changes that do not trigger a local network event.

The menu exposes:

- current public IP,
- country/region/city result,
- LAN IP,
- database version/date when known,
- refresh now,
- update database,
- quit.

## Error Handling

If the database is missing or download fails, the status item shows a short unavailable state and the menu offers retry/update. If the public IP cannot be fetched, the app preserves the last known value when available and shows an error in the menu. If a public IP is not found in the DB-IP database, the app shows the IP with an unknown location.

## Testing

Core logic is tested outside AppKit where practical:

- DB-IP monthly download URL candidate generation,
- status title formatting,
- refresh scheduling policy,
- MMDB reader behavior against the downloaded DB-IP database when available.

AppKit status item behavior is verified by building the executable and packaging the `.app`.
