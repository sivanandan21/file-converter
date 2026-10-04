import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/aws_release_service.dart';

class AppReleaseScreen extends StatefulWidget {
  const AppReleaseScreen({super.key});

  @override
  State<AppReleaseScreen> createState() => _AppReleaseScreenState();
}

class _AppReleaseScreenState extends State<AppReleaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _versionNameCtrl = TextEditingController(text: '1.0.1');
  final _versionCodeCtrl = TextEditingController(text: '2');
  final _releaseNotesCtrl = TextEditingController(
    text: '• 100% Deep Scan OCR (300 DPI + Otsu Binarization)\n• Editable Word (.docx) document output\n• Interactive 3D animations and UI overhaul',
  );
  final _customUrlCtrl = TextEditingController();

  final _awsService = AwsReleaseService();

  File? _selectedApk;
  bool _forceUpdate = false;
  bool _isPublishing = false;
  double _progress = 0;
  String _statusMessage = '';
  AppReleaseInfo? _currentRelease;
  bool _isLoadingCurrent = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentRelease();
  }

  @override
  void dispose() {
    _versionNameCtrl.dispose();
    _versionCodeCtrl.dispose();
    _releaseNotesCtrl.dispose();
    _customUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentRelease() async {
    setState(() => _isLoadingCurrent = true);
    final current = await _awsService.fetchCurrentLiveRelease();
    if (mounted) {
      setState(() {
        _currentRelease = current;
        _isLoadingCurrent = false;
        if (current != null) {
          _versionCodeCtrl.text = (current.versionCode + 1).toString();
        }
      });
    }
  }

  Future<void> _pickApkFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedApk = File(result.files.single.path!);
      });
    }
  }

  Future<void> _publishRelease() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedApk == null && _customUrlCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an APK file or provide a download URL.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isPublishing = true;
      _progress = 0.05;
      _statusMessage = 'Connecting to AWS...';
    });

    try {
      final updated = await _awsService.publishRelease(
        versionName: _versionNameCtrl.text.trim(),
        versionCode: int.parse(_versionCodeCtrl.text.trim()),
        releaseNotes: _releaseNotesCtrl.text.trim(),
        forceUpdate: _forceUpdate,
        apkFile: _selectedApk,
        customDownloadUrl: _customUrlCtrl.text.trim(),
        onProgress: (p, msg) {
          if (mounted) {
            setState(() {
              _progress = p;
              _statusMessage = msg;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isPublishing = false;
          _currentRelease = updated;
          _selectedApk = null;
        });

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green),
                SizedBox(width: 8),
                Text('Update Published!'),
              ],
            ),
            content: Text(
              'Version ${updated.latestVersion} (Code ${updated.versionCode}) is now live on AWS S3!\n\nAll main app users will be notified on launch.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPublishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Publish failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publish App Update (AWS)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadCurrentRelease,
            tooltip: 'Refresh live status',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live AWS status card
              _buildLiveStatusCard(),
              const SizedBox(height: 20),

              // Version fields
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _versionNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Version Name',
                        hintText: 'e.g. 1.0.1',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _versionCodeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Version Code',
                        hintText: 'e.g. 2',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers_rounded),
                      ),
                      validator: (v) => int.tryParse(v ?? '') == null
                          ? 'Integer'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Release notes
              TextFormField(
                controller: _releaseNotesCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Release Notes (Shown to Users)',
                  hintText: 'What is new in this update...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // APK Picker Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.android_rounded, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Release APK File',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_selectedApk != null) ...[
                      Text(
                        'Selected: ${_selectedApk!.path.split(Platform.pathSeparator).last}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Size: ${(_selectedApk!.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: _pickApkFile,
                      icon: const Icon(Icons.file_upload_rounded),
                      label: Text(_selectedApk == null
                          ? 'Select APK to Upload to AWS S3'
                          : 'Change APK File'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Or custom URL
              TextFormField(
                controller: _customUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Or External Download URL (Optional)',
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // Force update switch
              SwitchListTile(
                title: const Text('Force Update'),
                subtitle: const Text(
                  'Blocks users on older versions until they update',
                  style: TextStyle(fontSize: 12),
                ),
                value: _forceUpdate,
                onChanged: (v) => setState(() => _forceUpdate = v),
              ),
              const SizedBox(height: 24),

              // Progress indicator if publishing
              if (_isPublishing) ...[
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
              ],

              // Publish button
              ElevatedButton.icon(
                onPressed: _isPublishing ? null : _publishRelease,
                icon: const Icon(Icons.cloud_upload_rounded),
                label: Text(
                  _isPublishing ? 'Publishing to AWS...' : 'Publish Update to AWS S3',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStatusCard() {
    if (_isLoadingCurrent) {
      return const Center(child: CircularProgressIndicator());
    }

    final release = _currentRelease;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done_rounded, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'Current Live AWS S3 Release',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'v${release?.latestVersion ?? '1.0.0'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (release != null) ...[
            const SizedBox(height: 8),
            Text(
              'Version Code: ${release.versionCode} • Force: ${release.forceUpdate ? 'Yes' : 'No'}',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
            if (release.downloadUrl.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Download URL: ${release.downloadUrl}',
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
