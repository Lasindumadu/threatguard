import 'package:flutter/material.dart';

import '../../../../core/models/campaign_advisory.dart';
import '../../../../core/theme/app_theme.dart';

/// How the common scams actually work.
///
/// Bundled and offline on purpose: it works with no connection and doubles as
/// the educational surface that makes the rest of the app easier to read.
class ThreatFeedScreen extends StatefulWidget {
  const ThreatFeedScreen({super.key, this.catalog = const ThreatFeedCatalog()});

  final ThreatFeedCatalog catalog;

  @override
  State<ThreatFeedScreen> createState() => _ThreatFeedScreenState();
}

class _ThreatFeedScreenState extends State<ThreatFeedScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final campaigns = _selectedCategory == null
        ? widget.catalog.all
        : widget.catalog.byCategory(_selectedCategory!);

    return Scaffold(
      appBar: AppBar(title: const Text('Threat awareness')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Know the playbook',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Most attacks are variations on a handful of scripts. Recognising '
            'the script is faster than analysing an individual message.',
            style: TextStyle(
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _categoryChip(context, 'All', null),
                for (final category in widget.catalog.categories) ...[
                  const SizedBox(width: 8),
                  _categoryChip(context, category, category),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (final campaign in campaigns) _campaignCard(context, campaign),
        ],
      ),
    );
  }

  Widget _categoryChip(BuildContext context, String label, String? value) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedCategory == value,
      onSelected: (_) => setState(() => _selectedCategory = value),
    );
  }

  Widget _campaignCard(BuildContext context, CampaignAdvisory campaign) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Theme(
          // Remove the default divider colouring between ExpansionTile rows.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
              campaign.title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                campaign.category,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.suspiciousColor,
                ),
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.summary,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    _label(context, 'Wording they use'),
                    const SizedBox(height: 6),
                    for (final line in campaign.typicalWording)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                          ),
                          child: Text(
                            '"$line"',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    _bullet(
                      context,
                      Icons.gps_fixed_outlined,
                      'What they want',
                      campaign.objective,
                      AppTheme.highRiskColor,
                    ),
                    const SizedBox(height: 10),
                    _bullet(
                      context,
                      Icons.shield_outlined,
                      'How to shut it down',
                      campaign.defence,
                      AppTheme.safeColor,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.build_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            campaign.relatedTool,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _bullet(
    BuildContext context,
    IconData icon,
    String title,
    String body,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 12.5, height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}
