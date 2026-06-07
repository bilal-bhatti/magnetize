# Magnetize

A macOS menu bar app that sends `magnet:` links straight to a remote Transmission
daemon over RPC. No browser extension, no third-party tools. Pure Swift compiled
with `swiftc` — no Xcode project.

```
browser click  →  Magnetize (menu bar)  →  Transmission RPC
   (magnet:)        URLSession + Keychain      (your host)
```

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

A magnet clicked before configuring is queued and sent once you save.

## Make Firefox use it

1. `about:config` → set `network.protocol-handler.expose.magnet` to `false`.
2. Restart Firefox.
3. Click a magnet → **Choose…** → `/Applications/Magnetize.app` → **Remember my
   choice** → **Open**.

## Source

| Path | Role |
|------|------|
| `Sources/Transmission.swift` | **The only file that touches the network.** |
| `Sources/MagnetizeApp.swift` | Entry point: menu bar + magnet URL handler. |
| `Sources/AppState.swift` | Config, credentials, recents, queue. |
| `Sources/*View.swift` | UI. |
| `build-app.sh` | Compiles & installs. |

## Reset

- Server URL: `defaults delete com.local.magnetize`
- Credentials: `security delete-generic-password -s magnetize`

## License

MIT — see [LICENSE](LICENSE).
