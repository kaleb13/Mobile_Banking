import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../services/backup_service.dart';
import '../../theme/app_theme.dart';
import '../shell/custom_bottom_nav_bar.dart';

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
      if (mounted) {
        setState(() {
          _exportedPath = path;
          _isExporting = false;
        });
        // Refresh file list
        await _loadBackupFiles();
      }
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
        bottomNavigationBar: DynamicNavBarWrapper(
          currentIndex: 4,
          onTap: (_) {},
          isDynamic: true,
          dynamicActionLabel: 'Create Backup',
          dynamicActionIcon: Icons.backup_outlined,
          onDynamicAdd: _isExporting ? null : _runExport,
          onDynamicBack: () => Navigator.pop(context),
        ),
        body: SafeArea(
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
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textGray,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        tabs: const [
          Tab(text: '  Backup  '),
          Tab(text: '  Restore  '),
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
            color: AppColors.primaryBlue,
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
                color: AppColors.textGray,
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
    final fileName = _exportedPath!.split('/').last;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mintGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.mintGreen.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              color: AppColors.mintGreen, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backup created successfully!',
                  style: TextStyle(
                    color: AppColors.mintGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fileName,
                  style: TextStyle(
                    color: AppColors.mintGreen.withValues(alpha: 0.7),
                    fontSize: 11,
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
        color: AppColors.alertRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.alertRed.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.alertRed, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Backup failed: $_exportError',
              style: const TextStyle(color: AppColors.alertRed, fontSize: 12),
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
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description_outlined,
                color: AppColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textWhite,
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
                    color: AppColors.textGray,
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
            color: AppColors.primaryBlue,
            title: 'Restore from Backup',
            body:
                'Tap a backup file below to restore. Existing transactions will be '
                'kept and the system will start scanning SMS messages from the date '
                'of your latest imported transaction onwards.',
          ),
          const SizedBox(height: 24),
          if (_isLoadingFiles)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(
                  color: AppColors.primaryBlue,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_backupFiles.isEmpty)
            _noBackupsPlaceholder()
          else ...[
            const Text(
              'SELECT A BACKUP TO RESTORE',
              style: TextStyle(
                color: AppColors.textGray,
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
                      color: AppColors.primaryBlue,
                      strokeWidth: 2,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Importing data...',
                      style: TextStyle(color: AppColors.textGray, fontSize: 13),
                    ),
                    if (_selectedFile != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _selectedFile!.path.split('/').last,
                          style: const TextStyle(
                            color: AppColors.textGray,
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
            color: AppColors.textGray.withValues(alpha: 0.4),
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'No backups found',
            style: TextStyle(color: AppColors.textGray, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            'Go to the Backup tab to create your first backup.',
            style: TextStyle(
              color: AppColors.textGray.withValues(alpha: 0.6),
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
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.restore_outlined,
                  color: AppColors.primaryBlue, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.textWhite,
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
                      color: AppColors.textGray,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textGray, size: 13),
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
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restore_outlined,
                  color: AppColors.primaryBlue, size: 40),
              const SizedBox(height: 16),
              const Text(
                'Restore Backup?',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This will import all data from the selected file. '
                'Existing records that match imported ones will be skipped; nothing will be deleted.',
                style: TextStyle(color: AppColors.textGray, fontSize: 13),
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
                          style: TextStyle(color: AppColors.textGray),
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
                          color: AppColors.primaryBlue.withValues(alpha: 0.85),
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
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _statBadge(
                label: 'Success',
                count: successes,
                color: AppColors.mintGreen,
              ),
              const SizedBox(width: 12),
              _statBadge(
                label: 'Errors',
                count: errors,
                color: errors > 0 ? AppColors.alertRed : AppColors.textGray,
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
                    style: TextStyle(color: AppColors.textGray, fontSize: 12),
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
                color: AppColors.mintGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.mintGreen.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: AppColors.mintGreen, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All records imported successfully! The app will now track messages from your latest imported date onwards.',
                      style:
                          TextStyle(color: AppColors.mintGreen, fontSize: 12),
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
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.success
              ? Colors.white.withValues(alpha: 0.04)
              : AppColors.alertRed.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            result.success ? Icons.check_circle : Icons.error_outline,
            color: result.success ? AppColors.mintGreen : AppColors.alertRed,
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
                    color: AppColors.textWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  typeLabel,
                  style: const TextStyle(
                    color: AppColors.textGray,
                    fontSize: 10,
                  ),
                ),
                if (!result.success && result.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      result.error!,
                      style: TextStyle(
                        color: AppColors.alertRed.withValues(alpha: 0.8),
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
                  color: AppColors.primaryBlue.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
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
                    color: AppColors.textGray,
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
