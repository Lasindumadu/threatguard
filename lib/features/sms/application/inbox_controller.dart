import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/models/message_source.dart';
import '../../../core/models/threat_message.dart';
import '../../../core/services/android_sms_message_source.dart';
import '../../../core/services/fake_sms_message_source.dart';
import '../../../core/services/local_store.dart';
import '../../../core/services/threat_engine.dart';

/// Owns the inbox state so screens stay presentational.
///
/// Previously all of this lived inside `_SmsInboxScreenState`, which meant the
/// classifier was rebuilt per screen, results were recomputed on every paint,
/// and the dashboard had no way to reuse any of it.
class InboxController extends ChangeNotifier {
  InboxController({ThreatEngine? engine, LocalStore? store})
    : engine = engine ?? ThreatEngine.instance,
      // ignore: prefer_initializing_formals
      _store = store;

  static const MethodChannel _smsChannel = MethodChannel('threatguard/sms');

  final ThreatEngine engine;

  /// Loaded asynchronously after construction, so it can be null briefly and
  /// can be replaced by [attachStore] once persistence is ready.
  LocalStore? _store;

  /// Kept as a named parameter for call-site clarity even though the field is
  /// private, which is why the initializing-formal lint is suppressed here.
  // ignore: prefer_initializing_formals

  final AndroidSmsMessageSource _messageSource =
      const AndroidSmsMessageSource();
  final FakeSmsMessageSource _demoMessageSource = const FakeSmsMessageSource();

  List<ThreatMessage> _messages = const [];
  bool _isLoading = false;
  bool _isDemoMode = false;
  bool _hasSmsPermission = false;
  bool _permissionPermanentlyDenied = false;
  String? _errorMessage;

  List<ThreatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isDemoMode => _isDemoMode;
  bool get hasSmsPermission => _hasSmsPermission;
  bool get permissionPermanentlyDenied => _permissionPermanentlyDenied;
  String? get errorMessage => _errorMessage;
  LocalStore? get store => _store;

  /// Reports for every scanned message, memoised by the engine.
  List<MessageThreatReport> get reports => engine.analyzeAll(_messages);

  /// Messages the user muted, filtered out of the inbox view.
  List<ThreatMessage> get visibleMessages {
    final muted = _store?.mutedSenders ?? const <String>{};
    if (muted.isEmpty) return _messages;

    return _messages
        .where((m) => !muted.contains(m.sender?.trim() ?? ''))
        .toList();
  }

  Future<void> attachStore(LocalStore store) async {
    _store = store;
    notifyListeners();
  }

  /// Whether the user's SMS channel toggle allows automatic inbox reading.
  ///
  /// Phase 1 finding: the SMS inbox was read even with SMS monitoring off. The
  /// engine then marked each message "not analysed", which is honest about the
  /// verdict but not about the behaviour: "do not monitor SMS" means do not
  /// read the inbox. Pasted and shared content is unaffected.
  bool get smsChannelEnabled =>
      engine.enabledChannels.contains(MessageSource.sms);

  Future<void> initialize() async {
    try {
      final hasPermission =
          await _smsChannel.invokeMethod<bool>('checkSmsPermission') ?? false;

      _hasSmsPermission = hasPermission;
      _permissionPermanentlyDenied = false;

      if (hasPermission && smsChannelEnabled) {
        await loadMessages();
      } else {
        notifyListeners();
      }
    } on PlatformException catch (error) {
      _errorMessage = error.message ?? 'Unable to check SMS permission.';
      notifyListeners();
    } on MissingPluginException {
      // Non-Android host (e.g. tests, desktop). Degrade gracefully.
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> requestPermission() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final granted =
          await _smsChannel.invokeMethod<bool>('requestSmsPermission') ?? false;

      if (granted) {
        _hasSmsPermission = true;
        _permissionPermanentlyDenied = false;
        _isLoading = false;
        notifyListeners();
        if (smsChannelEnabled) await loadMessages();
        return;
      }

      _permissionPermanentlyDenied =
          await _smsChannel.invokeMethod<bool>(
            'isSmsPermissionPermanentlyDenied',
          ) ??
          false;
      _hasSmsPermission = false;
      _isLoading = false;
      notifyListeners();
    } on PlatformException catch (error) {
      _isLoading = false;
      _errorMessage = error.message ?? 'Unable to request SMS permission.';
      notifyListeners();
    } on MissingPluginException {
      _isLoading = false;
      _errorMessage = 'SMS access is only available on Android.';
      notifyListeners();
    }
  }

  Future<void> openAppSettings() async {
    try {
      await _smsChannel.invokeMethod<void>('openAppSettings');
    } on PlatformException {
      _errorMessage = 'Unable to open app settings.';
      notifyListeners();
    } on MissingPluginException {
      // Nothing to open off-device.
    }
  }

  Future<void> loadMessages() async {
    if (!_hasSmsPermission) return;

    // The SMS toggle is an automatic-monitoring switch, and the inbox scan is
    // the only automatic reader this channel has.
    if (!smsChannelEnabled) {
      _messages = const [];
      _isLoading = false;
      _errorMessage =
          'SMS monitoring is off in Shield, so the inbox was not read. You can '
          'still paste or share a message to check it.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final messages = await _messageSource.readMessages();
      _messages = messages;
      _isDemoMode = false;
      _isLoading = false;
      engine.clearCache();
      notifyListeners();
    } on PlatformException catch (error) {
      _isLoading = false;
      _errorMessage = error.message ?? 'Unable to read SMS messages.';
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      _errorMessage = 'Unable to read SMS messages.';
      notifyListeners();
    }
  }

  Future<void> loadDemoMessages() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final messages = await _demoMessageSource.readMessages();
      _messages = messages;
      _isDemoMode = true;
      _isLoading = false;
      engine.clearCache();
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> muteSender(String sender) async {
    await _store?.muteSender(sender);
    notifyListeners();
  }

  Future<void> unmuteSender(String sender) async {
    await _store?.unmuteSender(sender);
    notifyListeners();
  }

  /// Adds an arbitrary message (e.g. pasted text) to the analysed set.
  void addMessage(ThreatMessage message) {
    _messages = [message, ..._messages];
    notifyListeners();
  }
}
