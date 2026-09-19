import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_scroll_header_bar.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/bank_senders.dart';
import '../../services/bank_registry.dart';
import '../../presentation/viewmodels/cloud_sync_view_model.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../presentation/viewmodels/auth_view_model.dart';
import '../../widgets/account_sms_mode_drawer.dart';

/// Dedicated, uncluttered Cloud Backup & Sync Screen.
///
/// Follows Clean Architecture & MVVM with state managed by [CloudSyncViewModel].
///
/// Features:
/// - Clear 3-metric progress section:
///   1. How many SMS on this device
///   2. How many are backed up in the cloud
///   3. How much is left (pending upload)
/// - Batch failure tracking with a single "Retry Failed Batches" action.
/// - Contributing physical devices list with purge option.
/// - Bank-level sync filters.
class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  bool _showAdvancedSettings = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CloudSyncViewModel>().refreshState();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleRetryBatches(CloudSyncViewModel syncVM) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await syncVM.retryFailedBatches();
    if (mounted) {
      final txVM = context.read<TransactionsViewModel>();
      await txVM.refreshData();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Successfully retried failed batches.'
                : 'Some batches still failed to upload. Check internet connection.',
          ),
          backgroundColor: success ? AppColors.positive : AppColors.negative,
        ),
      );
    }
  }

  Future<void> _triggerFullSync(CloudSyncViewModel syncVM) async {
    final txVM = context.read<TransactionsViewModel>();
    await syncVM.syncNow();
    if (mounted) {
      await txVM.refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncVM = context.watch<CloudSyncViewModel>();
    final txVM = context.watch<TransactionsViewModel>();
    final topSafe = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            RefreshIndicator(
              color: AppColors.textPrimary,
              backgroundColor: AppColors.surface,
              edgeOffset: topSafe + 56.0,
              onRefresh: () async {
                await syncVM.refreshState();
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: topSafe + 56.0),
                    // 1. Account & Connection Status
                    _buildAccountConnectionCard(syncVM),

                    const SizedBox(height: 12),

                    // 2. The Core Highlight: Progress & Metrics Card
                    if (syncVM.isSyncEnabled && syncVM.isAuthenticated)
                      _buildProgressSection(syncVM),

                    // 3. Batch Error & Retry Section (if any batch failed)
                    _buildFailedBatchesCard(syncVM),

                    const SizedBox(height: 12),

                    // 4. Advanced Settings / Bank & Device Management Accordion
                    if (syncVM.isSyncEnabled && syncVM.isAuthenticated)
                      _buildAdvancedSection(syncVM, txVM),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // Pinned Collapsing Header Bar on Scroll
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppScrollHeaderBar(
                scrollController: _scrollController,
                mode: AppScrollHeaderMode.collapsingTitle,
                showBackButton: true,
                initialHeight: 56.0,
                collapsedHeight: 50.0,
                initialFontSize: 22.5,
                scrolledFontSize: 17.0,
                title: 'Cloud Backup & Sync',
                trailing: syncVM.isLoadingDetails
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textSecondary),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh,
                            color: AppColors.textPrimary, size: 20),
                        tooltip: 'Refresh Status',
                        onPressed: () => syncVM.refreshState(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  // ─── Account & Connection Card ──────────────────────────────────────────
  Widget _buildAccountConnectionCard(CloudSyncViewModel syncVM) {
    final isAuthenticated = syncVM.isAuthenticated;
    final authVM = context.read<AuthViewModel>();

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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAuthenticated
                          ? (authVM.displayName ?? 'Google Account')
                          : 'Cloud Synchronization',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAuthenticated
                          ? (syncVM.userEmail ?? 'Connected')
                          : 'Sign in to access from PC & devices',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AppSwitch(
                value: syncVM.isSyncEnabled,
                onChanged: (val) async {
                  if (val && !isAuthenticated) {
                    try {
                      final success = await authVM.signInWithGoogle();
                      if (success) {
                        await syncVM.toggleCloudSync(true);
                        if (!mounted) return;
                        await AccountSmsModeDrawer.promptIfUnconfigured(
                          context: context,
                          authVM: authVM,
                        );
                      }
                    } catch (_) {}
                    return;
                  }
                  await syncVM.toggleCloudSync(val);
                },
              ),
            ],
          ),
          if (!syncVM.isSyncEnabled && !isAuthenticated) ...[
            const SizedBox(height: 14),
            Text(
              'Sign in with Google to back up your SMS transactions to the cloud. You can seamlessly access your finances from the desktop app and other devices.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            AppButton.primary(
              text: 'Sign In with Google',
              icon: Icons.login,
              height: 44,
              fontSize: 13,
              fullWidth: true,
              onPressed: () async {
                try {
                  final success = await authVM.signInWithGoogle();
                  if (success) {
                    await syncVM.toggleCloudSync(true);
                    if (!mounted) return;
                    await AccountSmsModeDrawer.promptIfUnconfigured(
                      context: context,
                      authVM: authVM,
                    );
                  }
                } catch (_) {}
              },
            ),
          ],
        ],
      ),
    );
  }

  // ─── Progress & Storage Section ───────────────────────────────────────────
  Widget _buildProgressSection(CloudSyncViewModel syncVM) {
    final progress = syncVM.progress;
    final status = syncVM.status;
    final lastSynced = syncVM.lastSynced;
    final isSyncing = status == CloudSyncStatus.syncing || progress.isSyncing;

    String timeLabel = 'Never';
    if (lastSynced != null) {
      final diff = DateTime.now().difference(lastSynced);
      if (diff.inMinutes < 1) {
        timeLabel = 'Just now';
      } else if (diff.inHours < 1) {
        timeLabel = '${diff.inMinutes}m ago';
      } else {
        timeLabel = DateFormat('MMM d, HH:mm').format(lastSynced);
      }
    }

    final percent = progress.percentInCloud;
    final fraction = progress.fractionInCloud;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SMS SYNC PROGRESS',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  fontSize: 11,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${percent.toStringAsFixed(0)}% BACKED UP',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // The 3 KPI Metric Cards
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  label: 'On This Device',
                  value: '${progress.deviceTotal}',
                  subtitle: progress.disabledBankCount > 0
                      ? '${progress.disabledBankCount} disabled'
                      : 'Sync enabled',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricBox(
                  label: 'In Cloud',
                  value: '${progress.cloudCount}',
                  subtitle: 'Stored safe',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricBox(
                  label: 'Remaining',
                  value: '${progress.pendingCount}',
                  subtitle: progress.pendingCount == 0 ? 'All uploaded' : 'Left to sync',
                  isAccent: progress.pendingCount > 0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Visual Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Container(
              height: 6,
              width: double.infinity,
              color: AppColors.tabBackground,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction,
                child: Container(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Dynamic Status Row
          Row(
            children: [
              Icon(
                isSyncing
                    ? Icons.sync
                    : (status == CloudSyncStatus.offline
                        ? Icons.cloud_off_rounded
                        : (progress.pendingCount == 0
                            ? Icons.check_circle_rounded
                            : Icons.cloud_upload_outlined)),
                size: 15,
                color: status == CloudSyncStatus.offline
                    ? AppColors.gold
                    : (progress.pendingCount == 0
                        ? AppColors.textPrimary
                        : AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSyncing
                      ? 'Uploading batch ${progress.currentBatchUploaded} of ${progress.totalToUpload}…'
                      : (status == CloudSyncStatus.offline
                          ? 'Offline • Changes saved locally'
                          : (progress.pendingCount == 0
                              ? 'All SMS backed up • Last synced $timeLabel'
                              : '${progress.pendingCount} SMS pending upload')),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              AppButton.secondary(
                text: isSyncing ? 'Syncing…' : 'Sync Now',
                icon: Icons.sync,
                isLoading: isSyncing,
                fullWidth: false,
                height: 32,
                fontSize: 11,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                onPressed: isSyncing ? null : () => _triggerFullSync(syncVM),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBox({
    required String label,
    required String value,
    required String subtitle,
    bool isAccent = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.headline.copyWith(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── Batch Error & Retry Section ──────────────────────────────────────────
  Widget _buildFailedBatchesCard(CloudSyncViewModel syncVM) {
    final progress = syncVM.progress;
    if (progress.failedCount <= 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.negative.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.negative,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${progress.failedCount} SMS Failed to Upload',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      progress.failureMessage ?? 'A network interruption prevented some batches from syncing.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppButton.primary(
            text: syncVM.isRetryingBatch
                ? 'Retrying Batches…'
                : 'Retry Failed Batches (${progress.failedCount})',
            icon: Icons.refresh_rounded,
            height: 40,
            fontSize: 12,
            isLoading: syncVM.isRetryingBatch,
            fullWidth: true,
            onPressed: syncVM.isRetryingBatch ? null : () => _handleRetryBatches(syncVM),
          ),
        ],
      ),
    );
  }

  // ─── Advanced Management Section (Devices & Banks) ────────────────────────
  Widget _buildAdvancedSection(CloudSyncViewModel syncVM, TransactionsViewModel txVM) {
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _showAdvancedSettings = !_showAdvancedSettings);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEVICE & BANK CONTROLS',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage connected devices and bank sync filters',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showAdvancedSettings
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),

          if (_showAdvancedSettings) ...[
            const SizedBox(height: 16),

            // 1. Contributing Devices List
            _buildContributingDevicesList(syncVM),

            const SizedBox(height: 16),

            // 2. Bank Sync Controls List
            _buildBankSyncControlsList(syncVM, txVM),
          ],
        ],
      ),
    );
  }

  Widget _buildContributingDevicesList(CloudSyncViewModel syncVM) {
    final currentFingerprint = syncVM.currentDeviceFingerprint;
    final devices = syncVM.cloudDevices;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.devices_outlined, size: 16, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                'Contributing Physical Devices',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Devices that uploaded transactions to this account. Purge secondary devices anytime without deleting local phone records.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          if (devices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No device uploads recorded in cloud yet.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
            )
          else
            ...devices.map((device) {
              final fp = (device['device_fingerprint'] as String?) ?? 'unspecified_device';
              final rawModel = (device['device_model'] as String?) ?? 'Unknown Device';
              final count = (device['count'] as int?) ?? 0;
              final isCurrent = fp == currentFingerprint;
              final displayModel = _formatDeviceDisplayName(rawModel);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.buttonSecondary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.smartphone_rounded,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayModel,
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 6),
                                const AppBadge.success(
                                  text: 'THIS PHONE',
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$count transactions backed up',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppButton.softDestructive(
                      text: 'Purge',
                      fontSize: 11,
                      fullWidth: false,
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      onPressed: () => _confirmPurgeDevice(syncVM, fp, displayModel, count, isCurrent),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBankSyncControlsList(CloudSyncViewModel syncVM, TransactionsViewModel txVM) {
    final Map<String, int> bankDeviceCounts = {};
    for (final tx in txVM.transactions) {
      if (tx.bankName.isNotEmpty) {
        final canonical = BankSenders.match(tx.bankName) ?? tx.bankName;
        bankDeviceCounts[canonical] = (bankDeviceCounts[canonical] ?? 0) + 1;
      }
    }

    final Map<String, int> bankCloudCounts = {};
    for (final b in syncVM.cloudBanks) {
      final rawName = b['bank_name'] as String? ?? '';
      if (rawName.isEmpty) continue;
      final canonical = BankSenders.match(rawName) ?? rawName;
      final count = b['count'] as int? ?? 0;
      bankCloudCounts[canonical] = (bankCloudCounts[canonical] ?? 0) + count;
    }

    final Set<String> allBanks = {};
    for (final bank in BankRegistry.instance.allBanks) {
      if (bank.bankName.isNotEmpty) {
        allBanks.add(BankSenders.match(bank.bankName) ?? bank.bankName);
      }
    }
    const fallbackBanks = [
      'Telebirr',
      'CBE',
      'CBE Birr',
      'BOA',
      'Dashen Bank',
      'Ahadu Bank',
      'Awash Bank',
      'Zemen Bank',
      'Nib Bank',
      'Bunna Bank',
    ];
    for (final b in fallbackBanks) {
      allBanks.add(BankSenders.match(b) ?? b);
    }
    for (final name in txVM.uniqueBanks) {
      if (name.isNotEmpty) {
        allBanks.add(BankSenders.match(name) ?? name);
      }
    }

    const priorityOrder = [
      'Telebirr',
      'CBE',
      'CBE Birr',
      'BOA',
      'Dashen Bank',
      'Awash Bank',
      'Ahadu Bank',
      'Zemen Bank',
      'Nib Bank',
      'Bunna Bank',
    ];

    final sortedBanks = allBanks.toList()
      ..sort((a, b) {
        final indexA = priorityOrder.indexOf(a);
        final indexB = priorityOrder.indexOf(b);
        if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
        if (indexA != -1) return -1;
        if (indexB != -1) return 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_outlined, size: 16, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                'Per-Bank Cloud Sync & Purge',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Control which banks sync to cloud, or purge backed-up cloud copies for any bank.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          ...sortedBanks.map((bankName) {
            final isPaused = txVM.pausedBanks.any(
              (b) => !b.contains(':') && BankSenders.isSameBank(b, bankName),
            );
            final isDisabled = syncVM.disabledSyncBanks.any(
              (b) => BankSenders.isSameBank(b, bankName),
            );
            final isSyncOn = !isPaused && !isDisabled;
            final deviceCount = bankDeviceCounts[bankName] ?? 0;
            final cloudCount = bankCloudCounts[bankName] ?? 0;

            String statusSubtitle;
            if (isPaused) {
              statusSubtitle = '$deviceCount on device • Tracking paused';
            } else if (!isSyncOn) {
              statusSubtitle = '$deviceCount on device • Sync disabled';
            } else {
              statusSubtitle = '$deviceCount on device • $cloudCount in cloud';
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bankName,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          statusSubtitle,
                          style: AppTypography.caption.copyWith(
                            color: isPaused
                                ? AppColors.gold
                                : (!isSyncOn ? AppColors.textSecondary : AppColors.textSecondary),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (cloudCount > 0) ...[
                    AppButton.softDestructive(
                      text: 'Purge',
                      fontSize: 11,
                      fullWidth: false,
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      onPressed: () => _confirmPurgeBank(syncVM, bankName, cloudCount),
                    ),
                    const SizedBox(width: 8),
                  ],
                  AppSwitch(
                    value: isSyncOn,
                    onChanged: (val) {
                      if (isPaused) return;
                      syncVM.setBankSyncEnabled(bankName, val);
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatDeviceDisplayName(String rawModel) {
    final lower = rawModel.toLowerCase().trim();
    if (lower.contains('sdk_gphone') || lower.contains('emulator') || lower.contains('goldfish')) {
      return 'Android Emulator ($rawModel)';
    }
    if (lower.contains('desktop') || lower.contains('windows')) {
      return 'Windows Desktop ($rawModel)';
    }
    if (lower.isEmpty || lower == 'unspecified_device' || lower == 'unknown device') {
      return 'Initial Sync (Legacy Device)';
    }
    return rawModel;
  }

  Future<void> _confirmPurgeBank(CloudSyncViewModel syncVM, String bankName, int count) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: 'Purge $bankName Cloud Data?',
      message:
          'This will permanently delete all $count backed-up $bankName transactions from your cloud account. '
          'Your local transactions on this device will NOT be deleted.',
      confirmText: 'Purge Cloud Copy',
      cancelText: 'Cancel',
      onConfirm: () {},
    );
    if (confirmed == true && mounted) {
      final success = await syncVM.purgeBank(bankName);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Successfully purged $bankName from cloud.'
                  : 'Failed to purge $bankName cloud transactions.',
            ),
            backgroundColor: success ? AppColors.positive : AppColors.negative,
          ),
        );
      }
    }
  }

  Future<void> _confirmPurgeDevice(CloudSyncViewModel syncVM, String fp, String model, int count, bool isCurrent) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: 'Purge Cloud Data for $model?',
      message:
          'This will delete all $count transactions uploaded by this physical device from your cloud account. '
          'Transactions stored locally on this phone will NOT be deleted.',
      confirmText: 'Purge Device Data',
      cancelText: 'Cancel',
      onConfirm: () {},
    );
    if (confirmed == true && mounted) {
      final success = await syncVM.purgeDevice(fp);
      if (isCurrent && success) {
        await syncVM.toggleCloudSync(false);
      }
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Successfully purged $model transactions from cloud.'
                  : 'Failed to purge device cloud transactions.',
            ),
            backgroundColor: success ? AppColors.positive : AppColors.negative,
          ),
        );
      }
    }
  }
}
