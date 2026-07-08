/// Scripted fakes for every port (docs/UI-ARCHITECTURE.md §"The fake world").
///
/// Every fake both **scripts** (emit a fix, a feed update, an auth change;
/// make the next send fail or hang) and **records** (sends, deletes,
/// sign-outs, start/stop calls) so behavior cases assert on the recording.
///
/// Shipped inside the package so `dev/requirements/` can import it, but
/// never imported by `main.dart`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/feed_message.dart';
import '../ports/ports.dart';

/// A pinned, settable clock. `now()` returns the same instant until the test
/// sets it or calls [advance].
class FixedClock implements Clock {
  FixedClock(DateTime now) : _now = now;

  DateTime _now;

  @override
  DateTime now() => _now;

  set current(DateTime value) => _now = value;

  void advance(Duration delta) => _now = _now.add(delta);
}

/// Latest-value replay: every new listener immediately receives the most
/// recently emitted value (if any), then live updates — matching the
/// `authStateChanges` contract and Firestore snapshot behavior.
class _ReplayStream<T> {
  final List<StreamController<T>> _active = <StreamController<T>>[];
  bool _hasValue = false;
  late T _latest;

  bool get hasValue => _hasValue;

  T get latest => _latest;

  void add(T value) {
    _hasValue = true;
    _latest = value;
    for (final controller in List<StreamController<T>>.of(_active)) {
      controller.add(value);
    }
  }

  void addError(Object error) {
    for (final controller in List<StreamController<T>>.of(_active)) {
      controller.addError(error);
    }
  }

  Stream<T> get stream {
    late final StreamController<T> controller;
    controller = StreamController<T>(
      onListen: () {
        _active.add(controller);
        if (_hasValue) controller.add(_latest);
      },
      onCancel: () {
        _active.remove(controller);
      },
    );
    return controller.stream;
  }
}

/// Scripted [AuthPort]: tests emit auth states; taps on the sign-in button
/// are recorded and resolve against the script.
class FakeAuthPort implements AuthPort {
  FakeAuthPort({AppUser? initialUser}) {
    _states.add(initialUser);
  }

  final _ReplayStream<AppUser?> _states = _ReplayStream<AppUser?>();

  /// Script: the user a successful [signInWithGoogle] signs in as.
  AppUser? signInAs;

  /// Script: when set, [signInWithGoogle] throws this (a
  /// [SignInCanceledException] or [SignInException]) instead of signing in.
  /// Consumed by the next call.
  Object? signInError;

  /// Script: when set, [signInWithGoogle] stays in flight until the test
  /// completes it — freezes the busy spinner.
  Completer<void>? pendingSignIn;

  /// Recording.
  int signInWithGoogleCalls = 0;
  int signOutCalls = 0;

  /// The most recently emitted auth state.
  AppUser? get currentUser => _states.hasValue ? _states.latest : null;

  /// Script: emit an auth state (replayed to late listeners).
  void emitAuthState(AppUser? user) => _states.add(user);

  @override
  Stream<AppUser?> get authStateChanges => _states.stream;

  @override
  Future<void> signInWithGoogle() async {
    signInWithGoogleCalls++;
    final pending = pendingSignIn;
    if (pending != null) await pending.future;
    final error = signInError;
    if (error != null) {
      signInError = null;
      throw error;
    }
    emitAuthState(signInAs);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    emitAuthState(null);
  }
}

/// Scripted [LocationPort]: tests emit fixes and errors; [start]/[stop]
/// calls are recorded and otherwise do nothing.
class FakeLocationPort implements LocationPort {
  final ValueNotifier<GeoPosition?> _position =
      ValueNotifier<GeoPosition?>(null);
  final ValueNotifier<String?> _error = ValueNotifier<String?>(null);

  /// Recording.
  int startCalls = 0;
  int stopCalls = 0;

  @override
  ValueListenable<GeoPosition?> get position => _position;

  @override
  ValueListenable<String?> get error => _error;

  /// Script: emit a GPS fix (or null to lose the fix).
  void emitPosition(GeoPosition? value) => _position.value = value;

  /// Script: set (or clear, with null) the human-readable location problem.
  void emitError(String? message) => _error.value = message;

  @override
  Future<void> start() async {
    startCalls++;
  }

  @override
  void stop() {
    stopCalls++;
  }
}

/// One recorded [FakeMessagesPort.send] call.
class SendCall {
  const SendCall({required this.text, required this.kind, required this.at});

  final String text;
  final MessageKind kind;
  final GeoPosition at;
}

/// Scripted [MessagesPort]: tests emit feed snapshots; sends and deletes are
/// recorded. By default [send] succeeds deterministically and
/// [deleteFeedEntry] removes the entry from the latest feed and re-emits.
class FakeMessagesPort implements MessagesPort {
  final _ReplayStream<List<FeedMessage>> _feed =
      _ReplayStream<List<FeedMessage>>();

  /// Script: the `recipientCount` reported by successful default sends.
  int recipientCount = 0;

  /// Script: when set, [send] stays in flight until the test completes it —
  /// freezes the sending spinner.
  Completer<void>? pendingSend;

  /// Script: overrides the default send result — e.g.
  /// `onSend = (_) => throw const SendException('Too fast')`.
  Future<SendResult> Function(SendCall call)? onSend;

  /// Recording.
  final List<SendCall> sends = <SendCall>[];
  final List<String> deletes = <String>[];

  int _sendSeq = 0;

  /// The most recently emitted feed (empty if nothing emitted yet).
  List<FeedMessage> get latestFeed =>
      _feed.hasValue ? _feed.latest : const <FeedMessage>[];

  /// Script: emit a full feed snapshot, newest first (replayed to late
  /// listeners).
  void emitFeed(List<FeedMessage> messages) =>
      _feed.add(List<FeedMessage>.unmodifiable(messages));

  /// Script: break the feed stream (the UI's "Feed unavailable" state).
  void emitFeedError(Object error) => _feed.addError(error);

  @override
  Stream<List<FeedMessage>> feed() => _feed.stream;

  @override
  Future<SendResult> send({
    required String text,
    required MessageKind kind,
    required GeoPosition at,
  }) async {
    final call = SendCall(text: text, kind: kind, at: at);
    sends.add(call);
    final pending = pendingSend;
    if (pending != null) await pending.future;
    final override = onSend;
    if (override != null) return override(call);
    _sendSeq++;
    return SendResult(messageId: 'm$_sendSeq', recipientCount: recipientCount);
  }

  @override
  Future<void> deleteFeedEntry(String messageId) async {
    deletes.add(messageId);
    if (_feed.hasValue) {
      emitFeed(<FeedMessage>[
        for (final m in _feed.latest)
          if (m.messageId != messageId) m,
      ]);
    }
  }
}

/// Recording [PushPort]: push is fire-and-forget, so there is nothing to
/// script — only [init]/[stop] calls to assert on.
class FakePushPort implements PushPort {
  /// Recording.
  int initCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> init() async {
    initCalls++;
  }

  @override
  void stop() {
    stopCalls++;
  }
}
