# Achievement

A premium iOS companion app for Steam achievement hunters and completionists.
Calm, content-first, and polished — as if Apple designed a companion app for
Steam achievements.

> Full architecture notes: [ARCHITECTURE.md](ARCHITECTURE.md) ·
> Running log: [JOURNAL.md](JOURNAL.md)

## Project layout

```
Achievement/            SwiftUI app target (views, stores, design system)
AchievementCore/        Platform-independent Swift package: models, Steam Web API
                        client, OpenID auth, stats/streak/sort/compare engines,
                        sample data — fully unit tested, no UIKit/SwiftUI
project.yml             XcodeGen spec — generates Achievement.xcodeproj
Config/                 Build configuration (Steam API key lives here, gitignored)
```

## Getting started (on a Mac)

This project was authored on Windows, so the first Mac session should verify
everything in order:

1. **Run the core tests** (no Xcode project needed):
   ```sh
   cd AchievementCore && swift test
   ```
2. **Create your secrets file** (required before generating the project —
   the spec references it). Get a key at https://steamcommunity.com/dev/apikey,
   or leave it empty and use demo mode:
   ```sh
   cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
   # edit Config/Secrets.xcconfig and paste your key (optional)
   ```
3. **Generate and open the Xcode project**:
   ```sh
   brew install xcodegen
   xcodegen generate
   open Achievement.xcodeproj
   ```
4. **Run on the iPhone simulator.** No key? Tap **“Explore the demo”** on the
   welcome screen — every feature works against curated sample data. The
   `Achievement` scheme's Test action also runs the core package tests.

### Simulator verification checklist

- [ ] Welcome → demo mode → all five tabs render
- [ ] Welcome → “Sign in through Steam” → OpenID sheet → dashboard populates
- [ ] Dashboard: ring animates on appear, sync progress ticks during first import
- [ ] Library: search is instant, all five sort orders correct, cards press-deform
- [ ] Game detail: header art stretches on over-scroll, achievements grouped, rarity badges
- [ ] Friends: leaderboard ranks correctly, comparison screen balanced at all name lengths
- [ ] Profile: charts render with 0, few, and many data points
- [ ] Pull-to-refresh on Dashboard and Library
- [ ] Dynamic Type at XXL, dark mode, iPhone SE and Pro Max layouts
