import 'package:flutter_test/flutter_test.dart';
import 'package:remote_unlock/main.dart';

void main() {
  testWidgets('RemoteUnlock dashboard renders', (tester) async {
    await tester.pumpWidget(const RemoteUnlockApp());
    expect(find.text('RemoteUnlock'), findsOneWidget);
    expect(find.text('LOCK MY PC'), findsOneWidget);
    expect(find.text('OPEN REMOTE DESKTOP'), findsOneWidget);
  });
}
