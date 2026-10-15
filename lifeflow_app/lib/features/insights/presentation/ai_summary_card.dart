import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/insights_repository.dart';
import '../domain/ai_insight.dart';

const _months = [
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

/// AI summary of this week or month, with suggestions. Showing a saved summary
/// is free; writing or refreshing one calls the AI (limited per day).
class AiSummaryCard extends ConsumerStatefulWidget {
  const AiSummaryCard({super.key});

  @override
  ConsumerState<AiSummaryCard> createState() => _AiSummaryCardState();
}

class _AiSummaryCardState extends ConsumerState<AiSummaryCard> {
  String _period = 'week';
  bool _writing = false;
  String? _error;

  Future<void> _write() async {
    setState(() {
      _writing = true;
      _error = null;
    });
    try {
      await ref.read(insightsRepositoryProvider).generate(_period);
      ref.invalidate(insightProvider(_period));
    } on InsightException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(insightProvider(_period));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:
            theme.cardTheme.color ??
            (isDark ? const Color(0xFF1E1E2C) : Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'AI summary',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SegmentedButton<String>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: 'week', label: Text('This week')),
                  ButtonSegment(value: 'month', label: Text('This month')),
                ],
                selected: {_period},
                onSelectionChanged: _writing
                    ? null
                    : (s) => setState(() {
                        _period = s.first;
                        _error = null;
                      }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          state.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(insightProvider(_period)),
              child: const Text("Couldn't load the summary. Tap to retry."),
            ),
            data: (data) => _buildBody(theme, data),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, InsightState data) {
    if (_writing) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text(
              'Writing your summary…',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'This can take up to a minute.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final insight = data.insight;
    final error = _error == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          );

    if (insight == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.configured
                ? 'Get a short read of your ${_period == 'week' ? 'week' : 'month'}: money, tasks and habits, with a few suggestions.'
                : "AI summaries aren't set up on the server yet (it needs a Gemini key).",
            style: const TextStyle(color: Colors.grey),
          ),
          if (data.configured) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _write,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Write my summary'),
              ),
            ),
          ],
          error,
        ],
      );
    }

    final written = insight.generatedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          insight.headline,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          insight.summary,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        if (insight.highlights.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final h in insight.highlights)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 10),
                    child: Icon(
                      Icons.circle,
                      size: 7,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(child: Text(h)),
                ],
              ),
            ),
        ],
        if (insight.suggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Suggestions',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          for (final s in insight.suggestions)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _areaIcon(s.area),
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.detail,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            if (written != null)
              Text(
                'Written ${written.day} ${_months[written.month - 1]}, '
                '${written.hour.toString().padLeft(2, '0')}:${written.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            if (data.stale)
              const Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(Icons.update, size: 16),
                label: Text('New data since'),
              ),
            TextButton.icon(
              onPressed: data.configured ? _write : null,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
        error,
      ],
    );
  }

  IconData _areaIcon(String area) => switch (area) {
    'tasks' => Icons.check_circle_outline,
    'habits' => Icons.repeat,
    'wishlist' => Icons.card_giftcard_outlined,
    _ => Icons.account_balance_wallet_outlined,
  };
}
