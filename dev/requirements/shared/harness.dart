import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/world.dart';

import 'cases.dart';
import 'saga_animation.dart';

/// Phone-shaped test viewport: 375×812 logical — iPhone 13 mini, about the
/// smallest widely-used modern phone, so the UI is proven at a tight size.
/// Screen stills are captured at [viewportDpr]; saga animations override the
/// capture ratio with the smaller [sagaAnimationDpr] (shared/saga_animation.dart).
const Size viewportSize = Size(375, 812);
const double viewportDpr = 3.0;

bool _fontsLoaded = false;

/// Loads every real font the UI renders with, once per test process:
/// the bundled Roboto faces (declared in this package's pubspec) plus every
/// family in the merged FontManifest (MaterialIcons and any dependency
/// fonts). Without this, text renders as the glyph-less Ahem stub and icons
/// as boxes — goldens would be unreadable and unreviewable.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;

  final manifest = json.decode(
    utf8.decode(
      (await rootBundle.load('FontManifest.json')).buffer.asUint8List(),
    ),
  ) as List<dynamic>;

  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    // Strip the package prefix Flutter adds so styles using the plain
    // family name ('Roboto') resolve to the loaded font.
    final family = (entry['family'] as String).replaceFirst(
      RegExp(r'^packages/[^/]+/'),
      '',
    );
    final loader = FontLoader(family);
    for (final font in (entry['fonts'] as List<dynamic>)
        .cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// Sizes the test view like a phone, pumps [widget] wrapped in the
/// outermost [RepaintBoundary] the goldens capture, and restores the view
/// afterwards.
Future<void> pumpForGolden(WidgetTester tester, Widget widget) async {
  await loadAppFonts();
  tester.view.physicalSize = viewportSize * viewportDpr;
  tester.view.devicePixelRatio = viewportDpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(child: widget));
}

/// Captures the current frame against the committed golden at
/// `<kind>/cases/<name>.png` (paths resolve relative to `test/`, where the
/// runners live). With `flutter test --update-goldens` this writes the
/// golden instead — the regeneration path used by refresh_goldens.py.
Future<void> expectGolden(WidgetTester tester, String kind, String name) async {
  await expectLater(
    find.byType(RepaintBoundary).first,
    matchesGoldenFile('../$kind/cases/$name.png'),
  );
}

/// Standard fixed-duration settle: two frames for state propagation plus a
/// fixed animation window. NEVER `pumpAndSettle` — indeterminate progress
/// spinners animate forever and would hang the suite.
Future<void> settle(
  WidgetTester tester, [
  Duration duration = const Duration(milliseconds: 400),
]) async {
  await tester.pump();
  await tester.pump(duration);
}

/// Pumps the real app shell against [world]'s fakes — the standard entry
/// point for screen, saga, and behavior cases.
Future<void> pumpWorld(WidgetTester tester, FakeWorld world) async {
  await pumpForGolden(tester, world.buildApp());
  await settle(tester);
}

/// Runs a [ScreenCase] to its golden.
Future<void> runScreenCase(WidgetTester tester, ScreenCase c) async {
  final world = FakeWorld();
  c.arrange(world);
  await pumpForGolden(tester, (c.builder ?? (w) => w.buildApp())(world));
  await settle(tester, c.settle);
  if (c.act != null) {
    await c.act!(tester, world);
    await settle(tester, c.settle);
  }
  await expectGolden(tester, 'screen', '${c.slug}.${c.id}');
}

/// Runs a [SagaCase]: records the real UI's motion through every step into one
/// animated PNG (APNG) and compares it, by exact identity, to the committed
/// `saga/cases/<slug>.<id>.png`. See shared/saga_animation.dart.
Future<void> runSagaCase(WidgetTester tester, SagaCase c) async {
  final world = FakeWorld();
  c.arrange(world);
  await pumpWorld(tester, world);
  final recorder = SagaRecorder(region: c.region);
  await recorder.open(tester);
  for (final step in c.steps) {
    await recorder.step(tester, () => step.act(tester, world));
  }
  await recorder.compareOrUpdate(tester, '${c.slug}.${c.id}');
}
