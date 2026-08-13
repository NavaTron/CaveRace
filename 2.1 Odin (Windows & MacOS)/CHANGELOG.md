# CaveRace 2.1 version history

## 2.1.0

- Initial release of the 2.1 edition: a from-scratch rewrite of CaveRace in
  [Odin](https://odin-lang.org/) using Odin's bundled
  [raylib](https://www.raylib.com/) bindings, for Windows and macOS.
- Carries over the original level files and pixel-art rules from the 2.0
  Windows Phone releases with a modern, cross-platform application loop.
- Updates the story, menus, outcome screens, and gameplay HUD for the native
  800x480 presentation.
- Adds animated story, menu, outcome, lava, bomb, destruction, enemy, pickup,
  and explosion effects, including a Reduced Flashes presentation path.
- Separates screen, gameplay-world, HUD, modal, and feedback rendering into an
  explicit layered pipeline.
- Corrects the Microsoft Store package identity, display name, and listing
  description in `AppxManifest.xml` (previously stale placeholders left over
  from an earlier product name), and points the website's Store badge at the
  correct listing.
- Corrects the macOS bundle identifier (`com.navatron.caverace2`, distinct
  from 1.5's `com.navatron.caverace`) in `Info.plist` and
  `CaveRace.entitlements`, and points the website's Mac App Store badge at
  the correct app listing.
- Verified production-readiness pass: strict-vetted release build, full test
  suite, and the macOS direct-distribution packaging script all run clean
  with no dead code, unused assets, or unreferenced packaging files found.
