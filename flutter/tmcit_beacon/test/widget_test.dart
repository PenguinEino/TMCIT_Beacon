// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:tmcit_beacon/main.dart';

void main() {
  testWidgets('Beacon dashboard renders initial state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BeaconApp());

    expect(find.text('iBeacon モニタ'), findsOneWidget);
    expect(find.textContaining('ステータス: 待機中'), findsOneWidget);
    expect(find.text('ビーコン検出を開始'), findsOneWidget);

    // Ensure the detected tab exists and can be switched to.
    await tester.tap(find.text('検出一覧'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('UUID 4b206330-cf87-4d78-b460-acc3240a4777'),
      findsOneWidget,
    );
  });
}
