import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/world.dart';

/// The kind registry: **the folder is the kind.** Every kind directory under
/// `dev/requirements/` is named here; the coverage gate fails if a directory
/// with a `cases/` subfolder exists without a registry entry, or vice versa.
///
/// [KindImages.one] — the case's expected is exactly one committed golden
/// PNG beside it. [KindImages.frames] — an ordered storyboard of
/// `*.step-NN.png` goldens. [KindImages.none] — coded assertions only; a
/// PNG in the folder is a defect (a screenshot cannot verify a gesture or a
/// pure rule).
enum KindImages { one, frames, none }

const Map<String, KindImages> kinds = <String, KindImages>{
  'screen': KindImages.one,
  'saga': KindImages.frames,
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

/// One step of a saga: a caption for the storyboard and the action that
/// advances the story. A golden frame is captured after each step.
class SagaStep {
  const SagaStep(this.caption, this.act);

  final String caption;
  final Future<void> Function(WidgetTester tester, FakeWorld world) act;
}

/// A user story rendered as an ordered storyboard of golden frames
/// `<slug>.<id>.step-NN.png`, one per step, driven against the fake world.
class SagaCase extends RequirementCase {
  const SagaCase({
    required super.id,
    required super.slug,
    required super.description,
    required this.arrange,
    required this.steps,
  });

  /// Initial world state before the first frame's step runs.
  final void Function(FakeWorld world) arrange;

  final List<SagaStep> steps;
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
