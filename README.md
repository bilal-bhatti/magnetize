# Magnetize

A tiny, auditable macOS handler for `magnet:` links. Click a magnet in any
browser and it's sent straight to a remote Transmission daemon over its RPC API
— no browser extension, no signing, no third-party tools.

## How it works

```
browser click  →  Magnetize.app  →  send-magnet.sh  →  Transmission RPC
   (magnet:)      (on open location)   (curl + keychain)   (your Transmission host)
```

- **`Magnetize.app`** (built from `handler.applescript`) is registered as a
  `magnet:` URL handler. Its only job: hand the URL to the script, then show the
  script's one-line result as a notification (posted by the app, so it carries
  Magnetize's own icon).
- **`send-magnet.sh`** is the whole engine — the only file that touches the
  network. It reads credentials from the macOS Keychain, does Transmission's
  session-id handshake, and POSTs a `torrent-add`.

## Files

| Path | Role |
|------|------|
| `handler.applescript` | The app's logic: receive magnet → run script → notify. |
| `send-magnet.sh`      | Talks to Transmission. **The one file to audit.** |
| `build-app.sh`        | Rebuilds & installs `Magnetize.app`. Re-run after edits. |
| `icon/draw-icon.swift`| Renders the app icon (AppKit, no dependencies). |

## Audit in one minute

1. `send-magnet.sh` — every `curl` targets `$HOST`; the password comes from the
   Keychain and is never written to disk.
2. `handler.applescript` — no networking; just runs the script and notifies.
3. The app does nothing else: it's a 6-line AppleScript applet.

## Configuration

- **Transmission RPC URL:** a plain one-line text file at
  `~/Library/Application Support/Magnetize/rpc-url`. Edit it to point at a
  different server — no rebuild needed. Delete it (or leave it empty) to be
  prompted for the URL on the next magnet click. If it's missing, first run
  prompts for the URL (pre-filled with a default) and saves it here.
- **Credentials:** stored in the macOS Keychain under service `magnetize`. First
  run with no stored credentials prompts for username/password and saves them;
  every run after is silent. Wrong credentials are detected, cleared, and
  re-prompted automatically. To reset manually:
  `security delete-generic-password -s magnetize`
- **Log (failures only):** `~/Library/Logs/Magnetize.log`

## Make Firefox use it

macOS's default magnet handler is still Transmission.app, and Firefox's normal
dialog won't let you pick another app, so force its chooser:

1. `about:config` → set **`network.protocol-handler.expose.magnet`** to `false`
   (create it as a Boolean if absent).
2. Restart Firefox.
3. Click any magnet → **Launch Application** dialog → **Choose…** →
   `/Applications/Magnetize.app` → check **Remember my choice** → **Open**.

## Rebuilding

After editing `handler.applescript` or regenerating the icon:

```bash
./build-app.sh
```

To regenerate the icon after editing `icon/draw-icon.swift`:

```bash
./icon/build-icon.sh   # rebuilds icon/Magnetize.icns
./build-app.sh         # installs it
```

## License

MIT — see [LICENSE](LICENSE).
