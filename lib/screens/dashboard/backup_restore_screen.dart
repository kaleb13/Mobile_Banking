import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../services/backup_service.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Backup & Restore Screen
// ─────────────────────────────────────────────────────────────────────────────
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen>
    with SingleTickerProviderStateMixin {
  final BackupService _backupService = BackupService();

  late TabController _tabController;

  // ── Backup state ──────────────────────────────────────────────
  bool _isExporting = false;
  String? _exportedPath;
  String? _exportError;

  // ── Restore state ─────────────────────────────────────────────
  bool _isLoadingFiles = false;
  List<File> _backupFiles = [];
  bool _isImporting = false;
  List<ImportResult>? _importResults;
  File? _selectedFile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadBackupFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Load backup file list ──────────────────────────────────────────────
  Future<void> _loadBackupFiles() async {
    setState(() => _isLoadingFiles = true);
    try {
      final files = await _backupService.listBackupFiles();
      if (mounted) setState(() => _backupFiles = files);
    } finally {
      if (mounted) setState(() => _isLoadingFiles = false);
    }
  }

  // ─── Export ────────────────────────────────────────────────────────────
  Future<void> _runExport() async {
    setState(() {
      _isExporting = true;
      _exportedPath = null;
      _exportError = null;
    });

    try {
      final path = await _backupService.createBackup();
      if (!mounted) return;
      if (path == null) {
        setState(() => _isExporting = false);
        return;
      }
      setState(() {
        _exportedPath = path;
        _isExporting = false;
      });
      // Refresh file list
      await _loadBackupFiles();
    } catch (e) {
      if (mounted) {
        setState(() {
          _exportError = e.toString();
          _isExporting = false;
        });
      }
    }
  }

  // ─── Import ────────────────────────────────────────────────────────────
  Future<void> _runImport(File file) async {
    setState(() {
      _isImporting = true;
      _importResults = null;
      _selectedFile = file;
    });

    try {
      final results = await _backupService.importBackup(file);
      if (mounted) {
        setState(() {
          _importResults = results;
          _isImporting = false;
        });
        // Trigger provider reload so UI reflects imported data
        if (mounted) {
          await Provider.of<FinanceProvider>(context, listen: false)
              .refreshData();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _importResults = [
            ImportResult(
              type: 'error',
              label: 'Failed to parse backup file',
              success: false,
              error: e.toString(),
            ),
          ];
          _isImporting = false;
        });
      }
    }
  }

  // Pick any backup file from anywhere on the device and restore it
  Future<void> _pickAndRestore() async {
    final file = await _backupService.pickBackupFile();
    if (file == null) return; // user cancelled
    await _loadBackupFiles();
    if (mounted) await _confirmRestore(file);
  }

  // ─── Retry single failed item ──────────────────────────────────────────
  Future<void> _retryItem(int index) async {
    final failed = _importResults![index];
    final updated = await _backupService.retryImport(failed);
    setState(() => _importResults![index] = updated);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        bottomNavigationBar: _buildActionBar(),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                AppColors.background,
                AppColors.bgMid,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBackupTab(),
                      _buildRestoreTab(),
                    ],
                  ),
                ),
                const SizedBox(height: 100), // Padding for navbar
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    final isExportTab = _tabController.index == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.overlay,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          // Action button
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (isExportTab) {
                  if (!_isExporting) _runExport();
                } else {
                  if (!_isImporting) _pickAndRestore();
                }
              },
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isExportTab
                          ? Icons.backup_outlined
                          : Icons.folder_open_rounded,
                      color: AppColors.gold,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isExportTab ? 'Create Backup' : 'Browse & Pick File',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Text(
        'Backup & Restore',
        style: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ─── Tab Bar ─────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.overlay.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSoft,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: const [
          Tab(height: 38, text: 'Backup'),
          Tab(height: 38, text: 'Restore'),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKUP TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBackupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Info card
          _infoCard(
            icon: Icons.cloud_upload_outlined,
            color: AppColors.gold,
            title: 'Create a Backup',
            body:
                'Your backup will be saved to a "Shibre_Backups" folder on your device storage. '
                'The backup includes all senders, transactions, reasons, and linked rules.',
          ),

          const SizedBox(height: 24),

          const SizedBox(height: 24),

          // Result
          if (_exportedPath != null) _exportSuccessCard(),
          if (_exportError != null) _exportErrorCard(),

          const SizedBox(height: 32),

          // Existing backups
          if (_backupFiles.isNotEmpty) ...[
            const Text(
              'EXISTING BACKUPS',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            ..._backupFiles.map((f) => _backupFileCard(f)),
          ],
        ],
      ),
    );
  }

  Widget _exportSuccessCard() {
    final parts = _exportedPath!.split('/');
    final fileName = parts.last;
    final folder = parts.sublist(0, parts.length - 1).join('/');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.positive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.positive.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              color: AppColors.positive, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backup created successfully!',
                  style: TextStyle(
                    color: AppColors.positive,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fileName,
                  style: TextStyle(
                    color: AppColors.positive.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '📁 $folder',
                  style: TextStyle(
                    color: AppColors.positive.withValues(alpha: 0.55),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.negative.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.negative.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.negative, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Backup failed: $_exportError',
              style: const TextStyle(color: AppColors.negative, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backupFileCard(File file) {
    final name = file.path.split('/').last;
    final stat = file.statSync();
    final size = (stat.size / 1024).toStringAsFixed(1);
    final modified = DateFormat('MMM d, yyyy  HH:mm').format(stat.modified);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.overlay.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description_outlined,
                color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$modified  •  $size KB',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESTORE TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildRestoreTab() {
    return _importResults != null
        ? _buildImportResults()
        : _buildRestoreFileList();
  }

  Widget _buildRestoreFileList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _infoCard(
            icon: Icons.cloud_download_outlined,
            color: AppColors.gold,
            title: 'Restore from Backup',
            body:
                'Tap a backup file below to restore, or use the bottom action to '
                'pick a backup from any folder. Existing transactions are kept.',
          ),
          const SizedBox(height: 24),
          if (_isLoadingFiles)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_backupFiles.isEmpty)
            _noBackupsPlaceholder()
          else ...[
            const Text(
              'RECENT BACKUPS',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            ..._backupFiles.map((f) => _restoreFileCard(f)),
          ],
          if (_isImporting)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 2,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Importing data...',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    if (_selectedFile != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _selectedFile!.path.split('/').last,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
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

  Widget _noBackupsPlaceholder() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.folder_off_outlined,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'No backups found',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            'Go to the Backup tab to create your first backup.',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.6),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _restoreFileCard(File file) {
    final name = file.path.split('/').last;
    final stat = file.statSync();
    final size = (stat.size / 1024).toStringAsFixed(1);
    final modified = DateFormat('MMM d, yyyy  HH:mm').format(stat.modified);

    return GestureDetector(
      onTap: _isImporting ? null : () => _confirmRestore(file),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.overlay.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.restore_outlined,
                  color: AppColors.gold, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$modified  •  $size KB',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textSecondary, size: 13),
          ],
        ),
      ),
    );
  }

  // ─── Confirm dialog ──────────────────────────────────────────────────────
  Future<void> _confirmRestore(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.overlay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restore_outlined,
                  color: AppColors.gold, size: 40),
              const SizedBox(height: 16),
              const Text(
                'Restore Backup?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This will import all data from the selected file. '
                'Existing records that match imported ones will be skipped; nothing will be deleted.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Restore',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _runImport(file);
    }
  }

  // ─── Import Results ──────────────────────────────────────────────────────
  Widget _buildImportResults() {
    final results = _importResults!;
    final successes = results.where((r) => r.success).length;
    final errors = results.where((r) => !r.success).length;

    return Column(
      children: [
        // Summary banner
        Container(
          margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.overlay.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              _statBadge(
                label: 'Success',
                count: successes,
                color: AppColors.positive,
              ),
              const SizedBox(width: 12),
              _statBadge(
                label: 'Errors',
                count: errors,
                color: errors > 0 ? AppColors.negative : AppColors.textSecondary,
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _importResults = null;
                  _selectedFile = null;
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Info
        if (errors == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.positive.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.positive.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: AppColors.positive, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All records imported successfully! The app will now track messages from your latest imported date onwards.',
                      style:
                          TextStyle(color: AppColors.positive, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Results list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: results.length,
            itemBuilder: (context, i) {
              final r = results[i];
              return _importResultTile(r, i);
            },
          ),
        ),
      ],
    );
  }

  Widget _statBadge(
      {required String label, required int count, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _importResultTile(ImportResult result, int index) {
    final typeLabel = _typeLabel(result.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.overlay.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(
            result.success ? Icons.check_circle : Icons.error_outline,
            color: result.success ? AppColors.positive : AppColors.negative,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  typeLabel,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                if (!result.success && result.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      result.error!,
                      style: TextStyle(
                        color: AppColors.negative.withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          if (!result.success && result.rawData != null)
            GestureDetector(
              onTap: () => _retryItem(index),
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Shared widgets ──────────────────────────────────────────────────────
  Widget _infoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'transaction':
        return 'Transaction';
      case 'sender':
        return 'Sender';
      case 'reason':
        return 'Reason';
      case 'reason_link':
        return 'Reason Rule';
      default:
        return type;
    }
  }
}
