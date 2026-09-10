import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovespace_app/theme/living_surface.dart';

void main() {
  testWidgets(
    'ambient motion runs without tapping, pauses, and respects reduced motion',
    (tester) async {
      Widget scene(bool reduced) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: const Scaffold(
            body: LivingSurface(child: SizedBox(width: 300, height: 180)),
          ),
        ),
      );
      await tester.pumpWidget(scene(false));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.tap(find.text('暂停氛围'));
      await tester.pumpAndSettle();
      expect(find.text('播放氛围'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.tap(find.text('播放氛围'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(scene(true));
      await tester.pumpAndSettle();
      expect(find.text('已跟随系统关闭动效'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
