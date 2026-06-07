# Magnetize

A macOS menu bar app that sends `magnet:` links and `.torrent` files straight to a
remote Transmission daemon over RPC. No browser extension, no third-party tools.
Pure Swift compiled with `swiftc` — no Xcode project.

```
browser click  →  Magnetize (menu bar)  →  Transmission RPC
   (magnet:)        URLSession + Keychain      (your host)
 .torrent file
 (Open With…)
```

Magnets and `.torrent` *URLs* are sent as a `filename` (Transmission fetches them
itself); downloaded `.torrent` *files* are read and sent as base64 `metainfo`, so
they reach Transmission even when it runs on another host.

## Build & install

```bash
./build-app.sh --install
```

Compiles `Sources/*.swift` into `Magnetize.app`, ad-hoc signs it, installs to
`/Applications`, and registers it as the `magnet:` handler. Omit `--install` to
build into `./build/` only. Re-run after editing `Sources/`, `Info.plist`, or the
icon.

Requires macOS 14+ and the Command Line Tools (`xcode-select --install`). No Apple
Developer account needed.

## Configure

First launch opens **Settings** (also reachable from the menu bar icon):

- **RPC URL** — `http://your-host:9091/transmission/rpc` (the only required field)
- **Username / Password** — optional; stored in the Keychain (service
  `magnetize`). Leave blank if your server runs without RPC auth.
- **Launch at login**

A magnet or torrent received before configuring is queued and sent once you save.

## Send a .torrent link from the clipboard

Browsers own `https://`, so a `.torrent` link won't route to Magnetize the way a
`magnet:` link does. Instead, **copy the link**, then open the menu bar icon and
click **Send torrent from clipboard** — Transmission downloads the `.torrent`
itself. The same item handles copied `magnet:` links.

## Open .torrent files with it

Magnetize registers as an *alternate* handler for `.torrent` files, so it won't
displace your default torrent app. To send one: right-click a `.torrent` in Finder
→ **Open With** → **Magnetize**. To always use it, pick **Get Info** → **Open
with: Magnetize** → **Change All…**.

## Make Firefox use it

1. `about:config` → set `network.protocol-handler.expose.magnet` to `false`.
2. Restart Firefox.
3. Click a magnet → **Choose…** → `/Applications/Magnetize.app` → **Remember my
   choice** → **Open**.

## Source

| Path | Role |
|------|------|
| `Sources/Transmission.swift` | **The only file that touches the network.** |
| `Sources/MagnetizeApp.swift` | Entry point: menu bar + magnet URL & file handlers. |
| `Sources/AppState.swift` | Config, credentials, recents, queue. |
| `Sources/TorrentSource.swift` | Unifies a magnet link and a .torrent file. |
| `Sources/*View.swift` | UI. |
| `build-app.sh` | Compiles & installs. |

## Reset

- Server URL: `defaults delete com.local.magnetize`
- Credentials: `security delete-generic-password -s magnetize`

## License

MIT — see [LICENSE](LICENSE).
