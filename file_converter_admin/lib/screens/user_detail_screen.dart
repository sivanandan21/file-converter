import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/aws_dynamodb_service.dart';

class UserDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const UserDetailScreen({super.key, required this.data});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late Map<String, dynamic> _data;
  String? _selectedPlan;
  final _dynamo = AwsDynamoDbService();

  static const _plans = ['free', 'premium', 'lifetime'];
  static const _planColors = {
    'free': Color(0xFF64748B),
    'premium': Color(0xFF4B6BFB),
    'lifetime': Color(0xFFD97706),
  };

  Color get _planColor =>
      _planColors[(_selectedPlan ?? 'free').toLowerCase()] ??
      const Color(0xFF64748B);

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return {};
  }

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _selectedPlan = _data['plan'] ?? 'free';
  }

  Future<void> _savePlan() async {
    try {
      await _dynamo.updateDevicePlan(_data['device_id'], _selectedPlan ?? 'free');
      if (mounted) {
        setState(() => _data['plan'] = _selectedPlan);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan updated to ${_selectedPlan!.toUpperCase()} in AWS'),
            backgroundColor: _planColor,
          ),
        );
      }
    } catch (e) {
      _showSaveError('AWS DynamoDB update failed: $e');
    }
  }

  void _showSaveError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  Widget _infoRow(String label, String? value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white38, size: 16),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.isNotEmpty == true ? value! : '—',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final convsByType = _asStringMap(_data['conversions_by_type']);
    final totalConversions = _asInt(_data['total_conversions']);
    final statMax = totalConversions > 0 ? totalConversions : 1;
    final lastSeen =
        _data['last_seen'] != null
            ? DateTime.tryParse(_data['last_seen'].toString())?.toLocal()
            : null;
    final firstSeen =
        _data['first_seen'] != null
            ? DateTime.tryParse(_data['first_seen'].toString())?.toLocal()
            : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text(
          'User Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _planColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.smartphone_rounded,
                          color: _planColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _data['device_model'] ?? 'Unknown Device',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _data['brand'] ?? '',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _planColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          (_data['plan'] ?? 'free').toUpperCase(),
                          style: TextStyle(
                            color: _planColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 32),
                  _infoRow(
                    'Device ID',
                    _data['device_id'],
                    icon: Icons.fingerprint_rounded,
                  ),
                  if (_data['email'] != null && _data['email'].toString().isNotEmpty)
                    _infoRow(
                      'Email',
                      _data['email'],
                      icon: Icons.email_rounded,
                    ),
                  _infoRow(
                    'OS Version',
                    _data['os_version'],
                    icon: Icons.system_update_rounded,
                  ),
                  _infoRow(
                    'App Version',
                    _data['app_version'],
                    icon: Icons.apps_rounded,
                  ),
                  _infoRow(
                    'IP Address',
                    _data['ip_address'],
                    icon: Icons.wifi_rounded,
                  ),
                  _infoRow(
                    'First Seen',
                    firstSeen != null
                        ? DateFormat('MMM d, y  HH:mm').format(firstSeen)
                        : null,
                    icon: Icons.calendar_today_rounded,
                  ),
                  _infoRow(
                    'Last Seen',
                    lastSeen != null
                        ? DateFormat('MMM d, y  HH:mm').format(lastSeen)
                        : null,
                    icon: Icons.access_time_rounded,
                  ),
                  _infoRow(
                    'Sessions',
                    _data['session_count']?.toString(),
                    icon: Icons.login_rounded,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Conversions card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Conversion Stats',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StatBar(
                    label: 'Total',
                    count: totalConversions,
                    max: statMax,
                    color: const Color(0xFF4B6BFB),
                  ),
                  const SizedBox(height: 8),
                  ...convsByType.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _StatBar(
                        label: e.key,
                        count: _asInt(e.value),
                        max: statMax,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Plan management
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage Plan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children:
                        _plans.map((p) {
                          final selected = _selectedPlan == p;
                          final color =
                              _planColors[p] ?? const Color(0xFF64748B);
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedPlan = p),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      selected
                                          ? color.withValues(alpha: 0.2)
                                          : Colors.white.withValues(
                                            alpha: 0.04,
                                          ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        selected
                                            ? color
                                            : Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                    width: selected ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  p.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        selected
                                            ? color
                                            : Colors.white.withValues(
                                              alpha: 0.4,
                                            ),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _savePlan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _planColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Plan',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // Admin Controls
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admin Actions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _forceLogout,
                      icon: const Icon(Icons.logout_rounded, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      label: const Text(
                        'Force Logout User',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _resetQuotas,
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF10B981)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF10B981)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      label: const Text(
                        'Reset Today\'s Quotas',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _forceLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Force Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to log this user out of their device?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      )
    );
    
    if (confirmed == true) {
      try {
        await _dynamo.setForceLogout(_data['device_id'], true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AWS logout signal sent to device!')),
        );
      } catch (e) {
        _showSaveError('Failed to send AWS logout signal: $e');
      }
    }
  }

  Future<void> _resetQuotas() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Reset Quotas', style: TextStyle(color: Colors.white)),
        content: const Text('This will reset their daily conversions in AWS. Proceed?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset', style: TextStyle(color: Colors.green))),
        ],
      )
    );
    
    if (confirmed == true) {
      try {
        await _dynamo.resetQuotas(_data['device_id']);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AWS quotas reset successfully!')),
        );
      } catch (e) {
        _showSaveError('Failed to reset AWS quotas: $e');
      }
    }
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final int count;
  final int max;
  final Color color;

  const _StatBar({
    required this.label,
    required this.count,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = max > 0 ? (count / max).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.07),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$count',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
