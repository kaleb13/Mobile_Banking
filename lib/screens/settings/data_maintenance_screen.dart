import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_capsule_tab_bar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_toast.dart';

class DataMaintenanceScreen extends StatefulWidget {
  const DataMaintenanceScreen({super.key});

  @override
  State<DataMaintenanceScreen> createState() => _DataMaintenanceScreenState();
}

class _DataMaintenanceScreenState extends State<DataMaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessing = false;

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
    setState(() => _isProcessing = true);
    try {
      await context.read<TransactionsViewModel>().smartRefresh();
      if (mounted) {
        AppToast.success(context, message: 'Smart Refresh complete');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleFullReset() async {
    setState(() => _isProcessing = true);
    try {
      await context.read<TransactionsViewModel>().fullReset();
      if (mounted) {
        AppToast.success(context, message: 'Full reset complete');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _buildHeader(),
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
                    const SizedBox(height: 100), // Padding for navbar
                  ],
                ),
              ),
              if (_isProcessing) _buildLoadingOverlay(),
            ],
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
                        'This will PERMANENTLY erase all data and rescan everything. This cannot be undone!',
                    onConfirm: _handleFullReset,
                    confirmText: 'Reset Everything',
                    confirmColor: AppColors.negative,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 10),
          const Text(
            'Data Maintenance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
      child: Column(
        children: [
          _infoCard(
            icon: Icons.auto_awesome_rounded,
            color: AppColors.infoLight,
            title: 'How Smart Refresh Works',
            body:
                'Smart Refresh scans your SMS inbox for new or missing data while strictly preserving any manual work you\'ve done.\n\n'
                '• Keeps all transactions with reason tags\n'
                '• Repairs missing dates or metadata\n'
                '• Rescans unassigned messages',
          ),
          const SizedBox(height: 32),
          _statusItem(Icons.check_circle_outline, 'Reason Labels Preserved',
              'Your categories and notes are safe.'),
          _statusItem(Icons.check_circle_outline, 'Message Integrity',
              'Missing entries will be restored.'),
          _statusItem(Icons.lock_outline, 'Secure Process',
              'Data is processed locally on your device.'),
        ],
      ),
    );
  }

  Widget _buildResetTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
      child: Column(
        children: [
          _infoCard(
            icon: Icons.warning_amber_rounded,
            color: AppColors.negative,
            title: 'Critical Warning',
            body:
                'A Full Reset is a destructive action that clears your local database entirely. Use this only if you want to start from scratch or if the data is corrupted.\n\n'
                '• Deletes ALL transactions\n'
                '• Clears ALL custom reasons\n'
                '• Rescans ALL SMS from beginning',
          ),
          const SizedBox(height: 32),
          _statusItem(Icons.error_outline, 'Permanent Deletion',
              'Transactions cannot be recovered.'),
          _statusItem(Icons.history_rounded, 'Fresh Start',
              'SMS messages will be re-processed.'),
          _statusItem(Icons.info_outline, 'Backup Recommended',
              'Export your data before resetting.'),
        ],
      ),
    );
  }

  Widget _infoCard(
      {required IconData icon,
      required Color color,
      required String title,
      required String body}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Text(body,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.5)),
        ],
      ),
    );
  }

  Widget _statusItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppColors.textSoft, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.gold),
            SizedBox(height: 20),
            Text('Processing Data...',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500)),
          ],
        ),
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
