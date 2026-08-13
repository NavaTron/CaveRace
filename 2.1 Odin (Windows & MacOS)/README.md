# CaveRace 2.1

CaveRace 2.1 is the modern desktop edition of **CaveRace 2**, the larger
campaign first released with the 2.0 Windows Phone version. It is a from-scratch rewrite
in [Odin] using Odin's bundled [raylib] bindings and runs on current Windows
and macOS systems.

Enter the mines of Eldora, collect treasure, blast through soft rock, and
destroy every alien to clear each cave. Bombs also destroy treasure and
power-ups—and can hurt the player—so every placement needs an escape route.

The game is completely offline. It has *no* accounts, advertising, in-app
purchases, analytics, or online services.

## What is included

- A 25-cave campaign: Intro, five Forest caves, five Desert caves, five Winter
  caves, eight Lava caves, and End
- The original 2.0 level data and pixel-art rules in a new cross-platform
  application
- An animated story sequence, interactive tutorial, menus, HUD, result
  screens, audio, and visual effects designed for an 800×480 canvas
- Standard and Assisted difficulty profiles
- Per-cave score summaries and Bronze, Silver, or Gold medals based on
  treasure collection and completion time
- Keyboard, mouse, and controller support, including remappable keyboard and
  controller actions
- Windowed and borderless display modes at 1×, 2×, or 3× scale
- Music and sound volume, screen shake, controller rumble, reduced flashes,
  high-contrast bomb previews, and pause-on-focus-loss settings
- Automatic gameplay demonstrations after one minute of inactivity on the
  main menu
- Local settings storage with safe defaults when no valid settings file exists

Version 2.1.0 is the initial 2.1 release. See the [version history](CHANGELOG.md)
for its release notes.

## System requirements

| Platform | Minimum version | Architecture |
| --- | --- | --- |
| Windows | Windows 10 version 1809 | x86-64 |
| macOS | macOS 10.15 Catalina | Intel or Apple silicon |

A keyboard is sufficient. A mouse or compatible game controller is optional.

## Install and play

Download CaveRace 2 for Windows or macOS from the
[official CaveRace website](https://caverace.com/).

- **macOS:** move `CaveRace 2.app` to Applications and open it normally.
- **Windows:** keep `CaveRace.exe`, `media/`, and `levels/` together in the
  distribution directory. A Microsoft Store installation manages those files
  automatically.

### Default controls

| Input | Action |
| --- | --- |
| WASD or arrow keys | Move; navigate menus |
| Controller D-pad or left stick | Move; navigate menus |
| Space or controller A | Place a bomb; confirm; skip the current story panel |
| Enter | Confirm menu and result-screen actions |
| R or controller X | Retry after death; start over after game over |
| P or controller Start | Open or close the pause menu |
| Escape or controller B | Go back; open pause and abandon-run confirmation during play |
| Mouse pointer and left button | Select and activate menu items |
| Mouse wheel | Navigate menus or change a selected setting |
| Right mouse button | Go back |

Movement, Bomb, Confirm, Pause, and Restart bindings can be changed in
Settings. Arrow keys and the controller's left stick always remain movement
fallbacks; Escape and controller B are reserved for Back.

### Demo mode

After one minute without input on the main menu, the game starts a one-minute
automated demonstration. Demos alternate between the first two campaign caves
and use the selected difficulty with the same rules and starting stats as a
normal run. Any keyboard key, controller action, or mouse click returns to the
main menu.

The idle timer runs only on the main menu and pauses while the window is not
focused.

### Launch option

The executable accepts one optional compatibility switch:

| Option | Purpose |
| --- | --- |
| `-powerblast` | Enable the original F1–F5 cheat keys |

Unknown arguments are reported and ignored.

With `-powerblast` enabled:

| Key | Result |
| --- | --- |
| F1 | Destroy every enemy and complete the current cave |
| F2 | Restore four lives and eight energy |
| F3 | Grant capacity for four simultaneous bombs |
| F4 | Increase bomb power, up to 10 |
| F5 | Double the current score |

## Build from source

Install a current [Odin compiler]. A separate raylib installation is not
needed: the project imports `vendor:raylib` from the Odin distribution.

Run development commands from `source/`:

```sh
cd source
odin run .
```

Run the automated tests from the same directory:

```sh
odin test .
```

The tests cover movement behavior, presentation invariants, effect bounds,
and validation of all shipped campaign levels.

### Direct-distribution packages

Run the packaging command from this `2.1 Odin (Windows & MacOS)` directory.

macOS:

```sh
./scripts/build_macos.sh release
```

Windows PowerShell:

```powershell
.\scripts\build_windows.ps1 release
```

Artifacts are written to `dist/macos/CaveRace 2.app` and `dist/windows/`.
Pass `debug` instead of `release` for a checked debug build.

The macOS script can sign and notarize the app when
`CAVERACE_SIGN_IDENTITY` and `CAVERACE_NOTARY_PROFILE` are set. The Windows
script can Authenticode-sign the executable when
`CAVERACE_WINDOWS_CERT_SHA1` is set.

### Store packages

Mac App Store:

```sh
./scripts/build_macos_appstore.sh release
```

This builds a universal Intel/Apple-silicon `CaveRace 2.pkg` in
`dist/macos-appstore/`. The script requires these environment variables:

- `CAVERACE_APPSTORE_SIGN_IDENTITY`
- `CAVERACE_APPSTORE_INSTALLER_IDENTITY`
- `CAVERACE_APPSTORE_PROVISIONING_PROFILE`

Microsoft Store:

```powershell
.\scripts\build_windows_store.ps1 release
```

This creates `dist/windows-store/CaveRace2_2.1.0.0_x64.msix`. It requires the
Windows SDK; the package identity in
`packaging/windows-store/AppxManifest.xml` must match Partner Center. The
Microsoft Store signs the submitted package during certification.

Every packaging script compiles with strict Odin vetting and warnings treated
as errors, copies the required media and levels, and checks the essential
package contents before finishing.

## Repository layout

| Path | Contents |
| --- | --- |
| `source/` | Odin game, rendering, input, audio, settings, and test code |
| `source/levels/` | The 25 preserved 1,625-byte campaign level files |
| `source/media/` | Screens, sprites, tiles, effects, music, and sounds |
| `icons/` | Source application icons at common raster sizes |
| `packaging/` | macOS bundle metadata and Windows resources/Store manifest |
| `scripts/` | Direct-distribution and Store build automation |
| `dist/` | Generated packages and local build output |

The original level files are treated as immutable map data. Loading validates
their structure before live player, enemy, bomb, and explosion state is
created separately.

## Display behavior

CaveRace 2 uses a fixed 800×480 canvas to preserve the composition and pixel
art. Other aspect ratios are scaled proportionally and centered with black
letterboxing instead of stretching or reflowing the game.

## Privacy, support, and license

The Store privacy policy is available at
[navatron.com/privacy](https://navatron.com/privacy/). For game information
and support, visit the [official CaveRace website](https://caverace.com/).

NavaTron Game Studios. Copyright © 1997–2026 NavaTron B.V.

The source code is licensed under the [Apache License 2.0](../LICENSE). Game
content, artwork, music, and sound effects remain copyright NavaTron B.V.

[Odin]: https://odin-lang.org/
[Odin compiler]: https://odin-lang.org/docs/install/
[raylib]: https://www.raylib.com/
