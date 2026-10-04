import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  List<File> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    final files = await ref.read(fileStorageServiceProvider).listOutputFiles();
    if (mounted) {
      setState(() {
        _files = files;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Files'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFiles,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? _EmptyFilesState()
              : RefreshIndicator(
                  onRefresh: _loadFiles,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _files.length,
                    itemBuilder: (ctx, i) {
                      return _FileCard(
                        file: _files[i],
                        onRefresh: _loadFiles,
                      );
                    },
                  ),
                ),
    );
  }
}

class _FileCard extends ConsumerWidget {
  final File file;
  final VoidCallback onRefresh;

  const _FileCard({required this.file, required this.onRefresh});

  String get _ext {
    final parts = file.path.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stat = file.statSync();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final cardBg = isDark ? AppColors.darkCardColor : AppColors.cardColor;
    final shadowDark = isDark ? AppColors.darkShadowDark : AppColors.shadowDark;
    final shadowLight =
        isDark ? AppColors.darkShadowLight : AppColors.shadowLight;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowDark.withValues(alpha: 0.4),
            offset: const Offset(4, 4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: shadowLight.withValues(alpha: 0.9),
            offset: const Offset(-4, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        leading: AppConstants.imageExtensions.contains(_ext.toLowerCase())
            ? Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: cs.onSurface.withValues(alpha: 0.1)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.file(file, fit: BoxFit.cover),
                ),
              )
            : _ExtIcon(ext: _ext),
        title: Text(
          AppUtils.fileName(file.path),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${AppUtils.formatFileSize(stat.size)} • ${AppUtils.formatDate(stat.modified)}',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded,
              color: cs.onSurface.withValues(alpha: 0.4), size: 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: cardBg,
          onSelected: (value) async {
            if (value == 'open') {
              OpenFilex.open(file.path);
            } else if (value == 'share') {
              Share.shareXFiles([XFile(file.path)]);
            } else if (value == 'delete') {
              await ref.read(fileStorageServiceProvider).deleteFile(file.path);
              onRefresh();
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'open', child: Text('Open')),
            const PopupMenuItem(value: 'share', child: Text('Share')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtIcon extends StatelessWidget {
  final String ext;
  const _ExtIcon({required this.ext});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (ext.toLowerCase()) {
      case 'pdf':
        bg = AppColors.pdfRedLight;
        fg = AppColors.pdfRed;
        label = 'PDF';
        break;
      case 'docx':
      case 'doc':
        bg = AppColors.docxBlueLight;
        fg = AppColors.docxBlue;
        label = 'W';
        break;
      default:
        bg = AppColors.imageGreenLight;
        fg = AppColors.imageGreen;
        label = 'Img';
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: label.length == 1 ? 14 : 10,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _EmptyFilesState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded,
              size: 64, color: cs.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No output files yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Converted files will be saved here',
            style: TextStyle(
                fontSize: 13, color: cs.onSurface.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }
}
