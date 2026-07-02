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
