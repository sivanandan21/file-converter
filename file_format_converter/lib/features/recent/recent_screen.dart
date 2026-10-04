import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../../widgets/file_row_tile.dart';

class RecentScreen extends ConsumerWidget {
  const RecentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(filteredByTypeProvider);
    final searchQuery = ref.watch(recentSearchQueryProvider);
    final filterType = ref.watch(recentFilterTypeProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Recent Files'),
        automaticallyImplyLeading: false,
        actions: [
          if (records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              color: AppColors.error,
              tooltip: 'Clear all',
              onPressed: () => _confirmClearAll(context, ref),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _SearchBar(
              query: searchQuery,
              onChanged: (q) =>
                  ref.read(recentSearchQueryProvider.notifier).state = q,
            ),
          ),
          // Filter chips
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: filterType == null,
                  onTap: () =>
                      ref.read(recentFilterTypeProvider.notifier).state = null,
                ),
                _FilterChip(
                  label: 'PDF',
                  selected: filterType == AppConstants.pdfToImage ||
                      filterType == AppConstants.imageToPdf,
                  onTap: () => ref
                      .read(recentFilterTypeProvider.notifier)
                      .state = AppConstants.imageToPdf,
                ),
                _FilterChip(
                  label: 'Image',
                  selected: filterType == AppConstants.pdfToImage,
                  onTap: () => ref
                      .read(recentFilterTypeProvider.notifier)
                      .state = AppConstants.pdfToImage,
                ),
                _FilterChip(
                  label: 'DOCX',
                  selected: filterType == AppConstants.pdfToDocx,
                  onTap: () => ref
                      .read(recentFilterTypeProvider.notifier)
                      .state = AppConstants.pdfToDocx,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: records.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: records.length,
                    itemBuilder: (ctx, i) {
                      final record = records[i];
                      return FileRowTile(
                        record: record,
                        onTap: () => OpenFilex.open(record.outputFilePath),
                        onStar: () => ref
                            .read(conversionHistoryNotifierProvider.notifier)
                            .toggleStar(record.id),
                        onMore: () => _showOptions(
                            context, ref, record.id, record.outputFilePath),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showOptions(
      BuildContext context, WidgetRef ref, String id, String path) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded,
                  color: AppColors.primary),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(context);
                OpenFilex.open(path);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.share_rounded, color: AppColors.primary),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                Share.shareXFiles([XFile(path)]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error),
              title: const Text('Delete',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(conversionHistoryNotifierProvider.notifier)
                    .deleteRecord(id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear History'),
        content: const Text(
            'Are you sure you want to clear all conversion history?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(conversionHistoryNotifierProvider.notifier).clearAll();
            },
            child: const Text('Clear All',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.query, required this.onChanged});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.query);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final cardBg = isDark ? AppColors.darkCardColor : AppColors.cardColor;
    final shadowDark = isDark ? AppColors.darkShadowDark : AppColors.shadowDark;
    final shadowLight =
        isDark ? AppColors.darkShadowLight : AppColors.shadowLight;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowDark.withValues(alpha: 0.4),
            offset: const Offset(3, 3),
            blurRadius: 8,
          ),
          BoxShadow(
            color: shadowLight.withValues(alpha: 0.9),
            offset: const Offset(-3, -3),
            blurRadius: 8,
          ),
        ],
      ),
      child: TextField(
        controller: _ctrl,
        onChanged: widget.onChanged,
        style: TextStyle(fontSize: 14, color: cs.onSurface),
        decoration: InputDecoration(
          hintText: 'Search files...',
          hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.3)),
          prefixIcon: Icon(Icons.search_rounded,
              color: cs.onSurface.withValues(alpha: 0.3), size: 22),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final cardBg = isDark ? AppColors.darkCardColor : AppColors.cardColor;
    final shadowDark = isDark ? AppColors.darkShadowDark : AppColors.shadowDark;
    final shadowLight =
        isDark ? AppColors.darkShadowLight : AppColors.shadowLight;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: shadowDark.withValues(alpha: 0.3),
                    offset: const Offset(2, 2),
                    blurRadius: 6,
                  ),
                  BoxShadow(
                    color: shadowLight.withValues(alpha: 0.8),
                    offset: const Offset(-2, -2),
                    blurRadius: 6,
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color:
                selected ? Colors.white : cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded,
              size: 64, color: cs.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No recent files',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Convert a file to see it here',
            style: TextStyle(
                fontSize: 13, color: cs.onSurface.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }
}
