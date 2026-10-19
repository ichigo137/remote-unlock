# RemoteUnlock

A Flutter Android dashboard plus a small Windows companion agent for authenticated remote PC locking.

## Current capabilities

- Dark, responsive Flutter dashboard.
- Lock the current Windows session from the Windows build.
- Android client can send an authenticated `lock` command to the Windows agent over HTTPS.
- Agent binds to `127.0.0.1` only and uses a 256-bit random bearer token.
- Unlock is deliberately not implemented: Windows protects interactive sign-in. Use Windows Hello/PIN or a trusted remote desktop tool to sign in.

## Build the Android app

```powershell
flutter pub get
flutter analyze
flutter build apk --debug
```

APK output: `build\app\outputs\flutter-apk\app-debug.apk`.

## Start the Windows agent

Requires Node.js on the Windows PC.

```powershell
cd C:\Users\roypa\remote_unlock\windows_agent
.\start-agent.ps1
```

On first run, the script creates `pairing-token.txt` with a random token and prints it to the console. Keep it secret. Do not commit or share it.

The agent listens on `127.0.0.1:8765` and supports only:

- `GET /health`
- `POST /command` with `Authorization: Bearer <token>` and JSON `{ "action": "lock" }`

## Secure remote access setup

Do **not** port-forward port 8765 or expose it directly to the public internet. For access from anywhere, use a private VPN such as Tailscale and its HTTPS Serve feature. Install/sign in to Tailscale on the PC and phone, then expose the local agent through Tailscale Serve (for example, `tailscale serve --bg 8765`, checking the current Tailscale CLI help for the supported syntax). Use the HTTPS hostname Tailscale provides in the Android app's pairing dialog, plus the token printed by `start-agent.ps1`.

The pairing token is held in app memory only and must be entered again after restarting the app. Android sends commands only to HTTPS URLs. The agent is not an internet relay by itself; a private HTTPS route must be configured before remote commands can work.

## Security notes

- Never use a weak or reused pairing token.
- Keep the PC and phone signed into your own private VPN tailnet.
- The agent intentionally has no unlock, shell, arbitrary-command, or file-access API.
- A `202 Accepted` response means the lock command was accepted by the agent, not independent proof that the screen visibly locked.
