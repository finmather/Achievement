# Achievement — Architecture

Companion doc to [README.md](README.md) (setup) and [JOURNAL.md](JOURNAL.md)
(chronological decisions). This describes how the code is shaped and why.

## Principles

1. **Two layers, hard boundary.** Everything that can exist without a screen
   lives in `AchievementCore` (a Swift package with no UIKit/SwiftUI imports);
   the app target contains only SwiftUI views and thin `@Observable` stores.
   This exists for testability — the project was authored on Windows where
   SwiftUI can't compile, so all behavior worth testing had to live in a layer
   that runs anywhere Swift runs.
2. **The cache is the UI's source of truth; Steam is the cache's.** Every
   screen renders instantly from disk; network syncs refine what's on screen.
   No screen ever blocks on Steam.
3. **Sync is a stream, not a spinner.** First imports take minutes for big
   libraries (see *Steam API constraints*). The pipeline emits granular events
   so the UI can show a living import, game by game.
4. **Value types everywhere.** Domain models are `Sendable` structs. The only
   reference types are the `@MainActor` stores that own screen state, and the
   `LibraryCache` actor that owns disk access.

## Layout

```
AchievementCore/Sources/AchievementCore/
  Models/       SteamID, PlayerProfile, Game, Achievement (+Rarity, UnlockEvent),
                SteamArtwork (CDN URL builder)
  Engines/      StatsEngine, StreakEngine, HistoryEngine, LibrarySort, ComparisonEngine
                — pure functions, the app's business logic
  Networking/   HTTPClient (protocol), SteamWebAPIClient, DTOs, typed errors
  Sync/         SyncPlanner (pure policy), LibrarySyncService (event stream),
                LibraryCache (actor, JSON-on-disk)
  Auth/         SteamOpenID (pure), SteamAuthenticator (network verification)
  Sample/       SampleData — seeded demo library w/ real appIDs

Achievement/
  App/          AchievementApp, RootView (session switch), MainTabView
  Model/        AppModel (session), HomeModel (per-session composition root),
                LibraryStore, FriendsStore + ComparisonModel,
                GameDataSource (live/demo), AppConfig, KeychainStore
  DesignSystem/ Theme, Typography, CompletionRing, Pressable, Shimmer,
                RemoteArtView, AvatarView, Haptics
  Features/     Onboarding, Dashboard, Library, GameDetail, Friends, Profile
  Support/      Formatters
```

## Data flow

```
Steam Web API ──> SteamWebAPIClient ──> LibrarySyncService ──┐
                                             │               ├─ AsyncThrowingStream
                                             ▼               │  of LibrarySyncEvent
                                        LibraryCache <───────┘
                                        (JSON on disk)
                                             │
                              LibraryStore (@Observable, @MainActor)
                                             │
                     Dashboard / Library / GameDetail / Profile (SwiftUI)
```

A sync emits: cached library (instant paint) → fresh owned-games list (cached
progress carried forward, so numbers never regress mid-sync) → one
`gameHydrated` per game (bounded batches of 4, most recently played first) →
final persisted library → `finished(failedAppIDs:)`. Transient per-game
failures are reported, not fatal; the next sync retries them. A private
profile aborts with a typed error the UI can explain.

`SyncPlanner` is the entire hydration policy as a pure function: played games
only, refetch only when playtime/last-played changed, order by recency. It's
unit-tested; the service just executes the plan.

## Steam API constraints that shaped the design

- **No bulk achievement endpoint.** Per-game progress requires
  `GetPlayerAchievements` + `GetSchemaForGame` + global percentages per app.
  Hence: progressive hydration, aggressive caching, change detection, and
  "fetched, has none" cached as an empty list so it's never refetched.
- **No OAuth — OpenID 2.0 only.** `ASWebAuthenticationSession` needs a real
  redirect URL, which needs a server. Instead, sign-in runs in a `WKWebView`
  that intercepts navigation to the (never-loaded) `return_to` URL, then the
  assertion is verified by POSTing `check_authentication` back to Steam.
  Claimed-ID host checks reject spoofed callbacks (unit-tested).
- **The Web API needs a developer key.** v1 ships it in a gitignored xcconfig
  → Info.plist. That's fine for personal builds; an App Store release should
  route Steam calls through a small proxy that holds the key server-side
  (also unlocks push-style refresh). Recorded as the main v2 item.
- **Privacy states are common.** Private profile, private friends list, and
  friends with private game details each have typed errors and designed
  empty states, not generic failures.

## Session & state

`AppModel.session`: `.restoring → .signedOut → .active(HomeModel)`. A
`HomeModel` is created per sign-in and owns its stores and `GameDataSource`;
sign-out discards it and wipes the cache — no cross-account leakage by
construction. The SteamID persists in the Keychain, not UserDefaults.

`GameDataSource` abstracts live vs demo. Demo mode (curated `SampleData`,
real appIDs so CDN art loads, seeded so it's stable, unlock dates relative to
now so streaks are alive) makes every screen fully explorable with no key and
no account — and it's what SwiftUI previews use.

## Design system — the Aurora language

- **Backgrounds:** `AuroraBackground` — a 3×3 MeshGradient whose interior
  points drift on a 20fps timeline and shift with scroll offset. Dusk
  palette in dark, dawn mist in light; `hero`/`celebration` intensities.
  Reduce-motion freezes it. Nothing in the app sits on a flat fill.
- **Shape:** no card rectangles. Surfaces are `glassChip` (capsule, circle,
  or continuous-corner blob of ultra-thin material with a frost stroke);
  most content floats unboxed, grouped by proximity (`FloatingSection`).
  Rings overlap artwork corners; perfect games wear gold coins and auras.
- **One completion language:** indigo → blue → teal as progress climbs;
  gold strictly reserved for perfection. Rarity palette
  (gray/green/blue/purple/gold) doubles as glow color.
- **Type:** editorial — 64pt rounded hero numerals with tight tracking,
  kerned uppercase caps-labels, 34pt rounded titles.
- **Motion:** springs only, choreographed. `.entrance(index:)` staggers
  every screen's first paint; rings sweep with a blurred glow halo; covers
  zoom into detail (`navigationTransition(.zoom)`); placeholders breathe
  instead of shimmer; press = 1.5–3% deform + soft haptic. The unlock
  celebration is the loudest moment in the app and still restrained: glow
  bloom, spring landing, staged haptics, drifting embers.
- **Illustration:** all programmatic (empty-state orbit motes, ember field,
  radar web) — one style, resolution-independent, scheme-adaptive.
- **Signature visuals:** the profile's genre radar hexagon (Canvas-free
  Shape with animatable expansion, tappable vertices) and the unlock
  celebration overlay.

## Testing

- `AchievementCore` carries the suite (~60 tests): engines, planner, cache,
  sync pipeline against a mock HTTP layer, OpenID (incl. hostile callbacks),
  DTO decoding of Steam's JSON quirks, sample-data invariants.
  Run: `cd AchievementCore && swift test` (any Mac; Linux also works).
- The app layer is deliberately thin: stores delegate math to engines, so UI
  testing is a simulator walk (checklist in README) rather than logic tests.

## Known gaps / v2

- **Server proxy** for the API key (App Store readiness).
- **Favourite genres** on Profile: needs the storefront `appdetails` endpoint
  (per-app, unauthenticated) — deferred to keep v1 sync lean.
- **Image caching**: `AsyncImage` has no disk cache; a custom `URLCache`-backed
  loader would help huge libraries on cold launches.
- App icon artwork; iPad layout; localization (schema strings currently
  requested in English); widgets ("streak" is a natural lock-screen widget).
