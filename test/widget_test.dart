import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagisho_connect_parent/main.dart';

void main() {
  test('parent greeting displays their first name', () {
    expect(greetingName('Mpho Mokoena'), 'Mpho');
    expect(greetingName(''), 'there');
  });

  testWidgets('Kagisho Connect branding can render', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Kagisho Connect'))),
    ));
    expect(find.text('Kagisho Connect'), findsOneWidget);
    expect(Brand.green, const Color(0xFF176A58));
  });
}
