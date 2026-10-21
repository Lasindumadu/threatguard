import 'dart:async';

import 'package:flutter/services.dart';

import '../models/channel_profile.dart';
import '../models/message_source.dart';

/// One piece of text shared into ThreatGuard from another app.
class SharedIntake {
  final String text;
  final MessageSource source;

  /// The package that sent it, retained for display and for debugging a wrong
  /// channel guess.
  final String? sourcePackage;

  const SharedIntake({
    required this.text,
    required this.source,
    this.sourcePackage,
  });

  ChannelProfile get channel => ChannelProfile.of(source);

  String get originLabel => channel.displayName;
}

/// Receives text shared into the app from WhatsApp, Messenger, Instagram,
/// Gmail, a browser, or anything else with a share menu.
///
/// This is the honest way to "integrate" with those apps. They encrypt their
/// message stores and publish no read API, so an app that claims to read them
/// automatically is either using accessibility-service abuse or lying. The
/// share sheet gives the user explicit, per-message control over what gets
/// checked — which is also the stronger privacy story.
class SharedIntakeService {
  SharedIntakeService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel = methodChannel ?? const MethodChannel('threatguard/sms'),
       _eventChannel = eventChannel ?? const EventChannel('threatguard/share');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  final _controller = StreamController<SharedIntake>.broadcast();

  StreamSubscription<dynamic>? _subscription;

  Stream<SharedIntake> get intake => _controller.stream;

  /// Begins listening for shares that arrive while the app is alive.
  void start() {
    if (_subscription != null) return;

    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        final intake = _parse(event);
        if (intake != null) _controller.add(intake);
      },
      onError: (_) {
        // Sharing is unavailable if the platform channel is missing (web,
        // desktop, tests). The rest of the app keeps working.
      },
      cancelOnError: false,
    );
  }

  /// Collects a share that started the app, if any.
  ///
  /// Called once on launch: sharing into a cold app delivers the intent before
  /// Dart subscribes, so the pending payload is pulled explicitly rather than
  /// raced against.
  Future<SharedIntake?> consumePending() async {
    try {
      final raw = await _methodChannel.invokeMethod<dynamic>(
        'consumePendingShare',
      );
      return _parse(raw);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  SharedIntake? _parse(dynamic raw) {
    try {
      if (raw is! Map) return null;

      final text = raw['text'];
      if (text is! String || text.trim().isEmpty) return null;

      final package = raw['sourcePackage'];
      final referrer = raw['referrer'];
      final packageName = package is String
          ? package
          : referrer is String
          ? referrer
          : '';

      return SharedIntake(
        text: text.trim(),
        source: ChannelProfile.fromPackageName(packageName),
        sourcePackage: packageName.isEmpty ? null : packageName,
      );
    } catch (_) {
      // A malformed payload from a third-party share is not worth an error
      // boundary: there is simply nothing to check.
      return null;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
