import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/threat_analysis.dart';
import '../../../../core/services/threat_engine.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/threat_widgets.dart';
import '../../application/inbox_controller.dart';
import 'sms_detail_screen.dart';

/// Which subset of the inbox is shown.
enum InboxFilter { all, highRisk, suspicious, safe }

/// The analysed inbox: search, filter, sort, and a risk-first reading order.
class SmsInboxScreen extends StatefulWidget {
  final InboxController controller;

  const SmsInboxScreen({super.key, required this.controller});

  @override
  State<SmsInboxScreen> createState() => _SmsInboxScreenState();
}

class _SmsInboxScreenState extends State<SmsInboxScreen> {
  final TextEditingController _searchController = TextEditingController();

  InboxFilter _filter = InboxFilter.all;
  String _query = '';
  bool _worstFirst = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    if (controller.isLoading && controller.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage != null && controller.messages.isEmpty) {
      return _buildError();
    }

    if (!controller.hasSmsPermission && !controller.isDemoMode) {
      return _buildPermissionRequest();
    }

    if (controller.messages.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: 'No messages found',
        message: 'ThreatGuard could not find any SMS messages on this device.',
        actions: [
          FilledButton.icon(
            onPressed: controller.loadMessages,
            icon: const Icon(Icons.refresh),
            label: const Text('Scan again'),
          ),
        ],
      );
    }

    final entries = _buildEntries();

    return Column(
      children: [
        _buildToolbar(context, entries.length),
        if (controller.isDemoMode) _demoBanner(context),
        Expanded(
          child: entries.isEmpty
              ? EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'Nothing matches',
                  message: 'No messages match the current filter or search.',
                  actions: [
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _filter = InboxFilter.all;
                        });
                      },
                      child: const Text('Clear filters'),
                    ),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: controller.loadMessages,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: entries.length,
                    itemBuilder: (context, index) =>
                        _messageCard(entries[index]),
                  ),
                ),
        ),
      ],
    );
  }

  /// Applies search, filter and sort to produce the visible ordering.
  List<MessageThreatReport> _buildEntries() {
    final controller = widget.controller;
    final muted = controller.store?.mutedSenders ?? const <String>{};

    var reports = controller.reports
        .where((report) {
          final sender = report.message.sender?.trim() ?? '';
          return !muted.contains(sender);
        })
        .toList();

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      reports = reports
          .where(
            (r) =>
                r.message.body.toLowerCase().contains(q) ||
                (r.message.sender ?? '').toLowerCase().contains(q),
          )
          .toList();
    }

    reports = reports
        .where((r) {
          final level = r.analysis.finalLevel;
          return switch (_filter) {
            InboxFilter.all => true,
            InboxFilter.highRisk => level == ThreatLevel.highRisk,
            InboxFilter.suspicious => level == ThreatLevel.suspicious,
            InboxFilter.safe => level == ThreatLevel.safe,
          };
        })
        .toList();

    reports.sort((a, b) {
      if (_worstFirst) {
        final byRisk = b.analysis.blendedRiskScore.compareTo(
          a.analysis.blendedRiskScore,
        );
        if (byRisk != 0) return byRisk;
      }

      final aDate = a.message.receivedAt;
      final bDate = b.message.receivedAt;
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });

    return reports;
  }

  Widget _buildToolbar(BuildContext context, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              hintText: 'Search messages or senders',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('All', InboxFilter.all),
                      const SizedBox(width: 8),
                      _filterChip('High risk', InboxFilter.highRisk),
                      const SizedBox(width: 8),
                      _filterChip('Suspicious', InboxFilter.suspicious),
                      const SizedBox(width: 8),
                      _filterChip('Safe', InboxFilter.safe),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: _worstFirst ? 'Worst first' : 'Newest first',
                child: IconButton(
                  onPressed: () => setState(() => _worstFirst = !_worstFirst),
                  icon: Icon(
                    _worstFirst
                        ? Icons.sort_by_alpha_outlined
                        : Icons.schedule_outlined,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$count message${count == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, InboxFilter value) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _demoBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        color: Colors.amber.withValues(alpha: 0.14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Demo mode — these are simulated messages.',
              style: TextStyle(fontSize: 12.5),
            ),
          ),
          TextButton(
            onPressed: widget.controller.loadMessages,
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    final controller = widget.controller;

    return EmptyState(
      icon: Icons.error_outline,
      title: 'Unable to read messages',
      message: controller.errorMessage ?? 'An unexpected error occurred.',
      actions: [
        if (!controller.hasSmsPermission)
          controller.permissionPermanentlyDenied
              ? OutlinedButton.icon(
                  onPressed: controller.openAppSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Open app settings'),
                )
              : FilledButton.icon(
                  onPressed: controller.requestPermission,
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Allow SMS access'),
                )
        else
          FilledButton.icon(
            onPressed: controller.loadMessages,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
      ],
    );
  }

  Widget _buildPermissionRequest() {
    final controller = widget.controller;

    return EmptyState(
      icon: Icons.shield_outlined,
      title: 'Scan your messages',
      message: controller.permissionPermanentlyDenied
          ? 'SMS access was permanently denied. Open app settings to enable it '
                'manually.'
          : 'ThreatGuard needs SMS access to detect phishing, scams and social '
                'engineering. Analysis happens entirely on your device.',
      actions: [
        if (controller.permissionPermanentlyDenied)
          OutlinedButton.icon(
            onPressed: controller.openAppSettings,
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Open app settings'),
          )
        else
          FilledButton.icon(
            onPressed: controller.requestPermission,
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Allow SMS access'),
          ),
        if (kDebugMode)
          TextButton(
            onPressed: controller.loadDemoMessages,
            child: const Text('Explore with demo messages'),
          ),
      ],
    );
  }

  Widget _messageCard(MessageThreatReport report) {
    final analysis = report.analysis;
    final level = analysis.finalLevel;
    final color = AppTheme.levelColor(level);
    final message = report.message;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(report),
        onLongPress: () => _showMessageActions(report),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: color.withValues(alpha: 0.14),
                            child: Icon(
                              AppTheme.levelIcon(level),
                              size: 17,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.sender ?? 'Unknown sender',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (message.receivedAt != null)
                                  Text(
                                    _formatReceivedAt(
                                      context,
                                      message.receivedAt!,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          TypeBadge(type: analysis.finalType, compact: true),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          RiskChip(
                            score: analysis.blendedRiskScore,
                            level: level,
                          ),
                          const Spacer(),
                          if (report.templateMatch?.isCampaign ?? false)
                            _tinyFlag(
                              context,
                              Icons.content_copy_outlined,
                              'Campaign',
                            ),
                          if (analysis.ruleAnalysis.indicators.isNotEmpty)
                            _tinyFlag(
                              context,
                              Icons.flag_outlined,
                              '${analysis.ruleAnalysis.indicators.length}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tinyFlag(BuildContext context, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(MessageThreatReport report) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SmsDetailScreen(
          report: report,
          engine: widget.controller.engine,
          controller: widget.controller,
        ),
      ),
    );
  }

  void _showMessageActions(MessageThreatReport report) {
    final sender = report.message.sender?.trim();

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open analysis'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openDetail(report);
              },
            ),
            if (sender != null && sender.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.volume_off_outlined),
                title: Text('Mute $sender'),
                subtitle: const Text(
                  'Hide future messages from this sender from the inbox.',
                ),
                onTap: () {
                  widget.controller.muteSender(sender);
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Muted $sender')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatReceivedAt(BuildContext context, DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();

    if (DateUtils.isSameDay(localDate, now)) {
      return MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(TimeOfDay.fromDateTime(localDate));
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (DateUtils.isSameDay(localDate, yesterday)) return 'Yesterday';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[localDate.month - 1]} ${localDate.day}, '
        '${localDate.year}';
  }
}
