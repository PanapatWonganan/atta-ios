# ATTA — iOS

SwiftUI port of the ATTA Android app (same quiet-luxury design system,
same 144 hand-broken EN/TH affirmations, same deterministic line-of-day
logic). No external dependencies.

## Build & run

```bash
xcodegen generate   # project.yml -> ATTA.xcodeproj (brew install xcodegen)
xcodebuild -project ATTA.xcodeproj -scheme ATTA \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Or open `ATTA.xcodeproj` in Xcode and hit Run. Regenerate the project any
time files are added — never edit the .xcodeproj by hand.

## Layout

- `Shared/` — design tokens, models, 144 affirmations (generated from the
  Android `Affirmation.kt`), 8 widget themes, deterministic repository,
  settings store (app-group JSON). Compiled into app AND widget.
- `ATTA/` — app entry + router, components, screens, practice audio
  engine (AVSpeechSynthesizer + looping ambient beds), StoreKit 2
  billing, UNUserNotificationCenter reminders.
- `AttaWidget/` — WidgetKit widget (small + medium), native gradients.
- `Resources/` — Noto Serif Thai + IBM Plex Sans Thai, mood WAVs.

## Known state / before App Store

- `Assets.xcassets.disabled/` holds the app icon: this Mac's actool
  refuses the old iOS 18.2 sim runtime with the 26.5 SDK. Once the
  iOS 26.5 simulator runtime mounts (usually after a Mac restart —
  it is downloaded already), rename it back to
  `Resources/Assets.xcassets` and regenerate.
- `AttaBilling.localTestingMode = true` — paywall sets plans locally.
  Flip to false after creating atta_weekly / atta_yearly /
  atta_lifetime in App Store Connect.
- No AdMob / no Firebase in iOS v1 (comments mark where they land).
- Signing is disabled (`CODE_SIGNING_ALLOWED: NO`) for simulator work;
  set a team in project.yml before device builds / TestFlight.
