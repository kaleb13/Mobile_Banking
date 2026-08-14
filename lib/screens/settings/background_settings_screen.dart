import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';

class BackgroundSettingsScreen extends StatefulWidget {
  const BackgroundSettingsScreen({super.key});

  @override
  State<BackgroundSettingsScreen> createState() =>
      _BackgroundSettingsScreenState();
}

class _BackgroundSettingsScreenState extends State<BackgroundSettingsScreen>
    with WidgetsBindingObserver {
  bool _isCheckingStatus = true;
  bool _isBatteryIgnored = false;
  int _selectedOemIndex = 0;

  final List<Map<String, dynamic>> _oemGuides = [
    {
      'brand': 'Xiaomi / Poco',
      'subtitle': 'MIUI & HyperOS',
      'icon': Icons.phone_android_rounded,
      'steps': [
        'Open Security or Settings app on your device.',
        'Tap Apps ➔ Manage Apps ➔ Search for "Shibre".',
        'Turn ON "Autostart" permission.',
        'Tap Battery Saver ➔ Select "No restrictions".',
        'Enable "Display pop-up windows in background".'
      ]
    },
    {
      'brand': 'Samsung',
      'subtitle': 'One UI',
      'icon': Icons.smartphone_rounded,
      'steps': [
        'Open Settings ➔ Apps ➔ Select "Shibre".',
        'Tap Battery.',
        'Choose "Unrestricted" (instead of Optimized).',
        'Go to Device Care ➔ Battery ➔ Background usage limits.',
        'Ensure Shibre is NOT in "Never auto-sleeping apps" or "Sleeping apps".'
      ]
    },
    {
      'brand': 'Tecno / Infinix',
      'subtitle': 'HiOS & XOS',
      'icon': Icons.mobile_friendly_rounded,
      'steps': [
        'Open Phone Master app or Settings.',
        'Go to App Management ➔ Auto-start manager.',
        'Enable toggle switch for Shibre.',
        'Go to Power Marathon / Battery ➔ Battery saver.',
        'Exempt Shibre from background optimization.'
      ]
    },
    {
      'brand': 'Stock Android',
      'subtitle': 'Google Pixel / Motorola / Nokia',
      'icon': Icons.devices_other_rounded,
      'steps': [
        'Open Settings ➔ Apps ➔ See all apps ➔ "Shibre".',
        'Tap App battery usage (or Battery).',
        'Select "Unrestricted".',
        'Ensure Allow background usage is enabled.'
      ]
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBatteryOptimizationStatus();
    }
  }

  Future<void> _loadAllSettings() async {
    await _checkBatteryOptimizationStatus();
  }

  Future<void> _checkBatteryOptimizationStatus() async {
    setState(() => _isCheckingStatus = true);
    try {
      final isGranted = await Permission.ignoreBatteryOptimizations.isGranted;
      if (mounted) {
        setState(() {
          _isBatteryIgnored = isGranted;
          _isCheckingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isBatteryIgnored = false;
          _isCheckingStatus = false;
        });
      }
    }
  }



  Future<void> _requestIgnoreBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Battery optimization successfully disabled!'),
            backgroundColor: AppColors.positive,
          ),
        );
      }
    } else {
      await openAppSettings();
    }
    _checkBatteryOptimizationStatus();
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
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                child: Row(
                  children: [
                    const AppBackButton(),
                    const Expanded(
                      child: Text(
                        'Background & Battery',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppColors.textSecondary),
                      onPressed: _checkBatteryOptimizationStatus,
                      tooltip: 'Refresh Status',
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // ── Status Banner Card ───────────────────────────
                      _buildStatusCard(),

                      const SizedBox(height: 20),

                      // ── Actions Section ─────────────────────────────
                      _sectionTitle('Quick Setup Actions'),
                      const SizedBox(height: 8),
                      _buildCardGroup([
                        Consumer<FinanceProvider>(
                          builder: (context, provider, _) {
                            final isEnabled = provider.isSmsListeningEnabled;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (isEnabled ? AppColors.positive : AppColors.textSoft)
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isEnabled
                                          ? Icons.notifications_active_rounded
                                          : Icons.notifications_off_rounded,
                                      color: isEnabled ? AppColors.positive : AppColors.textSoft,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Active SMS Listening',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isEnabled
                                              ? 'Capturing bank SMS & auto-refreshing in real time'
                                              : 'Real-time SMS detection & notifications are turned off',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AppSwitch(
                                    value: isEnabled,
                                    onChanged: (val) => provider.setSmsListeningEnabled(val),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _actionTile(
                          icon: Icons.battery_saver_rounded,
                          iconColor: _isBatteryIgnored
                              ? AppColors.positive
                              : AppColors.amber,
                          title: 'Request Battery Exemption',
                          subtitle: _isBatteryIgnored
                              ? 'Battery optimization disabled (Active)'
                              : 'Tap to request unrestricted background access',
                          trailingText: _isBatteryIgnored ? 'Done' : 'Enable',
                          isPositive: _isBatteryIgnored,
                          onTap: _requestIgnoreBatteryOptimization,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _actionTile(
                          icon: Icons.settings_applications_outlined,
                          iconColor: AppColors.info,
                          title: 'Open System App Settings',
                          subtitle:
                              'Enable Autostart & background permissions manually',
                          trailingText: 'Open',
                          onTap: openAppSettings,
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // ── Live SMS Detection Preview ──────────────────
                      _sectionTitle('Instant Tracking Preview'),
                      const SizedBox(height: 4),
                      const Text(
                        'When background permissions are granted, SMS banking messages will be caught immediately:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildPreviewCard(),

                      const SizedBox(height: 24),

                      // ── Device-Specific Setup Guides ────────────────
                      _sectionTitle('Device Setup Guides'),
                      const SizedBox(height: 4),
                      const Text(
                        'Select your device manufacturer for exact steps:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildOemTabs(),
                      const SizedBox(height: 12),
                      _buildOemGuideCard(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.textPrimary.withValues(alpha: 0.9),
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildStatusCard() {
    final isActive = _isBatteryIgnored;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [
                  AppColors.statusActiveBg,
                  AppColors.surface,
                ]
              : [
                  AppColors.statusWarningBg,
                  AppColors.surface,
                ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isActive ? AppColors.positive : AppColors.amber)
                  .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive
                  ? Icons.shield_rounded
                  : Icons.warning_amber_rounded,
              color: isActive ? AppColors.positive : AppColors.amber,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isActive
                          ? 'REAL-TIME TRACKING ACTIVE'
                          : 'BATTERY OPTIMIZED',
                      style: TextStyle(
                        color: isActive ? AppColors.positive : AppColors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (_isCheckingStatus) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isActive
                      ? 'Background service is running unrestricted. Incoming banking SMS will be processed immediately.'
                      : 'Android or phone battery saver may delay or block instant SMS detection when app is closed.',
                  style: const TextStyle(
                    color: AppColors.textSoft,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String trailingText,
    bool isPositive = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.border,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isPositive
                    ? AppColors.positive.withValues(alpha: 0.15)
                    : AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trailingText,
                style: TextStyle(
                  color: isPositive ? AppColors.positive : AppColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.previewCardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.positive,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Incoming Bank SMS Caught',
                style: TextStyle(
                  color: AppColors.positive,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              const Text(
                'Just Now',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgDeep.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Telebirr / CBE',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '+500.00 ETB',
                      style: TextStyle(
                        color: AppColors.positive,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'You have received 500.00 ETB from John Doe via Telebirr. Ref: TXN981273',
                  style: TextStyle(
                    color: AppColors.textSecondary,
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

  Widget _buildOemTabs() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _oemGuides.length,
        itemBuilder: (context, index) {
          final guide = _oemGuides[index];
          final isSelected = index == _selectedOemIndex;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedOemIndex = index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.gold
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    guide['icon'] as IconData,
                    size: 16,
                    color: isSelected ? AppColors.bgDeep : AppColors.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    guide['brand'] as String,
                    style: TextStyle(
                      color: isSelected ? AppColors.bgDeep : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOemGuideCard() {
    final guide = _oemGuides[_selectedOemIndex];
    final steps = guide['steps'] as List<String>;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                guide['icon'] as IconData,
                color: AppColors.gold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Setup for ${guide['brand']}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                guide['subtitle'] as String,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(steps.length, (idx) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${idx + 1}',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      steps[idx],
                      style: const TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
