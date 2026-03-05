import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../shell/custom_bottom_nav_bar.dart';

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
      await context.read<FinanceProvider>().smartRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Smart Refresh complete ✓'),
            backgroundColor: Color(0xFF3EB489),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleFullReset() async {
    setState(() => _isProcessing = true);
    try {
      await context.read<FinanceProvider>().fullReset();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Full reset complete ✓'),
            backgroundColor: Color(0xFF3EB489),
            duration: Duration(seconds: 2),
          ),
        );
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
                Color(0xFF1F1F25),
                Color(0xFF1B1B21),
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
        bottomNavigationBar: DynamicNavBarWrapper(
          currentIndex: 4,
          onTap: (_) {},
          isDynamic: true,
          heroTag: 'navbar_data_maintenance',
          dynamicActionLabel:
              _tabController.index == 0 ? 'Start Refresh' : 'Reset All',
          dynamicActionIcon: _tabController.index == 0
              ? Icons.refresh_rounded
              : Icons.delete_sweep_rounded,
          onDynamicAdd: () {
            if (_tabController.index == 0) {
              _showConfirmDialog(
                title: 'Smart Refresh',
                content:
                    'This will rescan your messages while keeping your reason tags. Proceed?',
                onConfirm: _handleSmartRefresh,
                confirmText: 'Refresh',
                confirmColor: const Color(0xFF4FC3F7),
              );
            } else {
              _showConfirmDialog(
                title: 'Full Reset',
                content:
                    'This will PERMANENTLY erase all data and rescan everything. This cannot be undone!',
                onConfirm: _handleFullReset,
                confirmText: 'Reset Everything',
                confirmColor: AppColors.alertRed,
              );
            }
          },
          onDynamicBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data Maintenance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'Keep your financial data accurate and clean',
            style: TextStyle(color: AppColors.labelGray, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A34).withValues(alpha: 0.6),
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
        unselectedLabelColor: AppColors.labelGray,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: const [
          Tab(height: 38, text: 'Smart Refresh'),
          Tab(height: 38, text: 'Full Reset'),
        ],
      ),
    );
  }

  Widget _buildRefreshTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _infoCard(
            icon: Icons.auto_awesome_rounded,
            color: const Color(0xFF4FC3F7),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _infoCard(
            icon: Icons.warning_amber_rounded,
            color: AppColors.alertRed,
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Text(title,
                  style: TextStyle(
                      color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Text(body,
              style: const TextStyle(
                  color: AppColors.labelGray, fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }

  Widget _statusItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
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
                      color: AppColors.labelGray, fontSize: 12)),
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
            CircularProgressIndicator(color: AppColors.primaryBlue),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content:
            Text(content, style: const TextStyle(color: AppColors.labelGray)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.labelGray))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(confirmText,
                style: TextStyle(
                    color: confirmColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
