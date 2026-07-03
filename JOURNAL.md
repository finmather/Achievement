# Project Journal — Achievement

A running log of decisions, progress, and open threads. Newest entries at the bottom.

---

## 2026-07-03 — Project kickoff

**Context.** Building *Achievement*, a premium iOS companion app for Steam achievement
hunters. Design bar: "if Apple designed a companion app for Steam achievements" —
calm, content-first, generous spacing, intentional motion.

**Development environment constraint.** This project is being developed on a Windows
machine with no Swift toolchain, no Xcode, and no Docker. Consequences:

- All code is written to compile on a Mac, but **cannot be compiled or run here**.
- Mitigation strategy:
  1. Everything that *can* be platform-independent lives in `AchievementCore`, a
     Swift package with **zero UIKit/SwiftUI dependencies**. It carries a full unit
     test suite. On any Mac (or Linux box with Swift): `cd AchievementCore && swift test`.
  2. The app target contains only SwiftUI views and thin `@Observable` stores that
     delegate logic to the core package.
  3. The Xcode project itself is described declaratively in `project.yml`
     ([XcodeGen](https://github.com/yonaskolb/XcodeGen)) — no hand-maintained
     `.pbxproj`. On a Mac: `brew install xcodegen && xcodegen generate`.
- First task on a Mac: run the core tests, generate the project, launch the
  simulator, and walk every screen. A checklist lives in `README.md`.

**Stack decisions.**
- iOS 17 minimum: `@Observable`, Swift Charts, `.sensoryFeedback`,
  `ContentUnavailableView`, `scrollTransition` — all used, all iOS 17 APIs.
- Swift 5.9 tools version, strict-concurrency-friendly code (`Sendable` models,
  value-type domain layer, `async/await` networking).
- No third-party dependencies in v1. Steam's Web API is plain JSON over HTTPS and
  the design system is bespoke; dependencies would only add risk on a project that
  can't be compiled locally yet.

**Steam integration decisions.**
- **Auth**: Steam only supports OpenID 2.0 for third parties. `ASWebAuthenticationSession`
  needs a resolvable redirect URL, which Steam's OpenID flow can't provide for a
  client-only app — so sign-in uses a `WKWebView` sheet that *intercepts* the
  `return_to` redirect before it loads (the established pattern for mobile Steam
  companions). The OpenID response is then verified server-side-style by POSTing
  `check_authentication` back to Steam. All parsing/verification logic is pure and
  unit-tested in `AchievementCore/Auth`.
- **Data**: Steam Web API (`GetOwnedGames`, `GetPlayerAchievements`,
  `GetSchemaForGame`, `GetGlobalAchievementPercentagesForApp`, `GetPlayerSummaries`,
  `GetFriendList`). There is **no bulk endpoint** for per-game achievement progress,
  so the library is hydrated progressively: played games first, bounded concurrency,
  results cached on disk so subsequent launches are instant. The UI treats hydration
  as a first-class state (sync progress on Dashboard) rather than a spinner.
- **API key**: the Web API requires a key. v1 reads it from `Config/Secrets.xcconfig`
  (gitignored; template provided). A hosted proxy that keeps the key off-device is
  the right long-term answer — recorded in ARCHITECTURE.md as the v2 path.
- **Demo mode**: the app is fully explorable without a Steam account via curated
  sample data (also powers previews and made the UI testable without live keys).

**Next.** Build `AchievementCore`: domain models → engines (stats, streaks, history,
sorting, comparison) → OpenID → Web API client → sample data → tests.

---

## 2026-07-03 — v1 code complete

Everything in the v1 brief is written and committed: core package with ~60
unit tests, all five screens, onboarding with verified OpenID sign-in, demo
mode, design system, XcodeGen spec, and this documentation set. See
ARCHITECTURE.md for the shape of things; highlights and honest caveats below.

**Decisions made along the way.**
- *Average vs overall completion*: the dashboard hero shows **average per-game
  completion** (matches how Steam and completionists measure it); overall
  unlocked/total is still computed and available. Both live in `LibraryStats`.
- *"Almost There" rail*: added to the dashboard (games ≥70% and not perfect,
  closest first) — for a completionist this is the single most motivating
  list in the app. Not in the brief, but squarely in its spirit.
- *Favourite genres (Profile)*: **deferred**. Needs the storefront
  `appdetails` endpoint per app; would double first-sync traffic for a
  tertiary stat. Logged in ARCHITECTURE.md as v2.
- *Friend leaderboards*: full friends-wide average-completion leaderboards
  would need a whole-library hydration **per friend** (hundreds of calls
  each). v1 ships per-friend duels plus a "you lead in X of Y shared games"
  head-to-head computed from the games already on screen.
- *Celebrations*: refresh-discovered unlocks raise a gold toast + double-pulse
  haptic on the dashboard; perfect games get a gold banner, crown seal, and a
  one-time celebration haptic on the game page. Deliberately no confetti.

**Sample-data bug caught in review** (worth remembering as a pattern): rarity
percentages used additive jitter on top of exponential decay, so deep lists
could never reach the Legendary tier and `testRarityTiersSpanTheSpectrum...`
would have failed. Fixed by scaling jitter with the decay. Found by re-reading
the math against the test's assertion — the discipline of writing tests that
assert *invariants* (not snapshots) paid off before a compiler ever ran.

**Honest status: not yet compiled.** No Swift toolchain exists on this
machine. The riskiest spots to check first on a Mac, in order:
1. `swift test` in `AchievementCore` — engines/planner/OpenID/client tests.
2. Strict-concurrency diagnostics in `LibrarySyncService.run` (task-group
   result handling mutates locals from the group body — standard pattern,
   but the checker has opinions) and in `SteamWebAPIClient.achievements`
   (async-let over internal DTO arrays).
3. `xcodegen generate` — the scheme's package-test reference syntax
   (`package: AchievementCore/AchievementCoreTests`) and the `configFiles`
   requirement that `Config/Secrets.xcconfig` exists (README step 2).
4. Simulator walk per the README checklist; profile scrolling on a
   several-hundred-game library (AsyncImage has no disk cache — v2 item).

**Verification I could and did do here:** every JSON asset validated, all
fixture JSON in tests parsed with an external JSON parser, test assertions
recomputed by hand against the sample-data spec table (completion sums,
streak days, rarity boundaries), and a full re-read of cross-file API usage
(store ↔ core signatures, navigation values, environment plumbing). That
review pass caught and fixed two UI bugs before first compile: the welcome
screen's error alert used a `.constant` binding (would re-present forever
after OK), and library cards lacked a `.clipped()` for the landscape-header
artwork fallback (460×215 filling a 2:3 slot would bleed over the card).

---

## 2026-07-03 — Core verified on Windows: 69/69 tests pass

"Not yet compiled" is no longer true. Installed the official Swift 6.3.2
Windows toolchain via winget (plus VS 2022 Build Tools with only the MSVC
v143 + Windows 11 SDK components — the toolchain's one unbundleable
prerequisite), and ran the full `AchievementCore` suite on this machine:

**69 tests, 0 failures, 0 warnings, in 0.3s.**

Findings from the first real compile:
- **One genuine bug**: `SteamOpenID.swift` (and three test files) used
  `URLRequest` without the `#if canImport(FoundationNetworking)` guard that
  the networking files already had. On non-Apple platforms `URLRequest`
  lives in FoundationNetworking. Fixed everywhere.
- **One async-safety warning**: the test `MockHTTPClient` called
  `NSLock.lock()` directly inside an async function; extracted a synchronous
  `record(_:)` helper (locks must never span suspension points anyway).
- **OneDrive gotcha**: SwiftPM's `.build` symlink creation intermittently
  fails inside OneDrive-synced folders (I/O error 512, exit 255 *after* all
  tests pass). Fix: `swift test --scratch-path "$env:LOCALAPPDATA\..."` —
  documented in README.
- The strict-concurrency worries from the previous entry didn't materialize:
  `LibrarySyncService`'s task-group pattern and the client's `async let`
  merge compiled clean under the Swift 6.3 compiler in language mode 5.

**Still Mac-only:** the SwiftUI app target (screens, animations, gestures,
simulator walk). Everything below the UI is now compiler- and test-verified.

---

## 2026-07-03 — The Aurora redesign

Full visual-language overhaul on the user's direction: v1 read as generic
("cards on white, obviously generated"). New language, new bar: an app that
could plausibly be featured — inspired by Gentler Streak / Flighty / Arc
Search / Forest, deliberately not Apple-clone.

**The language.** Living MeshGradient aurora behind every screen (drifts at
rest, reacts to scroll, dusk palette in dark / dawn mist in light,
reduce-motion honored). Rectangles are gone: surfaces are glass chips
(capsule / circle / continuous blob), content floats in whitespace grouped
by proximity. Editorial type (64pt rounded numerals, kerned caps labels).
Choreographed springs everywhere: staggered entrances, glowing ring sweeps,
breathing placeholders, zoom transition from library covers into detail.

**Signature pieces.** (1) Genre radar hexagon on the profile — six axes
scored by GenreEngine from SteamSpy community tags, polygon springs out,
vertices tappable, strongest axis auto-spotlights. (2) Bespoke unlock
celebration — rarity glow bloom, spring icon landing, staged haptics,
drifting embers (no confetti), triggered on fresh unlocks and replayable
from the dashboard spotlight.

**Decisions.**
- iOS 17 → **18**: MeshGradient, `navigationTransition(.zoom)`,
  `onScrollGeometryChange` are the redesign's backbone.
- Genre tags via **SteamSpy** (Steam's own genres lack Roguelike/FPS/etc.);
  fetched lazily for played games, cached forever, radar degrades to a
  "keep playing" state without data.
- All illustration is **programmatic SwiftUI** (empty-state orbits, ember
  field, radar) — one cohesive style, both color schemes free.
- Habits/year-summary/milestone logic all landed as **pure core engines**
  first (89 tests green locally) so the flashy layer stays thin.

**Verification loop (no Mac here).** CI now runs the screenshot walk twice
(dark with screen-recorded video, then light), captures 9 states including
the celebration (`UI_TEST_CELEBRATE=1`), radar, and empty search, and
uploads screenshots + motion video as artifacts. The review discipline:
pull artifacts, inspect stills for spacing/alignment/template-smell, watch
the video for animation timing, fix, push again. First pass is a draft by
definition — polish iterations expected and planned.
