# Folio

A simple EPUB reader built for the iPhone Duo. Open, the inner display shows a two-page spread split at the fold. Closed, the outer display shows a single page with controls at the bottom. Your place carries over when you fold or unfold. It also runs on any iPhone or iPad running iOS 26 or later.

## Layout

- `Folio/Book`: EPUB parsing (`ZipArchive`, `Markup`, `EPUBPackage`, `ChapterRenderer`), typesetting and TextKit pagination (`Typesetter`, `Paginator`).
- `Folio/Reader`: reader screen, pager, page and spread views, Liquid Glass controls and panels, settings.
- `Folio/Library`: library store (Application Support/Library, one folder per book) and library screens.
- `Folio/Device`: fold handling. `FoldLayout` reads the system division region (`GeometryProxy.reservedRegions(kind: .division)`) and `HingeReader` reads `onHingeChange`; both need iOS 27.1. `DuoHarness` simulates the Duo on older simulators.
- `Folio/App`: a UIKit scene delegate hosts the SwiftUI root so `RootHostingController` can set `preferredVerticalBarBehavior`. The library keeps the Duo's vertical status bar; while a book is open it is disabled, which returns the status bar to the top edge and gives pages the full width of the outer screen (396 pt of text instead of 324 pt).
- `tools/make_sample_epub.py` builds the bundled sample book; `tools/make_icon.swift` draws the app icon.
- `marketing/compose.swift` frames simulator captures in the Duo artwork that ships with Xcode, for screenshots.

## Building

Open `Folio.xcodeproj` in Xcode 27.1 or later. To run on a device, set your own team under Signing & Capabilities. The app has no third-party dependencies.

## iPhone Duo simulator

The iPhone Duo simulator needs the iOS 27.1 runtime. Xcode 27 replaces Simulator.app with DeviceHub (`Xcode.app/Contents/Applications/DeviceHub.app`); folding and unfolding the device is done from its window. `simctl` has no fold command.

## Debug launch flags

Pass these to `simctl launch` with a `SIMCTL_CHILD_` prefix (Debug builds only):

| Flag | Effect |
| --- | --- |
| `FOLIO_DUO=1` | Render inside a simulated Duo (use a 13-inch iPad simulator so both screens fit at 1:1) |
| `FOLIO_POSTURE=open\|half\|closed` | Initial harness posture |
| `FOLIO_OPEN=1` | Open the most recent book at launch |
| `FOLIO_PAGE=n` | Jump to page n (zero-based) |
| `FOLIO_CHROME=1` | Show reader controls at launch |
| `FOLIO_PANEL=contents\|appearance` | Open a panel at launch |
| `FOLIO_THEME=paper\|sepia\|stone\|night` | Theme for this launch only |
| `FOLIO_PROBE=1` | Print screen size, safe area and reserved regions (use `simctl launch --console-pty`) |

```bash
xcodebuild -project Folio.xcodeproj -scheme Folio -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -derivedDataPath build build
```

## License

Folio is free software: you can redistribute it and modify it under the terms of the GNU Affero General Public License, version 3, as published by the Free Software Foundation. See [LICENSE](LICENSE) for the full text.

Copyright (C) 2026 Larkooo

## Contributing

Issues and pull requests are welcome. By submitting a contribution, you agree that it is licensed under the AGPL-3.0 and that the project owner may also distribute it under other license terms, including in versions of Folio sold on the App Store.
