import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../models/scan_window_option.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_capsule_tab_bar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_toast.dart';
import 'maintenance_progress_dialog.dart';

class DataMaintenanceScreen extends StatefulWidget {
  const DataMaintenanceScreen({super.key});

  @override
  State<DataMaintenanceScreen> createState() => _DataMaintenanceScreenState();
}

class _DataMaintenanceScreenState extends State<DataMaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleSmartRefresh() async {
    final txVM = context.read<TransactionsViewModel>();
    final ctrl = await showMaintenanceProgressDialog(
      context: context,
      title: 'Smart Refresh',
      accentColor: AppColors.brandGreen,
    );

    ctrl.setSteps([
      const MaintenanceStep(label: 'Scanning SMS inbox'),
      const MaintenanceStep(label: 'Parsing bank transactions'),
      const MaintenanceStep(label: 'Storing verified data'),
      const MaintenanceStep(label: 'Calculating balance & tier'),
    ]);

    await Future.delayed(const Duration(milliseconds: 300));

    try {
      ctrl.updateStep(0, MaintenanceStepStatus.running);
      ctrl.setProgress(0.05, 'Connecting to SMS inbox…');

      await txVM.smartRefresh(
        onProgress: (status) {
          if (status.progress >= 0.05 && status.progress < 0.35) {
            ctrl.updateStep(0, MaintenanceStepStatus.running);
            ctrl.setProgress(status.progress * 0.4, status.stage);
          } else if (status.progress >= 0.35 && status.progress < 0.55) {
            ctrl.updateStep(0, MaintenanceStepStatus.done);
            ctrl.updateStep(1, MaintenanceStepStatus.running);
            ctrl.setProgress(0.2 + status.progress * 0.3, status.stage);
          } else if (status.progress >= 0.55 && status.progress < 0.80) {
            ctrl.updateStep(1, MaintenanceStepStatus.done);
            ctrl.updateStep(2, MaintenanceStepStatus.running);
            ctrl.setProgress(0.4 + status.progress * 0.3, status.stage);
            if (status.scannedBanks.isNotEmpty) {
              ctrl.setScanStatus(status);
            }
          } else if (status.progress >= 0.80) {
            ctrl.updateStep(2, MaintenanceStepStatus.done);
            ctrl.updateStep(3, MaintenanceStepStatus.running);
            ctrl.setProgress(0.7 + status.progress * 0.2, status.stage);
            if (status.scannedBanks.isNotEmpty) {
              ctrl.setScanStatus(status);
            }
          }

          if (status.isComplete) {
            ctrl.updateStep(3, MaintenanceStepStatus.done);
            if (status.scannedBanks.isNotEmpty) {
              ctrl.setScanStatus(status);
            }
            ctrl.complete();
          }
        },
      );

      if (!ctrl.isComplete) {
        for (int i = 0; i < 4; i++) {
          ctrl.updateStep(i, MaintenanceStepStatus.done);
        }
        ctrl.complete();
      }

      if (mounted) {
        AppToast.success(context, message: 'Smart Refresh complete');
      }
    } catch (e) {
      ctrl.complete();
    }
  }

  Future<void> _handleFullReset() async {
    final txVM = context.read<TransactionsViewModel>();
    final ctrl = await showMaintenanceProgressDialog(
      context: context,
      title: 'Full Reset',
      accentColor: AppColors.negative,
    );

    ctrl.setSteps([
      const MaintenanceStep(label: 'Deleting all transactions'),
      const MaintenanceStep(label: 'Clearing all custom reasons'),
      const MaintenanceStep(label: 'Resetting notifications'),
      const MaintenanceStep(label: 'Scanning SMS from beginning'),
      const MaintenanceStep(label: 'Parsing banking transactions'),
      const MaintenanceStep(label: 'Storing verified data & balances'),
    ]);

    await Future.delayed(const Duration(milliseconds: 300));

    try {
      // Step 1: Delete all transactions
      ctrl.updateStep(0, MaintenanceStepStatus.running);
      ctrl.setProgress(0.05, 'Deleting all transactions…');
      await txVM.fullResetStep1DeleteTransactions();
      ctrl.updateStep(0, MaintenanceStepStatus.done);

      // Step 2: Clear all custom reasons
      ctrl.updateStep(1, MaintenanceStepStatus.running);
      ctrl.setProgress(0.12, 'Clearing custom reason mappings…');
      await txVM.fullResetStep2ClearCustomReasons();
      ctrl.updateStep(1, MaintenanceStepStatus.done);

      // Step 3: Delete notifications
      ctrl.updateStep(2, MaintenanceStepStatus.running);
      ctrl.setProgress(0.20, 'Clearing notifications cache…');
      await txVM.fullResetStep3DeleteNotifications();
      ctrl.updateStep(2, MaintenanceStepStatus.done);

      // Steps 4-6: Re-scan SMS from beginning
      ctrl.updateStep(3, MaintenanceStepStatus.running);
      ctrl.setProgress(0.28, 'Connecting to SMS archive…');

      await txVM.scanSms(
        scanWindowOption: ScanWindowOption.allTime,
        onProgress: (status) {
          if (status.progress >= 0.05 && status.progress < 0.35) {
            ctrl.updateStep(3, MaintenanceStepStatus.running);
            ctrl.setProgress(0.28 + status.progress * 0.15, status.stage);
          } else if (status.progress >= 0.35 && status.progress < 0.55) {
            ctrl.updateStep(3, MaintenanceStepStatus.done);
            ctrl.updateStep(4, MaintenanceStepStatus.running);
            ctrl.setProgress(0.42 + status.progress * 0.2, status.stage);
          } else if (status.progress >= 0.55 && status.progress < 0.80) {
            ctrl.updateStep(4, MaintenanceStepStatus.done);
            ctrl.updateStep(5, MaintenanceStepStatus.running);
            ctrl.setProgress(0.60 + status.progress * 0.2, status.stage);
            if (status.scannedBanks.isNotEmpty) {
              ctrl.setScanStatus(status);
            }
          } else if (status.progress >= 0.80) {
            ctrl.updateStep(5, MaintenanceStepStatus.running);
            ctrl.setProgress(0.80 + status.progress * 0.15, status.stage);
            if (status.scannedBanks.isNotEmpty) {
              ctrl.setScanStatus(status);
            }
          }

          if (status.isComplete) {
            ctrl.updateStep(5, MaintenanceStepStatus.done);
            if (status.scannedBanks.isNotEmpty) {
              ctrl.setScanStatus(status);
            }
            ctrl.complete();
          }
        },
      );

      if (!ctrl.isComplete) {
        for (int i = 0; i < 6; i++) {
          ctrl.updateStep(i, MaintenanceStepStatus.done);
        }
        ctrl.complete();
      }

      if (mounted) {
        AppToast.success(context, message: 'Full reset complete');
      }
    } catch (e) {
      ctrl.complete();
    }
  }

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
                const AppHeader(
                  title: 'Data Maintenance',
                ),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRefreshTab(),
                      _buildResetTab(),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildActionBar(),
      ),
    );
  }

  Widget _buildActionBar() {
    final isRefreshTab = _tabController.index == 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: isRefreshTab
            ? AppButton.primary(
                text: 'Start Refresh',
                icon: Icons.refresh_rounded,
                height: 50,
                onPressed: () {
                  _showConfirmDialog(
                    title: 'Smart Refresh',
                    content:
                        'This will rescan your messages while keeping your reason tags. Proceed?',
                    onConfirm: _handleSmartRefresh,
                    confirmText: 'Refresh',
                    confirmColor: AppColors.infoLight,
                  );
                },
              )
            : AppButton.destructive(
                text: 'Reset All',
                icon: Icons.delete_sweep_rounded,
                height: 50,
                onPressed: () {
                  _showConfirmDialog(
                    title: 'Full Reset',
                    content:
                        'This will PERMANENTLY erase all transactions and custom reasons, then rescan all SMS from the beginning. This cannot be undone!',
                    onConfirm: _handleFullReset,
                    confirmText: 'Reset Everything',
                    confirmColor: AppColors.negative,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildTabBar() {
    return AppPrimaryTabBar(
      tabs: const ['Smart Refresh', 'Full Reset'],
      controller: _tabController,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }

  Widget _buildRefreshTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          _buildInfoCard(
            context: context,
            icon: Icons.auto_awesome_rounded,
            accentColor: AppColors.infoLight,
            title: 'How Smart Refresh Works',
            body:
                'Smart Refresh scans your SMS inbox for new or missing data while strictly preserving any manual work you have done.\n\n'
                '• Keeps all transactions with reason tags\n'
                '• Repairs missing dates or metadata\n'
                '• Rescans unassigned messages',
          ),
          const SizedBox(height: 24),
          _buildStatusItem(
            context: context,
            icon: Icons.check_circle_outline_rounded,
            title: 'Reason Labels Preserved',
            subtitle: 'Your categories and notes are safe.',
          ),
          _buildStatusItem(
            context: context,
            icon: Icons.check_circle_outline_rounded,
            title: 'Message Integrity',
            subtitle: 'Missing entries will be restored.',
          ),
          _buildStatusItem(
            context: context,
            icon: Icons.lock_outline_rounded,
            title: 'Secure Process',
            subtitle: 'Data is processed locally on your device.',
          ),
        ],
      ),
    );
  }

  Widget _buildResetTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          _buildInfoCard(
            context: context,
            icon: Icons.warning_amber_rounded,
            accentColor: AppColors.negative,
            title: 'Critical Warning',
            body:
                'A Full Reset is a destructive action that clears your local database entirely. Use this only if you want to start from scratch or if the data is corrupted.\n\n'
                '• Deletes ALL transactions\n'
                '• Clears ALL custom reasons & links\n'
                '• Rescans ALL SMS from the beginning',
          ),
          const SizedBox(height: 24),
          _buildStatusItem(
            context: context,
            icon: Icons.error_outline_rounded,
            title: 'Permanent Deletion',
            subtitle: 'Transactions and custom reasons cannot be recovered.',
          ),
          _buildStatusItem(
            context: context,
            icon: Icons.history_rounded,
            title: 'Fresh Start',
            subtitle: 'SMS messages will be re-processed from scratch.',
          ),
          _buildStatusItem(
            context: context,
            icon: Icons.info_outline_rounded,
            title: 'Full Rescan',
            subtitle: 'Calculates all historical balances and account tiers.',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String body,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      customColor: AppColors.surface,
      borderRadius: AppRadius.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.heading2.copyWith(
                    color: context.themeTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            body,
            style: AppTypography.bodySmall.copyWith(
              color: context.themeTextSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: context.themeTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: context.themeTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
    required String confirmText,
    required Color confirmColor,
  }) {
    AppConfirmDialog.show(
      context: context,
      title: title,
      icon: confirmColor == AppColors.negative
          ? Icons.warning_amber_rounded
          : Icons.info_outline_rounded,
      iconColor: confirmColor,
      message: content,
      confirmText: confirmText,
      cancelText: 'Cancel',
      isDestructive: confirmColor == AppColors.negative,
      onConfirm: onConfirm,
    );
  }
}
