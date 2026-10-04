import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_detail_screen.dart';
import 'login_screen.dart';
import 'app_release_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _search = '';
  String _planFilter = 'All';
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _channel;

  static const _planColors = {
    'free': Color(0xFF64748B),
    'premium': Color(0xFF4B6BFB),
    'lifetime': Color(0xFFD97706),
  };
  static const _plans = ['All', 'free', 'premium', 'lifetime'];

  Color _planColor(String plan) =>
      _planColors[plan.toLowerCase()] ?? const Color(0xFF64748B);

  bool _isInternalQuotaRow(Map<String, dynamic> row) {
    return (row['device_id'] ?? '').toString().startsWith('quota:');
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _subscribeRealtime();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await Supabase.instance.client
          .from('user_devices')
          .select()
          .order('last_seen', ascending: false);
      if (mounted) {
        setState(() {
          _users =
              List<Map<String, dynamic>>.from(
                res,
              ).where((row) => !_isInternalQuotaRow(row)).toList();
          _loading = false;
        });
      }
    } on PostgrestException catch (e) {
      _showLoadError(e.message);
    } catch (e) {
      _showLoadError(e.toString());
    }
  }

  void _showLoadError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  void _subscribeRealtime() {
    _channel =
        Supabase.instance.client
            .channel('user_devices_changes')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'user_devices',
              callback: (_) => _loadUsers(),
            )
            .subscribe();
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _users;
    if (_planFilter != 'All') {
      list =
          list
              .where(
                (d) =>
                    (d['plan'] ?? '').toString().toLowerCase() == _planFilter,
              )
              .toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list =
          list.where((d) {
            return (d['device_model'] ?? '').toString().toLowerCase().contains(
                  q,
                ) ||
                (d['device_id'] ?? '').toString().toLowerCase().contains(q) ||
                (d['email'] ?? '').toString().toLowerCase().contains(q) ||
                (d['ip_address'] ?? '').toString().toLowerCase().contains(q) ||
                (d['brand'] ?? '').toString().toLowerCase().contains(q);
          }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final total = _users.length;
    final premium = _users.where((d) => (d['plan'] ?? '') == 'premium').length;
    final lifetime =
        _users.where((d) => (d['plan'] ?? '') == 'lifetime').length;
    final totalConversions = _users.fold<int>(
      0,
      (s, d) => s + _asInt(d['total_conversions']),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4B6BFB), Color(0xFF7C5CFC)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Admin Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF4B6BFB)),
            tooltip: 'Publish App Update (AWS S3)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AppReleaseScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _loadUsers,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats banner
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF111827),
            child: Row(
              children: [
                _StatChip(
                  label: 'Users',
                  value: '$total',
                  color: const Color(0xFF4B6BFB),
                ),
                const SizedBox(width: 10),
                _StatChip(
                  label: 'Premium',
                  value: '$premium',
                  color: const Color(0xFF7C5CFC),
                ),
                const SizedBox(width: 10),
                _StatChip(
                  label: 'Lifetime',
                  value: '$lifetime',
                  color: const Color(0xFFD97706),
                ),
                const SizedBox(width: 10),
                _StatChip(
                  label: 'Conversions',
                  value: '$totalConversions',
                  color: const Color(0xFF10B981),
                ),
              ],
            ),
          ),

          // Search + filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by device, model, IP...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 18,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1E2433),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                PopupMenuButton<String>(
                  initialValue: _planFilter,
                  onSelected: (v) => setState(() => _planFilter = v),
                  color: const Color(0xFF1E2433),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2433),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _planFilter,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.expand_more_rounded,
                          color: Colors.white54,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                  itemBuilder:
                      (_) =>
                          _plans
                              .map(
                                (p) => PopupMenuItem(
                                  value: p,
                                  child: Text(
                                    p,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                              .toList(),
                ),
              ],
            ),
          ),

          // User list
          Expanded(
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? _DashboardError(message: _error!, onRetry: _loadUsers)
                    : _filtered.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No users found',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final d = _filtered[i];
                          final plan = (d['plan'] ?? 'free').toString();
                          final lastSeenRaw = d['last_seen'];
                          DateTime? lastSeen;
                          if (lastSeenRaw != null) {
                            lastSeen = DateTime.tryParse(
                              lastSeenRaw.toString(),
                            );
                          }
                          return GestureDetector(
                            onTap:
                                () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => UserDetailScreen(data: d),
                                  ),
                                ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111827),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _planColor(
                                        plan,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.smartphone_rounded,
                                      color: _planColor(plan),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d['email'] != null && d['email'].toString().isNotEmpty 
                                              ? d['email'] 
                                              : (d['device_model'] ?? 'Unknown Device'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${d['email'] != null && d['email'].toString().isNotEmpty ? "${d['device_model']} • " : ""}${d['os_version'] ?? ''} • IP: ${d['ip_address'] ?? 'N/A'}',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.4,
                                            ),
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _planColor(
                                            plan,
                                          ).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          plan.toUpperCase(),
                                          style: TextStyle(
                                            color: _planColor(plan),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        lastSeen != null
                                            ? DateFormat(
                                              'MMM d, HH:mm',
                                            ).format(lastSeen.toLocal())
                                            : '—',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: Color(0xFFF87171),
            ),
            const SizedBox(height: 14),
            const Text(
              'Supabase connection failed',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
