import 'db_provider.dart';

/// A single failover event recorded in persistent local storage and
/// optionally forwarded to the admin notification channel.
class FailoverEvent {
  final DateTime timestamp;
  final DbProvider from;
  final DbProvider to;
  final String reason;

  const FailoverEvent({
    required this.timestamp,
    required this.from,
    required this.to,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'from': from.label,
        'to': to.label,
        'reason': reason,
      };

  factory FailoverEvent.fromJson(Map<String, dynamic> json) => FailoverEvent(
        timestamp: DateTime.parse(json['timestamp'] as String),
        from: DbProvider.values
            .firstWhere((p) => p.label == json['from'],
                orElse: () => DbProvider.supabase),
        to: DbProvider.values
            .firstWhere((p) => p.label == json['to'],
                orElse: () => DbProvider.cloudflareD1),
        reason: json['reason'] as String,
      );

  @override
  String toString() =>
      '[${timestamp.toIso8601String()}] FAILOVER ${from.label} → ${to.label}: $reason';
}
