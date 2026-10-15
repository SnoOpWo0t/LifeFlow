/// A saved AI summary of a week or month (GET/POST /insights).
class AiInsight {
  final String headline;
  final String summary;
  final List<String> highlights;
  final List<({String title, String detail, String area})> suggestions;
  final DateTime? generatedAt;

  const AiInsight({
    required this.headline,
    required this.summary,
    required this.highlights,
    required this.suggestions,
    this.generatedAt,
  });

  factory AiInsight.fromJson(Map<String, dynamic> j) => AiInsight(
    headline: j['headline'] as String? ?? '',
    summary: j['summary'] as String? ?? '',
    highlights: [for (final h in (j['highlights'] as List? ?? const [])) '$h'],
    suggestions: [
      for (final s in (j['suggestions'] as List? ?? const []).whereType<Map>())
        (
          title: '${s['title'] ?? ''}',
          detail: '${s['detail'] ?? ''}',
          area: '${s['area'] ?? 'money'}',
        ),
    ],
    generatedAt: DateTime.tryParse(
      j['generated_at'] as String? ?? '',
    )?.toLocal(),
  );
}

class InsightState {
  final String period; // week | month
  final String from;
  final String to;
  final bool configured; // the server has a Gemini key
  final AiInsight? insight; // null until one is written
  final bool stale; // data changed since it was written

  const InsightState({
    required this.period,
    required this.from,
    required this.to,
    required this.configured,
    this.insight,
    this.stale = false,
  });

  factory InsightState.fromJson(Map<String, dynamic> j) => InsightState(
    period: j['period'] as String? ?? 'month',
    from: j['from'] as String? ?? '',
    to: j['to'] as String? ?? '',
    configured: j['configured'] != false,
    insight: j['insight'] is Map<String, dynamic>
        ? AiInsight.fromJson(j['insight'])
        : null,
    stale: j['stale'] == true,
  );
}
