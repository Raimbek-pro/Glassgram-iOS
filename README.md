<div align="center">
  <img src="https://raw.githubusercontent.com/Raimbek-pro/Glassgram/master/images/glassgram/icon.webp"
      width="125"
      height="125">

  <h2 align="center">Glassgram for iOS</h2>
  <p align="center">An unofficial Telegram client for iPhone with Liquid Glass message bubbles.</p>
</div>

**Glassgram** is a fork of [Telegram iOS](https://github.com/TelegramMessenger/Telegram-iOS) that redesigns message bubbles with Apple's Liquid Glass (`UIGlassEffect`, iOS 26). It is **not affiliated with or endorsed by Telegram**.

It is the iOS version of [Glassgram for macOS](https://github.com/Raimbek-pro/Glassgram).

## What's new in Glassgram

### Liquid Glass message bubbles
On iOS 26 and later, chat bubbles are glass instead of a solid color:

- **Clear glass** – the chat wallpaper shows through every bubble, lightly tinted with your theme's bubble color.
- **Bright glass rim** – a thin white edge, brightest at the top and fading along the sides, like light catching real glass.
- **Exact bubble shape** – glass and rim follow Telegram's bubble shape, tail and grouped corners included.
- **Follows your theme** – the glass uses the chat theme's dark or light style, so it stays dark and clear on dark wallpapers.
- **Short messages stay clear** – Liquid Glass renders short views as frosted "control" glass; Glassgram keeps the glass view at least 100 pt tall and cuts it to the bubble shape, so one-line messages look like long ones.
- **Tap highlight still works** – the normal highlighted bubble is shown while a message is selected.
- **Automatic fallback** – on iOS versions before 26, bubbles look the same as in Telegram.

### Settings → Glassgram
A new screen in Settings with:
- a **live preview** of an incoming and an outgoing glass bubble over your chat wallpaper,
- sliders for **Glass Tint** and **Rim Brightness** (top, sides, bottom),
- **Reset to Defaults**.

Changes apply instantly to the preview and to every open chat, and are saved on the device.

### Branding
- App name **Glassgram** (home screen, share sheet, widgets).
- Own app icon made with Icon Composer (`Telegram/Telegram-iOS/Glassgram.icon`).

## Where the code lives

| What | File |
|---|---|
| Glass bubble drawing | `submodules/ChatMessageBackground/Sources/ChatMessageBackground.swift` |
| Settings values, rim view, rim mask generation | `submodules/ChatMessageBackground/Sources/GlassBubbleSettings.swift` |
| Turning glass on per message (tint, dark mode) | `submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode/Sources/ChatMessageBubbleItemNode.swift` |
| Settings → Glassgram screen | `submodules/SettingsUI/Sources/Glassgram/GlassgramSettingsController.swift` |
| Settings row | `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoSettingsItems.swift` |
| App name and icon | `Telegram/BUILD` |

## Requirements

- iOS 26 for the glass effect (the app itself supports iOS 15+)
- Xcode 26 (Telegram pins an exact version in `versions.json`; see `--overrideXcodeVersion` below)
- [Git LFS](https://git-lfs.com) (`brew install git-lfs && git lfs install`)
- About **40 GB of free disk space** for the first build

## How to Build

### 1. Get the code

```
git clone --recursive -j8 https://github.com/Raimbek-pro/Glassgram-iOS.git
```

Two submodules use relative URLs and point at repositories that only exist under `TelegramMessenger`. If they fail to clone from the fork, point them at the originals locally and fetch them:

```
git config submodule.submodules/rlottie/rlottie.url https://github.com/TelegramMessenger/rlottie.git
git config submodule.submodules/TgVoipWebrtc/tgcalls.url https://github.com/TelegramMessenger/tgcalls.git
git submodule update --init --recursive
```

If `rlottie` fails with `not our ref`, the pinned commit is not public upstream. Check out the latest public commit instead:

```
git -C submodules/rlottie/rlottie fetch origin && git -C submodules/rlottie/rlottie checkout origin/master
```

Make sure no submodule folder is empty (for example `third-party/wallet-engine/wallet-engine`); if one is, run `git -C <path> checkout -f HEAD` after installing Git LFS.

### 2. Configure

1. Get your own `api_id` and `api_hash` at [my.telegram.org](https://my.telegram.org).
2. Find your Team ID: Keychain Access → your `Apple Development` certificate → **Organizational Unit**.
3. Copy `build-system/template_minimal_development_configuration.json` to a location **outside the repository** and fill in `bundle_id`, `api_id`, `api_hash` and `team_id`. **Never commit your `api_hash`.**

### 3. Generate the Xcode project

```
python3 build-system/Make/Make.py \
    --overrideXcodeVersion \
    --cacheDir="$HOME/telegram-bazel-cache" \
    generateProject \
    --configurationPath=path/to/your-configuration.json \
    --xcodeManagedCodesigning
```

The first run downloads Bazel and builds a lot; expect it to take an hour or more. Later runs are fast.

### 4. Run

Open `Telegram/Telegram.xcodeproj`, choose the **Telegram** scheme and an iPhone simulator, and press **⌘R**.

After adding new source files, re-run step 3 so Xcode's editor knows about them (the build itself picks them up automatically).

### Troubleshooting

- **"build-request.json not updated yet"** – cancel the build and start it again.
- **`assert(resultCode)` in `SqliteValueBox.swift` / "No space left on device"** – the disk is full. Free space, then remove the app from the simulator and run again.
- **`Telegram_xcodeproj: no such package`** after a restart – re-run step 3.

## License

Glassgram is licensed under the GNU General Public License, version 2.0, like Telegram iOS. See [LICENSE](LICENSE).

## Credits

Based on [Telegram iOS](https://github.com/TelegramMessenger/Telegram-iOS). Following Telegram's requirements for third-party apps, Glassgram uses its own API ID, its own name and icon (not the Telegram logo), follows Telegram's [security guidelines](https://core.telegram.org/mtproto/security_guidelines), and publishes its full source code here.

Bugs and ideas for Glassgram: [open an issue](https://github.com/Raimbek-pro/Glassgram-iOS/issues). Please don't report Glassgram bugs to Telegram.
