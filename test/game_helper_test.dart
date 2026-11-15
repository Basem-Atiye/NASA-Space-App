import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton_station/ui/game_helper.dart';

void main() {
  testWidgets('global astronaut opens, answers and closes with an overlay', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => Overlay.wrap(child: GameHelper(reducedMotion: true, child: child!)),
      home: const Scaffold(body: GameText('Oxygen and radiation')),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('astronaut-help')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Astronaut guide'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'oxygen');
    await tester.tap(find.byTooltip('Send question'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(gameGlossary['oxygen']!), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final word in ['battery', 'the', 'water', 'electrolyser', 'electrolyzer']) {
      await tester.enterText(find.byType(TextField), 'What does $word mean?');
      await tester.tap(find.byTooltip('Send question'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(gameGlossary[word]!), findsWidgets);
      expect(tester.takeException(), isNull);
    }
    await tester.enterText(find.byType(TextField), 'What are electrolysers?');
    await tester.tap(find.byTooltip('Send question'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(gameGlossary['electrolyser']!), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close game help'));
    await tester.pump();
    expect(find.text('Astronaut guide'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
