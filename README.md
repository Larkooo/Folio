# Folio

A simple EPUB reader built for the iPhone Duo. Open, the inner display shows a two-page spread split at the fold. Closed, the outer display shows a single page with controls at the bottom. Your place carries over when you fold or unfold. It also runs on any iPhone or iPad running iOS 26 or later.

## Layout

- `Folio/Book`: EPUB parsing (`ZipArchive`, `Markup`, `EPUBPackage`, `ChapterRenderer`), typesetting and TextKit pagination (`Typesetter`, `Paginator`).
- `Folio/Reader`: reader screen, pager, page and spread views, Liquid Glass controls and panels, settings.
- `Folio/Library`: library store (Application Support/Library, one folder per book) and library screens.
- `Folio/Device`: fold handling. `FoldLayout` reads the system division region (`GeometryProxy.reservedRegions(kind: .division)`) and `HingeReader` reads `onHingeChange`; both need iOS 27.1. `DuoHarness` simulates the Duo on older simulators.
- `tools/make_sample_epub.py` builds the bundled sample book; `tools/make_icon.swift` draws the app icon.

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

```bash
xcodebuild -project Folio.xcodeproj -scheme Folio -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -derivedDataPath build build
```
