import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../services/backup_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_capsule_tab_bar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_scroll_header_bar.dart';
import '../../widgets/app_confirm_dialog.dart';

/// Dedicated Local Offline Backup & Restore Screen.
///
/// Features:
/// - Create JSON backup file to device storage.
/// - Browse and pick any backup file from device or cloud drive.
/// - List and share existing local backup files.
/// - Zero cloud clutter, 100% offline capability.
class LocalBackupScreen extends StatefulWidget {
  const LocalBackupScreen({super.key});

  @override
  State<LocalBackupScreen> createState() => _LocalBackupScreenState();
}

class _LocalBackupScreenState extends State<LocalBackupScreen>
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

  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);

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
    _scrollOffsetNotifier.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBackupFiles() async {
    setState(() => _isLoadingFiles = true);
    try {
      final files = await _backupService.listBackupFiles();
      if (mounted) setState(() => _backupFiles = files);
    } finally {
      if (mounted) setState(() => _isLoadingFiles = false);
    }
  }

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

  Future<void> _runImport(File file) async {
    setState(() {
      _isImporting = true;
      _importResults = null;
    });

    try {
      final results = await _backupService.importBackup(file);
      if (mounted) {
        setState(() {
          _importResults = results;
          _isImporting = false;
        });
        await Provider.of<TransactionsViewModel>(context, listen: false)
            .refreshData();
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

  Future<void> _pickAndRestore() async {
    final file = await _backupService.pickBackupFile();
    if (file == null) return;
    await _loadBackupFiles();
    if (mounted) await _confirmRestore(file);
  }

  Future<void> _confirmRestore(File file) async {
    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: 'Restore Backup?',
      message:
          'This will import all records from "${file.path.split(Platform.pathSeparator).last}". Existing matching transactions will not be duplicated.',
      confirmText: 'Restore Now',
      cancelText: 'Cancel',
      onConfirm: () {},
    );

    if (confirmed == true && mounted) {
      await _runImport(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topSafe = MediaQuery.paddingOf(context).top;
    final headerTotalHeight = topSafe + 56.0 + 54.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: _buildActionBar(),
        body: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.axis == Axis.vertical) {
                  _scrollOffsetNotifier.value =
                      notification.metrics.pixels.clamp(0.0, 60.0);
                }
                return false;
              },
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBackupTab(headerTotalHeight),
                  _buildRestoreTab(headerTotalHeight),
                ],
              ),
            ),

            // Pinned Collapsing Header Bar & Tab Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _scrollOffsetNotifier,
                builder: (context, _) {
                  final progress =
                      (_scrollOffsetNotifier.value / 55.0).clamp(0.0, 1.0);
                  final isScrolled = progress > 0.03;
                  return Container(
                    color: isScrolled ? AppColors.surface : Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppScrollHeaderBar(
                          scrollOffsetListenable: _scrollOffsetNotifier,
                          mode: AppScrollHeaderMode.collapsingTitle,
                          showBackButton: true,
                          initialHeight: 56.0,
                          collapsedHeight: 50.0,
                          initialFontSize: 22.5,
                          scrolledFontSize: 17.0,
                          title: 'Local Backup & Restore',
                          solidBackgroundColor: isScrolled
                              ? AppColors.surface
                              : Colors.transparent,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _buildTabBar(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    final isExportTab = _tabController.index == 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: AppButton.primary(
          text: isExportTab ? 'Create Offline Backup' : 'Browse & Pick File',
          icon: isExportTab ? Icons.save_alt_rounded : Icons.folder_open_rounded,
          height: 50,
          isLoading: isExportTab ? _isExporting : _isImporting,
          onPressed: () {
            if (isExportTab) {
              if (!_isExporting) _runExport();
            } else {
              if (!_isImporting) _pickAndRestore();
            }
          },
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return AppPrimaryTabBar(
      tabs: const ['Create Backup', 'Restore Backup'],
      controller: _tabController,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildBackupTab(double topPadding) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(0, topPadding, 0, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storage_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full Offline Backup',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Creates an encrypted, portable JSON file containing all SMS & cash transactions, categories, saving goals, loans, and settings. You can safely save it to your SD card or Google Drive.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Export results
          if (_exportedPath != null) _exportSuccessCard(),
          if (_exportError != null) _exportErrorCard(),

          // Existing backups
          if (_backupFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'EXISTING LOCAL BACKUPS',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  fontSize: 11,
                ),
              ),
            ),
            ..._backupFiles.map((f) => _backupFileCard(f)),
          ],
        ],
      ),
    );
  }

  Widget _exportSuccessCard() {
    final fileName = _exportedPath!.split(Platform.pathSeparator).last;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.positive, size: 20),
              const SizedBox(width: 10),
              Text(
                'Backup Created Successfully',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            fileName,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  text: 'Share Backup',
                  icon: Icons.share_outlined,
                  height: 38,
                  fontSize: 12,
                  onPressed: () {
                    // ignore: deprecated_member_use
                    Share.shareXFiles([XFile(_exportedPath!)]);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _exportErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.negative, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Backup failed: $_exportError',
              style: AppTypography.caption.copyWith(
                color: AppColors.negative,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backupFileCard(File file) {
    final name = file.path.split(Platform.pathSeparator).last;
    final stat = file.statSync();
    final size = (stat.size / 1024).toStringAsFixed(1);
    final modified = DateFormat('MMM d, yyyy  HH:mm').format(stat.modified);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$modified  •  $size KB',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.textSecondary, size: 18),
            onPressed: () {
              // ignore: deprecated_member_use
              Share.shareXFiles([XFile(file.path)]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreTab(double topPadding) {
    return _importResults != null
        ? _buildImportResultsView(topPadding)
        : _buildRestorePickerView(topPadding);
  }

  Widget _buildRestorePickerView(double topPadding) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(0, topPadding, 0, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.settings_backup_restore_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Restore Financial Records',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select an existing backup file below or tap Browse to import a file from Google Drive, Telegram, or internal storage.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingFiles)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.textPrimary,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_backupFiles.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No local backups found on device.\nTap "Browse & Pick File" to locate a backup.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'AVAILABLE LOCAL BACKUPS',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  fontSize: 11,
                ),
              ),
            ),
            ..._backupFiles.map((f) => _restoreFileCard(f)),
          ],
        ],
      ),
    );
  }

  Widget _restoreFileCard(File file) {
    final name = file.path.split(Platform.pathSeparator).last;
    final stat = file.statSync();
    final size = (stat.size / 1024).toStringAsFixed(1);
    final modified = DateFormat('MMM d, yyyy  HH:mm').format(stat.modified);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: _isImporting ? null : () => _confirmRestore(file),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.restore_page_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$modified  •  $size KB',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    ),
  ),
);
}

  Widget _buildImportResultsView(double topPadding) {
    final results = _importResults!;
    final successes = results.where((r) => r.success).length;
    final errors = results.where((r) => !r.success).length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(0, topPadding, 0, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      errors == 0 ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      color: errors == 0 ? AppColors.positive : AppColors.gold,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      errors == 0 ? 'Restore Completed' : 'Restore Completed with Warnings',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$successes sections imported successfully.${errors > 0 ? ' $errors items skipped or failed.' : ''}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                AppButton.secondary(
                  text: 'Dismiss Results',
                  height: 36,
                  fontSize: 12,
                  onPressed: () {
                    setState(() => _importResults = null);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'DETAILED LOG',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                fontSize: 11,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: results
                  .map((r) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              r.success ? Icons.check_rounded : Icons.close_rounded,
                              color: r.success ? AppColors.positive : AppColors.negative,
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                r.label,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
