import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() => runApp(const RemoteUnlockApp());

const ink = Color(0xFF090B13);
const panel = Color(0xFF131725);
const violet = Color(0xFF8B7CFF);
const mint = Color(0xFF66E5C0);
const muted = Color(0xFF9299B2);

class RemoteUnlockApp extends StatelessWidget {
  const RemoteUnlockApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'RemoteUnlock',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ink,
      colorScheme: ColorScheme.fromSeed(seedColor: violet, brightness: Brightness.dark),
      useMaterial3: true,
      fontFamily: 'Segoe UI',
    ),
    home: const Dashboard(),
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool connected = false;
  bool busy = false;
  String status = 'Not paired';
  String pcName = 'MY WINDOWS PC';
  final endpoint = TextEditingController();
  final secret = TextEditingController();

  bool get isWindows => !kIsWeb && Platform.isWindows;

  String relayUrl = '';
  String authToken = '';

  Future<void> lockPc() async {
    if (busy) return;
    if (isWindows) {
      setState(() => busy = true);
      try {
        await Process.run('rundll32.exe', ['user32.dll,LockWorkStation']);
        if (mounted) {
          setState(() { status = 'Lock command sent'; busy = false; });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Windows lock command sent.')));
        }
      } catch (_) {
        if (mounted) setState(() { busy = false; status = 'Command failed'; });
      }
      return;
    }
    if (relayUrl.isEmpty || authToken.isEmpty) { _showPairDialog(); return; }
    setState(() => busy = true);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse('${relayUrl.replaceFirst(RegExp(r'/+$'), '')}/command');
      if (uri.scheme != 'https') throw const FormatException('HTTPS is required');
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
      request.headers.contentType = ContentType.json;
      request.write('{"action":"lock"}');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) throw HttpException('Relay rejected command (${response.statusCode}): $body');
      if (mounted) {
        setState(() { status = 'Lock command accepted'; busy = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PC agent accepted the lock command.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() { status = 'Connection failed'; busy = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not reach your PC: $e')));
      }
    } finally { client.close(force: true); }
  }

  void _showPairDialog() {
    endpoint.text = relayUrl;
    secret.text = authToken;
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: panel,
      title: const Text('Pair your Windows PC'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Enter your PC agent’s HTTPS address and the shared token configured on that PC. Keep the endpoint private; HTTPS is required.', style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
        const SizedBox(height: 16),
        TextField(controller: endpoint, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'HTTPS endpoint', hintText: 'https://your-pc.example.ts.net', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: secret, obscureText: true, decoration: const InputDecoration(labelText: 'Pairing token', border: OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          final url = endpoint.text.trim(); final token = secret.text.trim();
          final uri = Uri.tryParse(url);
          if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || token.length < 24) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use a valid HTTPS URL and a token of at least 24 characters.'))); return;
          }
          Navigator.pop(ctx);
          setState(() { relayUrl = url; authToken = token; connected = true; status = 'Paired (not yet tested)'; });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pairing details saved in app memory. Test by sending a lock command.')));
        }, child: const Text('Save pairing')),
      ],
    ));
  }

  void _showUnlockInfo() {
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: panel,
      title: const Text('Windows sign-in stays secure'),
      content: const Text('Windows intentionally protects the lock screen from third-party remote unlock commands. This app does not bypass sign-in or collect your password. To regain access, use Windows Hello/PIN, or set up Windows Remote Desktop or another trusted remote-access tool.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood'))],
    ));
  }

  @override
  void dispose() { endpoint.dispose(); secret.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 680;
    return Scaffold(
      body: Stack(children: [
        Positioned(top: -150, right: -100, child: _glow(300, violet.withValues(alpha: .18))),
        Positioned(bottom: -160, left: -100, child: _glow(320, const Color(0xFF36BDA0).withValues(alpha: .10))),
        SafeArea(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(22, 18, 22, 28), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(colors: [Color(0xFF9B8EFF), Color(0xFF6555E8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: violet.withValues(alpha: .25), blurRadius: 24, offset: const Offset(0, 8))]),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 25)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('RemoteUnlock', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                  Text('YOUR PC. YOUR CONTROL.', style: TextStyle(fontSize: 9, letterSpacing: 2.1, color: muted, fontWeight: FontWeight.w700)),
                ])),
                IconButton(onPressed: _showPairDialog, icon: const Icon(Icons.tune_rounded, color: muted), tooltip: 'Connection settings'),
              ]),
              const SizedBox(height: 34),
              Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: connected ? mint : const Color(0xFFFFC46B), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(connected ? 'PAIRING CONFIGURED' : 'AWAITING CONNECTION', style: const TextStyle(color: muted, fontSize: 10, letterSpacing: 1.7, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              Text('Your desk,\nfrom anywhere.', style: TextStyle(fontSize: wide ? 46 : 39, height: 1.06, letterSpacing: -1.8, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 12),
              const Text('A calmer way to manage your Windows PC remotely.', style: TextStyle(color: muted, fontSize: 14, height: 1.5)),
              const SizedBox(height: 26),
              _pcCard(),
              const SizedBox(height: 18),
              if (wide) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _actionCard()),
                const SizedBox(width: 16),
                Expanded(child: _securityCard()),
              ]) else Column(children: [_actionCard(), const SizedBox(height: 16), _securityCard()]),
              const SizedBox(height: 24),
              Row(children: [
                const Icon(Icons.bolt_rounded, color: violet, size: 18),
                const SizedBox(width: 8),
                const Text('QUICK STATUS', style: TextStyle(fontSize: 10, letterSpacing: 1.8, fontWeight: FontWeight.w800, color: muted)),
                const Spacer(),
                Text(isWindows ? 'DESKTOP PREVIEW' : 'ANDROID CLIENT', style: const TextStyle(fontSize: 9, letterSpacing: 1.1, color: muted)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _metric(Icons.lock_outline_rounded, 'Lock state', isWindows ? 'Ready' : 'Unknown', violet)),
                const SizedBox(width: 10),
                Expanded(child: _metric(Icons.wifi_rounded, 'Relay', connected ? 'Online' : 'Offline', mint)),
                const SizedBox(width: 10),
                Expanded(child: _metric(Icons.shield_outlined, 'Security', 'Protected', const Color(0xFFFFC46B))),
              ]),
              const SizedBox(height: 26),
              Center(child: Text('REMOTEUNLOCK  •  PRIVATE BY DESIGN', style: TextStyle(color: muted.withValues(alpha: .65), fontSize: 9, letterSpacing: 1.6))),
            ],
          )),
        ))),
      ]),
    );
  }

  Widget _pcCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Colors.white.withValues(alpha: .09)),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF20243A), Color(0xFF121624), Color(0xFF111521)]),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .2), blurRadius: 35, offset: const Offset(0, 15))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: violet.withValues(alpha: .13), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.desktop_windows_rounded, color: violet, size: 24)),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PRIMARY DEVICE', style: TextStyle(fontSize: 9, color: muted, letterSpacing: 1.8, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('Windows workstation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(20)), child: Text(isWindows ? 'THIS PC' : 'UNPAIRED', style: const TextStyle(fontSize: 9, color: muted, letterSpacing: 1, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 24),
      Container(height: 1, color: Colors.white.withValues(alpha: .07)),
      const SizedBox(height: 18),
      Row(children: [
        const Icon(Icons.circle, size: 7, color: Color(0xFFFFC46B)),
        const SizedBox(width: 8),
        Expanded(child: Text(isWindows ? 'Local Windows control available' : 'Waiting for secure pairing', style: const TextStyle(fontSize: 12, color: Color(0xFFD5D8E6)))),
        Text(status.toUpperCase(), style: const TextStyle(fontSize: 9, color: muted, letterSpacing: .8)),
      ]),
    ]),
  );

  Widget _actionCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: panel.withValues(alpha: .92), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: .07))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('POWER & ACCESS', style: TextStyle(fontSize: 10, letterSpacing: 1.7, color: muted, fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      const Text('Take control', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -.5)),
      const SizedBox(height: 6),
      const Text('Lock your workstation or review access options.', style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
      const SizedBox(height: 18),
      SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(
        onPressed: busy ? null : lockPc,
        icon: busy ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.lock_rounded, size: 18),
        label: Text(busy ? 'SENDING COMMAND…' : 'LOCK MY PC', style: const TextStyle(fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w800)),
        style: FilledButton.styleFrom(backgroundColor: violet, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
      )),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(
        onPressed: _showUnlockInfo,
        icon: const Icon(Icons.key_rounded, size: 17),
        label: const Text('UNLOCK / SIGN-IN OPTIONS', style: TextStyle(fontSize: 10, letterSpacing: .8, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFD4D0FF), side: BorderSide(color: violet.withValues(alpha: .35)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
      )),
      const SizedBox(height: 10),
      const Text('Windows sign-in remains protected. This app will never store or transmit your Windows password.', style: TextStyle(color: muted, fontSize: 10, height: 1.5)),
    ]),
  );

  Widget _securityCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: panel.withValues(alpha: .92), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: .07))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: mint.withValues(alpha: .11), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.verified_user_rounded, color: mint, size: 20)), const SizedBox(width: 11), const Expanded(child: Text('Security by design', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)))]),
      const SizedBox(height: 16),
      _checkLine('Authenticated device pairing'),
      const SizedBox(height: 12),
      _checkLine('Encrypted transport required'),
      const SizedBox(height: 12),
      _checkLine('No Windows password stored'),
      const SizedBox(height: 12),
      _checkLine('Commands must be verified'),
      const SizedBox(height: 17),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: mint.withValues(alpha: .07), borderRadius: BorderRadius.circular(14)), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline_rounded, color: mint, size: 17), SizedBox(width: 9), Expanded(child: Text('Remote control activates after a trusted relay and PC agent are configured.', style: TextStyle(color: Color(0xFFB8DAD2), fontSize: 11, height: 1.5)))])),
    ]),
  );

  Widget _checkLine(String label) => Row(children: [const Icon(Icons.check_circle_rounded, color: mint, size: 16), const SizedBox(width: 9), Expanded(child: Text(label, style: const TextStyle(color: Color(0xFFD1D5E5), fontSize: 12)))]);
  Widget _metric(IconData icon, String title, String value, Color accent) => Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: panel.withValues(alpha: .75), borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withValues(alpha: .06))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: accent, size: 18), const SizedBox(height: 13), Text(title, style: const TextStyle(color: muted, fontSize: 10)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))]));
  Widget _glow(double size, Color color) => ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40), child: Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle)));
}
