import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ILECO PAY test environment works', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('ILECO PAY'),
          ),
        ),
      ),
    );

    expect(find.text('ILECO PAY'), findsOneWidget);
  });
}
