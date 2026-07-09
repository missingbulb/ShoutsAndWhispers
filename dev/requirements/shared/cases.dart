import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/world.dart';

/// The kind registry: **the folder is the kind.** Every kind directory under
/// `dev/requirements/` is named here; the coverage gate fails if a directory
/// with a `cases/` subfolder exists without a registry entry, or vice versa.
///
/// [KindImages.one] — the case's expected is exactly one committed golden
/// PNG beside it. [KindImages.animation] — exactly one committed
/// `<slug>.<id>.png`, but an *animated* PNG (APNG) recording the whole story
/// (see [SagaCase] and shared/saga_animation.dart). [KindImages.none] —
/// coded assertions only; a PNG in the folder is a defect (a screenshot
/// cannot verify a gesture or a pure rule).
enum KindImages { one, animation, none }

const Map<String, KindImages> kinds = <String, KindImages>{
  'screen': KindImages.one,
  'saga': KindImages.animation,
  'behavior': KindImages.none,
  'logic': KindImages.none,
};

/// Common shape of every case: the leaf it claims and its file slug.
/// The case file MUST be named `<slug>.<id>.case.dart`; the coverage gate
/// enforces the bijection between spec leaves, files on disk, and manifest
/// registrations.
abstract class RequirementCase {
  const RequirementCase({
    required this.id,
    required this.slug,
    required this.description,
  });

  /// The spec leaf this case claims, e.g. `'6.2'`.
  final String id;

  /// Kebab-case component slug, stable across section retitles.
  final String slug;

  /// One sentence: what this case demonstrates.
  final String description;

  String get caseFileName => '$slug.$id.case.dart';
}

/// A rendered resting state, pixel-compared against `<slug>.<id>.png`.
class ScreenCase extends RequirementCase {
  const ScreenCase({
    required super.id,
    required super.slug,
    required super.description,
    required this.arrange,
    this.act,
    this.builder,
    this.settle = const Duration(milliseconds: 400),
  });

  /// Scripts the fake world into the state under test (sign in, emit fix,
  /// seed feed…). Runs before the app is pumped.
  final void Function(FakeWorld world) arrange;

  /// Optional gesture folded into the snapshot (open a dialog, start a
  /// send). Runs after the first frame; the golden is taken afterwards.
  final Future<void> Function(WidgetTester tester, FakeWorld world)? act;

  /// Overrides the widget under test; defaults to the real app shell
  /// (`world.buildApp()`). Only for surfaces outside the shell (e.g. the
  /// setup-required screen).
  final Widget Function(FakeWorld world)? builder;

  /// Fixed post-arrange pump duration — never `pumpAndSettle`, which hangs
  /// on indeterminate spinners. The default outlives Material transitions.
  final Duration settle;
}

/// One step of a saga: a short caption naming what the step does, and the
/// action that advances the story. The recorder captures the UI's motion
/// after each step's [act] (see shared/saga_animation.dart). The caption
/// documents the step in the case file; it is the natural source if
/// per-segment subtitles are ever burned into the animation.
class SagaStep {
  const SagaStep(this.caption, this.act);

  final String caption;
  final Future<void> Function(WidgetTester tester, FakeWorld world) act;
}

/// A user story recorded as a single animated PNG (APNG) golden
/// `<slug>.<id>.png`: the real app shell driven step by step against the fake
/// world, with the UI's motion between states captured — not just the resting
/// frames. See shared/saga_animation.dart for capture, delay-shortening,
/// encoding, and the identity comparison.
class SagaCase extends RequirementCase {
  const SagaCase({
    required super.id,
    required super.slug,
    required super.description,
    required this.arrange,
    required this.steps,
    this.region,
  });

  /// Initial world state before the first frame's step runs.
  final void Function(FakeWorld world) arrange;

  final List<SagaStep> steps;

  /// Optional sub-region to record instead of the whole app — a [Finder]
  /// matching exactly one widget (e.g. `find.byType(AppBar)` for just the top
  /// bar). The full frame is captured and cropped to the finder's rect, so no
  /// extra `RepaintBoundary` is needed. Null (the default) records the whole
  /// app.
  final Finder? region;
}

/// A driven gesture asserted by code — what a static image cannot observe.
/// The whole test body is the case's [run]; expectations live inside it.
class BehaviorCase extends RequirementCase {
  const BehaviorCase({
    required super.id,
    required super.slug,
    required super.description,
    required this.run,
  });

  final Future<void> Function(WidgetTester tester, FakeWorld world) run;
}

/// A pure product rule verified against shipped code (no widget tree).
class LogicCase extends RequirementCase {
  const LogicCase({
    required super.id,
    required super.slug,
    required super.description,
    required this.verify,
  });

  final void Function() verify;
}
