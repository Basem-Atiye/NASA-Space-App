import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton_station/data/messages.dart';
import 'package:shackleton_station/ui/widgets/avatar.dart';
import 'package:shackleton_station/ui/widgets/common.dart';

void main() {
  testWidgets('HUD widgets render', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [
          AstronautAvatar(mood: Mood.happy, size: 60),
          StarRow(stars: 2),
          HudButton(label: 'POWER', icon: Icons.bolt_rounded),
        ]),
      ),
    ));
    expect(find.text('POWER'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
