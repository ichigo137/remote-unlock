# RemoteUnlock

A Flutter Android app and lightweight Windows agent for remotely locking your own Windows session through a hosted Supabase relay, with a safe hand-off to Chrome Remote Desktop for full remote control and normal Windows sign-in.

## Architecture

- Android sends a lock request to a Supabase Edge Function over HTTPS.
- The Edge Function authenticates the command secret and stores a short-lived command in a private database queue.
- The Windows agent makes outbound HTTPS polls every 10 seconds and claims pending commands.
- The Windows agent opens **no listening port**. No router port forwarding or Tailscale Serve is required.
- The agent supports only the `lock` action. It cannot unlock Windows or execute arbitrary commands.
- The Android app's **Open Remote Desktop** action opens Chrome Remote Desktop in the external browser. Remote desktop video/input is provided by that trusted service, not by the Supabase command relay.

The laptop must be awake, connected to the internet, and running the small Windows agent to receive lock commands. The app does not need to be open on the laptop. A command expires after 2 minutes if the agent doesn't collect it. Chrome Remote Desktop must be configured separately for full remote access; the PC must be powered on and online.

## Remote desktop setup (Windows 11 Home)

Windows Home cannot host Microsoft's built-in Remote Desktop service. Use [Chrome Remote Desktop](https://remotedesktop.google.com/access), which supports Windows hosts and mobile clients.

1. While signed in locally on the Windows PC, open `https://remotedesktop.google.com/access` in Chrome.
2. Sign in with the Google account you control, choose **Set up remote access**, and install the official Chrome Remote Desktop host when prompted.
3. Complete Google's host registration and choose a strong access PIN. Do not share the Google account or PIN.
4. On Android, sign in to the same Google account in Chrome Remote Desktop (or open the **Open Remote Desktop** action in this app and continue in the browser).
5. Select your PC, enter the Chrome Remote Desktop PIN, and connect. If Windows is at its sign-in screen, enter your normal Windows PIN/password there.

The app does not store your Windows password, Google credentials, or Chrome Remote Desktop PIN. The app only opens the trusted remote-access page; the actual remote screen and input are handled by Chrome Remote Desktop. First-time host setup requires your interactive Google sign-in and consent and cannot safely be completed by this app on your behalf.

## Cloud setup

You need an active Supabase project. The current account must have access to that project before deployment.

1. Install the [Supabase CLI](https://supabase.com/docs/guides/cli) and sign in:

   ```powershell
   supabase login
   ```

2. From this repository, link the project (replace the placeholder with your project ref):

   ```powershell
   supabase link --project-ref YOUR_PROJECT_REF
   ```

3. Create the two random secrets and local agent configuration:

   ```powershell
   .\setup-cloud-secrets.ps1
   ```

   The script creates `cloud-secrets.json` and `cloud-secrets.env`. Both are excluded from Git. It prints the command secret for the Android app. Never commit or share these files.

4. Apply the database migration and set Edge Function secrets:

   ```powershell
   supabase db push
   supabase secrets set --env-file ./cloud-secrets.env
   ```

5. Deploy the Edge Function with JWT verification disabled at the gateway. The function performs its own constant-time shared-secret checks:

   ```powershell
   supabase functions deploy remoteunlock --no-verify-jwt
   ```

6. In Supabase Dashboard, open **Project Settings → API Keys** and copy the **publishable key**. The function endpoint is:

   ```text
   https://YOUR_PROJECT_REF.supabase.co/functions/v1/remoteunlock
   ```

7. Run `.\setup-cloud-secrets.ps1` again and paste the function endpoint and publishable key when prompted. It reuses existing secrets and writes the ignored local file `windows_agent\agent-config.json`.

## Start the Windows agent

Requires Node.js 18 or newer.

```powershell
cd C:\Users\YOUR_USER\remote_unlock\windows_agent
.\start-agent.ps1
```

The agent polls the hosted relay every 10 seconds and only executes `rundll32.exe user32.dll,LockWorkStation` for a valid `lock` command. It does not accept incoming network connections, arbitrary shell commands, unlock requests, or file-access requests.

To use the Android app, open **Connection settings** and enter:

- **Supabase Edge Function URL:** the full URL ending in `/functions/v1/remoteunlock`
- **Supabase publishable key:** the public project key from the dashboard
- **Command secret:** the value printed by `setup-cloud-secrets.ps1`

The app keeps pairing details in memory only; you'll need to enter them again after restarting the app.

## Build and verify

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

APK output: `build\app\outputs\flutter-apk\app-debug.apk`.

## Security notes

- Keep the command and device secrets private and different from each other.
- Never expose a Supabase service-role/secret key in the Android app.
- The database queue has RLS enabled and denies direct access to client roles; only the Edge Function's server-side key accesses it.
- Lock commands expire after two minutes and can only request a lock.
- Remote desktop authentication is handled separately by Google and Windows; do not add Windows credentials to the relay or app.
- The publishable key is designed for client use; it is not a substitute for the command secret.
- A successful queue response means the command was accepted by the cloud, not proof that Windows visibly locked.
- The Windows agent must be running for the command to be delivered. The hosted relay removes the local HTTP server and inbound port, but cannot operate a powered-off PC.
