import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/pin_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

enum _PinFlowMode { setNew, confirmNew, verifyOld }

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen>
    with SingleTickerProviderStateMixin {
  bool _lockEnabled = false;
  bool _biometricEnabled = false;
  bool _canUseBiometrics = false;
  bool _hasPin = false;

  // PIN entry overlay state
  bool _showPinEntry = false;
  _PinFlowMode _flowMode = _PinFlowMode.setNew;
  String _enteredPin = '';
  String _firstPin = ''; // used for confirm step
  bool _isError = false;
  String _errorMsg = '';

  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _loadState();
  }

  Future<void> _loadState() async {
    final lockEnabled = await PinService.instance.isLockEnabled();
    final biometric = await PinService.instance.isBiometricEnabled();
    final canBio = await PinService.instance.canUseBiometrics();
    final hasPin = await PinService.instance.hasPin();
    if (mounted) {
      setState(() {
        _lockEnabled = lockEnabled;
        _biometricEnabled = biometric;
        _canUseBiometrics = canBio;
        _hasPin = hasPin;
      });
    }
  }

  // ── PIN Entry Flow ────────────────────────────────────────────────────────

  void _startSetPin() {
    setState(() {
      _flowMode = _PinFlowMode.setNew;
      _enteredPin = '';
      _firstPin = '';
      _isError = false;
      _errorMsg = '';
      _showPinEntry = true;
    });
  }

  void _startChangePin() {
    // If already has PIN, verify old first
    setState(() {
      _flowMode = _hasPin ? _PinFlowMode.verifyOld : _PinFlowMode.setNew;
      _enteredPin = '';
      _firstPin = '';
      _isError = false;
      _errorMsg = '';
      _showPinEntry = true;
    });
  }

  void _startDisablePin() {
    setState(() {
      _flowMode = _PinFlowMode.verifyOld;
      _enteredPin = '';
      _firstPin = '';
      _isError = false;
      _errorMsg = '';
      _showPinEntry = true;
    });
  }

  void _onPinKey(String digit) {
    if (_enteredPin.length >= 4) return;
    final next = _enteredPin + digit;
    setState(() => _enteredPin = next);
    if (next.length == 4) {
      _handleComplete(next);
    }
  }

  void _onPinBackspace() {
    if (_enteredPin.isEmpty) return;
    setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
  }

  Future<void> _handleComplete(String pin) async {
    switch (_flowMode) {
      case _PinFlowMode.verifyOld:
        final ok = await PinService.instance.verifyPin(pin);
        if (!mounted) return;
        if (ok) {
          // Check what we were trying to do
          if (_firstPin.isEmpty) {
            // verifyOld for disable: clear pin
            if (!_showPinEntry) return;
            // Determine if we're disabling or changing
            // We use a flag via _firstPin == 'DISABLE'
            await PinService.instance.clearPin();
            setState(() {
              _lockEnabled = false;
              _biometricEnabled = false;
              _hasPin = false;
              _showPinEntry = false;
            });
            _showSnack('PIN removed. App lock is off.');
          } else {
            // Was changing PIN
            setState(() {
              _flowMode = _PinFlowMode.setNew;
              _enteredPin = '';
              _isError = false;
            });
          }
        } else {
          _shakeError('Incorrect PIN. Try again.');
        }
        break;

      case _PinFlowMode.setNew:
        setState(() {
          _firstPin = pin;
          _flowMode = _PinFlowMode.confirmNew;
          _enteredPin = '';
          _isError = false;
        });
        break;

      case _PinFlowMode.confirmNew:
        if (pin == _firstPin) {
          await PinService.instance.setPin(pin);
          if (!mounted) return;
          setState(() {
            _lockEnabled = true;
            _hasPin = true;
            _showPinEntry = false;
          });
          _showSnack('PIN set. App lock is active.');
        } else {
          _shakeError('PINs do not match. Try again.');
          setState(() {
            _flowMode = _PinFlowMode.setNew;
            _firstPin = '';
            _enteredPin = '';
          });
        }
        break;
    }
  }

  void _shakeError(String msg) {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0);
    setState(() {
      _enteredPin = '';
      _isError = true;
      _errorMsg = msg;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isError = false);
    });
  }

  void _showSnack(String msg) {
    AppToast.info(context, message: msg);
  }

  String get _pinFlowTitle {
    switch (_flowMode) {
      case _PinFlowMode.setNew:
        return 'Set a new PIN';
      case _PinFlowMode.confirmNew:
        return 'Confirm your PIN';
      case _PinFlowMode.verifyOld:
        return 'Enter current PIN';
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  Widget _buildCardBase(BuildContext context, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 20),
      child: Text(
        label,
        style: TextStyle(
          color: context.themeTextSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool showDivider = false,
    bool disabled = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: disabled ? null : onTap,
          splashColor: context.themeBorder.withValues(alpha: 0.2),
          child: Opacity(
            opacity: disabled ? 0.4 : 1.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: context.themeTextPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: context.themeTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing ??
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: context.themeTextSecondary.withValues(alpha: 0.5),
                        size: 14,
                      ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: context.themeBorder,
          ),
      ],
    );
  }

  Widget _toggleTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool disabled = false,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Opacity(
            opacity: disabled ? 0.4 : 1.0,
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: context.themeTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.themeTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                AppSwitch(
                  value: value,
                  onChanged: disabled ? (_) {} : onChanged,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: context.themeBorder,
          ),
      ],
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.themeOverlayStyle,
      child: Scaffold(
        backgroundColor: context.themeBackground,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                      child: Row(
                        children: [
                          const AppBackButton(),
                          Text(
                            'Privacy & Security',
                            style: TextStyle(
                              color: context.themeTextPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── App Lock Section ──────────────────────────────────
                    _sectionLabel(context, 'App Lock'),
                    _buildCardBase(context, [
                      _toggleTile(
                        context,
                        icon: Icons.lock_rounded,
                        iconColor: AppColors.gold,
                        label: 'Enable App Lock',
                        subtitle: _lockEnabled
                            ? 'App locks when minimized'
                            : 'Unlock with PIN on open',
                        value: _lockEnabled,
                        showDivider: true,
                        onChanged: (v) async {
                          if (v) {
                            // Enabling — set a PIN first
                            _startSetPin();
                          } else {
                            // Disabling — verify current PIN first
                            if (_hasPin) {
                              _startDisablePin();
                            } else {
                              await PinService.instance.setLockEnabled(false);
                              setState(() => _lockEnabled = false);
                            }
                          }
                        },
                      ),
                      _tile(
                        context,
                        icon: Icons.pin_outlined,
                        iconColor: AppColors.info,
                        label: _hasPin ? 'Change PIN' : 'Set PIN',
                        subtitle: _hasPin
                            ? 'Update your 4-digit PIN'
                            : 'Create a 4-digit lock PIN',
                        onTap: _startChangePin,
                        showDivider: false,
                      ),
                    ]),

                    // ── Biometrics Section ────────────────────────────────
                    _sectionLabel(context, 'Biometrics'),
                    _buildCardBase(context, [
                      _toggleTile(
                        context,
                        icon: Icons.fingerprint_rounded,
                        iconColor: AppColors.positive,
                        label: 'Fingerprint Unlock',
                        subtitle: !_canUseBiometrics
                            ? 'No biometric hardware detected'
                            : !_hasPin
                                ? 'Set a PIN first to enable'
                                : _biometricEnabled
                                    ? 'Use fingerprint to unlock'
                                    : 'Unlock with fingerprint',
                        value: _biometricEnabled,
                        disabled: !_canUseBiometrics || !_hasPin,
                        onChanged: (v) async {
                          await PinService.instance.setBiometricEnabled(v);
                          setState(() => _biometricEnabled = v);
                        },
                      ),
                    ]),

                    // ── Danger Zone ───────────────────────────────────────
                    if (_hasPin) ...[
                      _sectionLabel(context, 'Danger Zone'),
                      _buildCardBase(context, [
                        _tile(
                          context,
                          icon: Icons.no_encryption_rounded,
                          iconColor: AppColors.negative,
                          label: 'Remove PIN',
                          subtitle: 'Disables lock and removes your PIN',
                          onTap: () {
                            AppConfirmDialog.show(
                              context: context,
                              title: 'Remove PIN?',
                              message:
                                  'Your PIN will be deleted and app lock will be disabled.',
                              confirmText: 'Remove',
                              isDestructive: true,
                              onConfirm: () {
                                _startDisablePin();
                              },
                            );
                          },
                          trailing: const Icon(Icons.arrow_forward_ios_rounded,
                              color: AppColors.negative, size: 14),
                        ),
                      ]),
                    ],

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),

            // ── In-page PIN numpad overlay ────────────────────────────────
            if (_showPinEntry) _buildPinOverlay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPinOverlay(BuildContext context) {
    return Container(
      color: context.themeBackground,
      child: SafeArea(
        child: Column(
          children: [
            // Close / back
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showPinEntry = false),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.themeSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: context.themeTextPrimary, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),

            // Title
            Text(
              _pinFlowTitle,
              style: TextStyle(
                color: context.themeTextPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isError
                  ? _errorMsg
                  : _flowMode == _PinFlowMode.confirmNew
                      ? 'Re-enter the same PIN to confirm'
                      : '4 digits, numbers only',
              style: TextStyle(
                color: _isError
                    ? AppColors.negative
                    : context.themeTextSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),

            // Dot indicators
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (context, child) {
                final offset = _shakeController.isAnimating
                    ? _shakeAnim.value *
                        ((_shakeController.value * 6).round().isEven ? 1 : -1)
                    : 0.0;
                return Transform.translate(
                    offset: Offset(offset, 0), child: child);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isError
                          ? AppColors.negative
                          : filled
                              ? AppColors.brandGreen
                              : context.themeBorder,
                    ),
                  );
                }),
              ),
            ),

            const Spacer(flex: 2),

            // Numpad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  _numRow(context, ['1', '2', '3']),
                  const SizedBox(height: 14),
                  _numRow(context, ['4', '5', '6']),
                  const SizedBox(height: 14),
                  _numRow(context, ['7', '8', '9']),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 72, height: 72),
                      _numKey(
                        context,
                        child: Text('0',
                            style: TextStyle(
                                color: context.themeTextPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w600)),
                        onTap: () => _onPinKey('0'),
                      ),
                      _numKey(
                        context,
                        child: Icon(Icons.backspace_outlined,
                            color: context.themeTextPrimary, size: 22),
                        onTap: _onPinBackspace,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _numRow(BuildContext context, List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map((d) => _numKey(
                context,
                child: Text(d,
                    style: TextStyle(
                        color: context.themeTextPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w600)),
                onTap: () => _onPinKey(d),
              ))
          .toList(),
    );
  }

  Widget _numKey(BuildContext context, {required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: context.themeSurface,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
