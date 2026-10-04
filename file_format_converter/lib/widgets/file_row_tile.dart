import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../models/conversion_record.dart';

class FileRowTile extends StatelessWidget {
  final ConversionRecord record;
  final VoidCallback? onStar;
  final VoidCallback? onMore;
  final VoidCallback? onTap;

  const FileRowTile({
    super.key,
    required this.record,
    this.onStar,
    this.onMore,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardColor : AppColors.cardColor;
    final shadowDark = isDark ? AppColors.darkShadowDark : AppColors.shadowDark;
    final shadowLight =
        isDark ? AppColors.darkShadowLight : AppColors.shadowLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        child: Row(
          children: [
            _FileTypeIcon(record: record),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.outputFileName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${record.outputExtension} \u2022 ${AppUtils.formatFileSize(record.outputFileSize)} \u2022 ${AppUtils.formatDate(record.createdAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onStar,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  record.isStarred
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 20,
                  color: record.isStarred
                      ? Colors.amber
                      : cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
            GestureDetector(
              onTap: onMore,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileTypeIcon extends StatelessWidget {
  final ConversionRecord record;
  const _FileTypeIcon({required this.record});

  @override
  Widget build(BuildContext context) {
    final ext = record.outputExtension.toLowerCase();
    Color bg;
    Color fg;
    IconData icon;

    if (ext == 'pdf') {
      bg = AppColors.pdfRedLight;
      fg = AppColors.pdfRed;
      icon = Icons.picture_as_pdf_rounded;
    } else if (ext == 'docx' || ext == 'doc') {
      bg = AppColors.docxBlueLight;
      fg = AppColors.docxBlue;
      icon = Icons.description_rounded;
    } else {
      bg = AppColors.imageGreenLight;
      fg = AppColors.imageGreen;
      icon = Icons.image_rounded;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: fg, size: 22),
    );
  }
}
