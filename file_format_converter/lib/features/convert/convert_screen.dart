import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../models/conversion_record.dart';
import '../../providers/app_providers.dart';
import '../../services/conversion_services.dart';
import '../../services/analytics_service.dart';
import '../../widgets/buttons.dart';
import '../../widgets/conversion_card.dart';

enum ConvertState { idle, loading, converting, success, error }

class ConvertScreen extends ConsumerStatefulWidget {
  final ConversionType conversionType;
  final String title;

  const ConvertScreen({
    super.key,
    required this.conversionType,
    required this.title,
  });

  @override
  ConsumerState<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends ConsumerState<ConvertScreen>
    with TickerProviderStateMixin {
  ConvertState _state = ConvertState.idle;
  List<PlatformFile> _selectedFiles = [];
  List<String> _outputPaths = [];
  String? _errorMessage;
  double _progress = 0;
  int _currentPage = 0;
  int _totalPages = 0;
  String? _progressMessage;
  double _selectedDpi = 300.0;

  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;
  late AnimationController _successGlowCtrl;
  late AnimationController _successParticleCtrl;

  String _estimateOutputSize() {
    if (_selectedFiles.isEmpty) return '';
    final totalInput = _selectedFiles.fold<int>(0, (sum, f) => sum + f.size);
    switch (widget.conversionType) {
      case ConversionType.pdfToImage:
        final estBytes = (_selectedDpi == 150 ? 450 * 1024 : (_selectedDpi == 300 ? 1200 * 1024 : 3200 * 1024));
        return '~${AppUtils.formatFileSize(estBytes)} / page';
      case ConversionType.imageToPdf:
        return '~${AppUtils.formatFileSize((totalInput * 0.88).toInt())}';
      case ConversionType.pdfToDocx:
        return '~${AppUtils.formatFileSize(math.min(totalInput, 250 * 1024))}';
      case ConversionType.docxToPdf:
        return '~${AppUtils.formatFileSize((totalInput * 1.15).toInt())}';
    }
  }

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkScale = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut),
    );
    _successGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _successParticleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    _successGlowCtrl.dispose();
    _successParticleCtrl.dispose();
    super.dispose();
  }

  List<String> get _allowedExtensions {
    switch (widget.conversionType) {
      case ConversionType.pdfToImage:
      case ConversionType.pdfToDocx:
        return AppConstants.pdfExtensions;
      case ConversionType.imageToPdf:
        return AppConstants.imageExtensions;
      case ConversionType.docxToPdf:
        return AppConstants.docxExtensions;
    }
  }

  String get _outputFormat {
    switch (widget.conversionType) {
      case ConversionType.pdfToImage:
        return 'PNG';
      case ConversionType.imageToPdf:
        return 'PDF';
      case ConversionType.pdfToDocx:
        return 'DOCX';
      case ConversionType.docxToPdf:
        return 'PDF';
    }
  }

  bool get _hasSelectedFiles =>
      _selectedFiles.isNotEmpty &&
      _selectedFiles.every((file) => file.path != null);

  String get _sourceName {
    if (_selectedFiles.length == 1) return _selectedFiles.first.name;
    return '${_selectedFiles.length} images';
  }

  Future<void> _pickFile() async {
    final isImage = widget.conversionType == ConversionType.imageToPdf;
    final result = await FilePicker.platform.pickFiles(
      type: isImage ? FileType.image : FileType.custom,
      allowedExtensions: isImage ? null : _allowedExtensions,
      allowMultiple: isImage,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFiles =
            result.files.where((file) => file.path != null).toList();
        _state = ConvertState.idle;
        _outputPaths = [];
        _errorMessage = null;
        _progress = 0;
        _currentPage = 0;
        _totalPages = 0;
        _progressMessage = null;
      });
    }
  }

  Future<void> _addMoreFiles() async {
    final isImage = widget.conversionType == ConversionType.imageToPdf;
    final result = await FilePicker.platform.pickFiles(
      type: isImage ? FileType.image : FileType.custom,
      allowedExtensions: isImage ? null : _allowedExtensions,
      allowMultiple: isImage,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        final existingPaths = _selectedFiles.map((f) => f.path).toSet();
        final newFiles = result.files
            .where((f) => f.path != null && !existingPaths.contains(f.path));
        _selectedFiles.addAll(newFiles);
        _state = ConvertState.idle;
        _outputPaths = [];
        _errorMessage = null;
        _progress = 0;
        _currentPage = 0;
        _totalPages = 0;
        _progressMessage = null;
      });
    }
  }

  Future<void> _refreshAccountQuota() async {
    final snapshot = await ref.read(accountQuotaServiceProvider).fetchToday();
    if (!mounted || snapshot == null) return;
    ref.read(freemiumNotifierProvider.notifier).applyAccountQuota(snapshot);
  }

  Future<void> _convert() async {
    if (!_hasSelectedFiles) return;

    await _refreshAccountQuota();
    if (!mounted) return;

    // Check freemium limit
    final freemium = ref.read(freemiumNotifierProvider);
    if (!freemium.canConvert) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Daily limit reached. Watch an ad or go Pro!'),
          action: SnackBarAction(
            label: 'Go Pro',
            onPressed: () => Navigator.of(context).pushNamed('/pro'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _state = ConvertState.converting;
      _progress = 0;
      _errorMessage = null;
      _outputPaths = [];
      _progressMessage = null;
    });

    try {
      final sourcePath = _selectedFiles.first.path!;
      List<String> outputs = [];

      switch (widget.conversionType) {
        case ConversionType.imageToPdf:
          setState(() {
            _progress = 0.3;
            _progressMessage = 'Preparing images for PDF';
          });
          outputs = [
            await ref
                .read(imageToPdfServiceProvider)
                .convert(_selectedFiles.map((file) => file.path!).toList())
          ];
          setState(() => _progress = 1.0);
          break;

        case ConversionType.pdfToImage:
          outputs = await ref.read(pdfToImageServiceProvider).convert(
            sourcePath,
            dpi: _selectedDpi,
            onProgress: (p, total) {
              setState(() {
                _currentPage = p;
                _totalPages = total;
                _progress = p / total;
                _progressMessage = 'Rendering page $p of $total (${_selectedDpi.toInt()} DPI)';
              });
            },
          );
          break;

        case ConversionType.pdfToDocx:
          outputs = [
            await ref.read(pdfToDocxServiceProvider).convert(
              sourcePath,
              onProgress: (page, total, stage) {
                setState(() {
                  _currentPage = page;
                  _totalPages = total;
                  switch (stage) {
                    case PdfToDocxStage.extractingText:
                      _progress = (page / total) * 0.15;
                      _progressMessage = 'Deep Scan: Reading page $page of $total';
                      break;
                    case PdfToDocxStage.renderingPages:
                      _progress = 0.15 + ((page / total) * 0.45);
                      _progressMessage = 'Deep Scan 300 DPI: page $page of $total';
                      break;
                    case PdfToDocxStage.recognizingText:
                      _progress = 0.60 + ((page / total) * 0.40);
                      _progressMessage = 'Dual-pass OCR recognition: page $page of $total';
                      break;
                  }
                });
              },
            )
          ];
          setState(() => _progress = 1.0);
          break;

        case ConversionType.docxToPdf:
          setState(() {
            _progress = 0.5;
            _progressMessage = 'Building PDF from DOCX text';
          });
          outputs = [
            await ref.read(docxToPdfServiceProvider).convert(sourcePath)
          ];
          setState(() => _progress = 1.0);
          break;
      }

      if (!mounted) return;

      if (outputs.isNotEmpty) {
        final freemiumNotifier = ref.read(freemiumNotifierProvider.notifier);
        final accountQuota = ref.read(accountQuotaServiceProvider);
        await freemiumNotifier.recordConversion();
        final quotaSnapshot =
            await accountQuota.recordConversion(widget.conversionType.name);
        if (quotaSnapshot != null && mounted) {
          freemiumNotifier.applyAccountQuota(quotaSnapshot);
        }

        final storage = ref.read(fileStorageServiceProvider);
        final history = ref.read(conversionHistoryNotifierProvider.notifier);
        for (final output in outputs) {
          final size = await storage.fileSize(output);
          final record = ConversionRecord(
            id: const Uuid().v4(),
            conversionType: widget.title,
            sourceFileName: _sourceName,
            outputFileName: AppUtils.fileName(output),
            outputFilePath: output,
            outputFileSize: size,
            createdAt: DateTime.now(),
          );
          await history.addRecord(record);
        }

        // Log conversion analytics (inside mounted guard)
        AnalyticsService().logConversion(widget.conversionType.name);

        setState(() {
          _outputPaths = outputs;
          _state = ConvertState.success;
        });
        _checkCtrl.forward(from: 0);
        _successGlowCtrl.repeat(reverse: true);
        _successParticleCtrl.repeat();
      }
    } catch (e) {
      setState(() {
        _state = ConvertState.error;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // File picker area
              if (_state != ConvertState.success) ...[
                _FilePicker(
                  selectedFiles: _selectedFiles,
                  onPick: _pickFile,
                  onAddMore: _addMoreFiles,
                  allowedExtensions: _allowedExtensions,
                  allowMultiple:
                      widget.conversionType == ConversionType.imageToPdf,
                ),
                const SizedBox(height: 20),
              ],

              // Output format info & quality settings
              if (_hasSelectedFiles && _state != ConvertState.success) ...[
                _OutputFormatCard(
                  format: _outputFormat,
                  estimatedSize: _estimateOutputSize(),
                  conversionType: widget.conversionType,
                  selectedDpi: _selectedDpi,
                  onDpiChanged: (dpi) => setState(() => _selectedDpi = dpi),
                ),
                const SizedBox(height: 24),
              ],

              // Convert button / progress / success
              if (_state == ConvertState.idle && _hasSelectedFiles)
                PrimaryButton(
                  label: 'Convert Now',
                  onPressed: _convert,
                  icon: const Icon(Icons.swap_horiz_rounded,
                      color: Colors.white, size: 20),
                ),

              if (_state == ConvertState.converting)
                _ConversionProgress3D(
                  progress: _progress,
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  type: widget.conversionType,
                  message: _progressMessage,
                ),

              if (_state == ConvertState.error)
                _ErrorCard(
                  message: _errorMessage ?? 'Unknown error',
                  onRetry: _convert,
                ),

              if (_state == ConvertState.success && _outputPaths.isNotEmpty)
                _SuccessCard3D(
                  outputPaths: _outputPaths,
                  checkScale: _checkScale,
                  glowCtrl: _successGlowCtrl,
                  particleCtrl: _successParticleCtrl,
                  onViewFiles: () {
                    Navigator.of(context).pop();
                    ref.read(activeNavIndexProvider.notifier).state = 3;
                  },
                  onConvertAnother: () {
                    setState(() {
                      _state = ConvertState.idle;
                      _selectedFiles = [];
                      _outputPaths = [];
                      _progress = 0;
                      _currentPage = 0;
                      _totalPages = 0;
                      _progressMessage = null;
                    });
                    _checkCtrl.reset();
                    _successGlowCtrl.stop();
                    _successParticleCtrl.stop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _FilePicker extends StatefulWidget {
  final List<PlatformFile> selectedFiles;
  final VoidCallback onPick;
  final VoidCallback onAddMore;
  final List<String> allowedExtensions;
  final bool allowMultiple;

  const _FilePicker({
    required this.selectedFiles,
    required this.onPick,
    required this.onAddMore,
    required this.allowedExtensions,
    required this.allowMultiple,
  });

  @override
  State<_FilePicker> createState() => _FilePickerState();
}

class _FilePickerState extends State<_FilePicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _tiltSpringCtrl;
  late Animation<double> _tiltXAnim;
  late Animation<double> _tiltYAnim;
  double _tiltX = 0;
  double _tiltY = 0;

  @override
  void initState() {
    super.initState();
    _tiltSpringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(() {
        if (_tiltSpringCtrl.isAnimating) {
          setState(() {
            _tiltX = _tiltXAnim.value;
            _tiltY = _tiltYAnim.value;
          });
        }
      });
  }

  @override
  void dispose() {
    _tiltSpringCtrl.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details, double width, double height) {
    if (width <= 0 || height <= 0) return;
    final normalizedX = (details.localPosition.dx / width - 0.5) * 2;
    final normalizedY = (details.localPosition.dy / height - 0.5) * 2;
    setState(() {
      _tiltX = (-normalizedY * 0.12).clamp(-0.12, 0.12);
      _tiltY = (normalizedX * 0.12).clamp(-0.12, 0.12);
    });
  }

  void _onPanEnd() {
    _tiltXAnim = Tween<double>(begin: _tiltX, end: 0).animate(
      CurvedAnimation(parent: _tiltSpringCtrl, curve: Curves.elasticOut),
    );
    _tiltYAnim = Tween<double>(begin: _tiltY, end: 0).animate(
      CurvedAnimation(parent: _tiltSpringCtrl, curve: Curves.elasticOut),
    );
    _tiltSpringCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final cardBg = isDark ? AppColors.darkCardColor : AppColors.cardColor;
    final shadowDark = isDark ? AppColors.darkShadowDark : AppColors.shadowDark;
    final shadowLight =
        isDark ? AppColors.darkShadowLight : AppColors.shadowLight;
    final hasFiles = widget.selectedFiles.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: widget.onPick,
          onPanUpdate: (d) => _onPanUpdate(d, constraints.maxWidth, 180),
          onPanEnd: (_) => _onPanEnd(),
          onPanCancel: () => _onPanEnd(),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateX(_tiltX)
              ..rotateY(_tiltY),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary
                      .withValues(alpha: hasFiles ? 0.5 : 0.2),
                  width: 2,
                  style: BorderStyle.solid,
                ),
                boxShadow: [
                  BoxShadow(
                    color: shadowDark.withValues(alpha: 0.4),
                    offset: Offset(5 + _tiltY * 15, 5 - _tiltX * 15),
                    blurRadius: 12,
                  ),
                  BoxShadow(
                    color: shadowLight.withValues(alpha: 0.9),
                    offset: Offset(-5 - _tiltY * 15, -5 + _tiltX * 15),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: !hasFiles
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 32,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.allowMultiple
                              ? 'Tap to select images'
                              : 'Tap to select file',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.allowedExtensions
                              .map((e) => e.toUpperCase())
                              .join(', '),
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.insert_drive_file_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.selectedFiles.length == 1
                                      ? widget.selectedFiles.first.name
                                      : '${widget.selectedFiles.length} images selected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppUtils.formatFileSize(
                                    widget.selectedFiles.fold<int>(
                                      0,
                                      (sum, file) => sum + file.size,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.allowMultiple) ...[
                            GestureDetector(
                              onTap: widget.onAddMore,
                              child: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 24,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          GestureDetector(
                            onTap: widget.onPick,
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _OutputFormatCard extends StatelessWidget {
  final String format;
  final String estimatedSize;
  final ConversionType conversionType;
  final double selectedDpi;
  final ValueChanged<double> onDpiChanged;

  const _OutputFormatCard({
    required this.format,
    required this.estimatedSize,
    required this.conversionType,
    required this.selectedDpi,
    required this.onDpiChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.output_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Output format: $format',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              if (estimatedSize.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.speed_rounded,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        estimatedSize,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (conversionType == ConversionType.pdfToDocx) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.proStart.withValues(alpha: 0.08),
                  AppColors.proEnd.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.proStart.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: AppColors.proStart, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Full Deep Scan: 300 DPI + Otsu Dual-Pass OCR • Produces editable Word text',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (conversionType == ConversionType.pdfToImage) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: cs.onSurface.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.hd_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Resolution Quality:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _DpiButton(
                      label: '150 DPI (Fast)',
                      dpi: 150,
                      isSelected: selectedDpi == 150,
                      onTap: () => onDpiChanged(150),
                    ),
                    const SizedBox(width: 8),
                    _DpiButton(
                      label: '300 DPI (High)',
                      dpi: 300,
                      isSelected: selectedDpi == 300,
                      onTap: () => onDpiChanged(300),
                    ),
                    const SizedBox(width: 8),
                    _DpiButton(
                      label: '600 DPI (Ultra)',
                      dpi: 600,
                      isSelected: selectedDpi == 600,
                      onTap: () => onDpiChanged(600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DpiButton extends StatelessWidget {
  final String label;
  final double dpi;
  final bool isSelected;
  final VoidCallback onTap;

  const _DpiButton({
    required this.label,
    required this.dpi,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 3D page-turning progress indicator.
class _ConversionProgress3D extends StatefulWidget {
  final double progress;
  final int currentPage;
  final int totalPages;
  final ConversionType type;
  final String? message;

  const _ConversionProgress3D({
    required this.progress,
    required this.currentPage,
    required this.totalPages,
    required this.type,
    this.message,
  });

  @override
  State<_ConversionProgress3D> createState() => _ConversionProgress3DState();
}

class _ConversionProgress3DState extends State<_ConversionProgress3D>
    with TickerProviderStateMixin {
  late AnimationController _pageFlipCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pageFlipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageFlipCtrl.dispose();
    _pulseCtrl.dispose();
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
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowDark.withValues(alpha: 0.4),
            offset: const Offset(5, 5),
            blurRadius: 12,
          ),
          BoxShadow(
            color: shadowLight.withValues(alpha: 0.9),
            offset: const Offset(-5, -5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // 3D page flip animation
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background pages
                ...List.generate(3, (i) {
                  return AnimatedBuilder(
                    animation: _pageFlipCtrl,
                    builder: (_, __) {
                      final offset = (i - 1) * 0.33;
                      final angle =
                          math.sin((_pageFlipCtrl.value + offset) * 2 * math.pi) *
                              0.2;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.002)
                          ..rotateY(angle)
                          ..translateByDouble(0.0, 0.0, -i * 3.0, 1.0),
                        child: Container(
                          width: 60 - i * 4,
                          height: 80 - i * 4,
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: 0.1 - i * 0.02),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.primary
                                  .withValues(alpha: 0.2 - i * 0.05),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
                // Progress percentage
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) {
                    return Transform.scale(
                      scale: 1.0 + _pulseCtrl.value * 0.05,
                      child: Text(
                        '${(widget.progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          shadows: [
                            Shadow(
                              color:
                                  AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Converting...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.message ??
                (widget.type == ConversionType.pdfToImage &&
                        widget.totalPages > 0
                    ? 'Page ${widget.currentPage} of ${widget.totalPages}'
                    : 'Processing your file on-device'),
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          // Gradient progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: widget.progress > 0 ? widget.progress : 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.proEnd,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 3D success card with particle burst and glowing sphere.
class _SuccessCard3D extends StatelessWidget {
  final List<String> outputPaths;
  final Animation<double> checkScale;
  final AnimationController glowCtrl;
  final AnimationController particleCtrl;
  final VoidCallback onConvertAnother;
  final VoidCallback onViewFiles;

  const _SuccessCard3D({
    required this.outputPaths,
    required this.checkScale,
    required this.glowCtrl,
    required this.particleCtrl,
    required this.onConvertAnother,
    required this.onViewFiles,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final cardBg = isDark ? AppColors.darkCardColor : AppColors.cardColor;
    final shadowDark = isDark ? AppColors.darkShadowDark : AppColors.shadowDark;
    final shadowLight =
        isDark ? AppColors.darkShadowLight : AppColors.shadowLight;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: shadowDark.withValues(alpha: 0.4),
                offset: const Offset(5, 5),
                blurRadius: 12,
              ),
              BoxShadow(
                color: shadowLight.withValues(alpha: 0.9),
                offset: const Offset(-5, -5),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            children: [
              // 3D success sphere with particles
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow ring
                    AnimatedBuilder(
                      animation: glowCtrl,
                      builder: (_, __) {
                        return Container(
                          width: 120 + glowCtrl.value * 20,
                          height: 120 + glowCtrl.value * 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success
                                    .withValues(alpha: 0.1 + glowCtrl.value * 0.15),
                                blurRadius: 25 + glowCtrl.value * 15,
                                spreadRadius: 5 + glowCtrl.value * 8,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Burst particles
                    ...List.generate(12, (i) => _SuccessParticle(
                      controller: particleCtrl,
                      index: i,
                    )),
                    // 3D rotating check sphere
                    ScaleTransition(
                      scale: checkScale,
                      child: AnimatedBuilder(
                        animation: glowCtrl,
                        builder: (_, child) {
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(math.sin(glowCtrl.value * 2 * math.pi) * 0.08)
                              ..rotateX(math.cos(glowCtrl.value * 2 * math.pi) * 0.04),
                            child: child,
                          );
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                AppColors.success.withValues(alpha: 0.2),
                                AppColors.success.withValues(alpha: 0.08),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.3),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: AppColors.success,
                            size: 44,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.success, Color(0xFF2E7D5B)],
                ).createShader(bounds),
                child: const Text(
                  'Conversion Complete!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                outputPaths.length == 1
                    ? AppUtils.fileName(outputPaths.first)
                    : '${outputPaths.length} files created',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (outputPaths.any((p) => AppConstants.imageExtensions
                  .contains(AppUtils.fileExtension(p)))) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemCount: outputPaths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final path = outputPaths[index];
                      final isImage = AppConstants.imageExtensions
                          .contains(AppUtils.fileExtension(path));
                      return Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: cs.onSurface.withValues(alpha: 0.1)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: isImage
                              ? Image.file(File(path), fit: BoxFit.cover)
                              : Icon(Icons.insert_drive_file_rounded,
                                  color:
                                      AppColors.primary.withValues(alpha: 0.5),
                                  size: 32),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: outputPaths.length == 1 ? 'Open' : 'View Files',
                      onPressed: () {
                        if (outputPaths.length == 1) {
                          OpenFilex.open(outputPaths.first);
                        } else {
                          onViewFiles();
                        }
                      },
                      icon: Icon(
                        outputPaths.length == 1
                            ? Icons.open_in_new_rounded
                            : Icons.folder_open_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SecondaryButton(
                      label: 'Share',
                      onPressed: () => Share.shareXFiles(
                        outputPaths.map((path) => XFile(path)).toList(),
                      ),
                      icon: const Icon(Icons.share_rounded,
                          color: AppColors.primary, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Convert Another File',
          onPressed: onConvertAnother,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        ),
      ],
    );
  }
}

class _SuccessParticle extends StatelessWidget {
  final AnimationController controller;
  final int index;

  const _SuccessParticle({
    required this.controller,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final angle = (index / 12) * 2 * math.pi;
        final progress = controller.value;
        final radius = 30 + progress * 35;
        final x = math.cos(angle + progress * math.pi) * radius;
        final y = math.sin(angle + progress * math.pi) * radius;
        final opacity = (1.0 - progress).clamp(0.0, 0.8);
        final size = 4.0 * (1.0 - progress * 0.5);

        return Transform.translate(
          offset: Offset(x, y),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: opacity),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: opacity * 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ErrorCard({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Conversion failed: $message',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
