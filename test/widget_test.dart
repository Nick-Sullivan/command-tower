import 'package:flutter_test/flutter_test.dart';

import 'package:mtg_life_tracker/main.dart';

void main() {
  testWidgets('shows Hello World', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Hello World'), findsOneWidget);
  });
}
