# IPLoc Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app that displays public IP, DB-IP geolocation, LAN IP, and keeps the display current as IPs change.

**Architecture:** Use a SwiftPM package with a reusable core library and an AppKit executable. Keep network fetching, DB download/update, MMDB reading, formatting, and refresh scheduling separate from status bar UI.

**Tech Stack:** Swift 6, Foundation, AppKit, Network.framework, URLSession, Gzip via `/usr/bin/gunzip` for downloaded DB files, SwiftPM tests.

---

### File Structure

- `Package.swift`: SwiftPM package definition.
- `Sources/IPLocCore/`: core services and pure logic.
- `Sources/IPLocApp/`: AppKit menu bar application.
- `Tests/IPLocCoreTests/`: unit/integration tests for non-UI behavior.
- `scripts/package_app.sh`: release build and `.app` bundle creator.
- `Resources/Info.plist`: app bundle metadata with `LSUIElement`.

### Tasks

- [ ] Create the SwiftPM package structure.
- [ ] Add failing tests for DB-IP download candidate URLs and status title formatting.
- [ ] Implement URL candidate generation and display formatting.
- [ ] Add refresh policy tests for launch, network-change, and timer refresh triggers.
- [ ] Implement refresh coordinator primitives.
- [ ] Add an MMDB integration test that uses `.tmp/dbip-check/dbip-city-lite-2026-05.mmdb` when present.
- [ ] Implement a pure Swift MMDB reader supporting DB-IP City Lite fields.
- [ ] Implement public IP fetching and LAN IP enumeration.
- [ ] Implement database storage, prompted first download, manual update, decompression, and atomic replacement.
- [ ] Implement AppKit status item, menu, network monitor, timer, and user prompts.
- [ ] Add packaging script and app Info.plist.
- [ ] Run `swift test`, `swift build -c release`, and package script.
