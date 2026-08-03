import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/pin_service.dart';
import '../../theme/app_theme.dart';

class AppLockScreen extends StatefulWidget {
  /// Called when the user successfully authenticates.
  final VoidCallback onUnlocked;

  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  String _entered = '';
  bool _isError = false;
  bool _canUseBiometric = false;
  bool _biometricEnabled = false;
  bool _biometricTriggered = false; // guard: do not re-trigger while dialog open

  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Wait for first frame before launching system biometric dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initBiometrics();
    });
  }

  Future<void> _initBiometrics() async {
    final canUse = await PinService.instance.canUseBiometrics();
    final enabled = await PinService.instance.isBiometricEnabled();
    if (!mounted) return;
    setState(() {
      _canUseBiometric = canUse;
      _biometricEnabled = enabled;
    });
    // Immediately prompt fingerprint if enabled — show before PIN keypad
    if (canUse && enabled) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    if (_biometricTriggered) return;
    if (!mounted) return;
    setState(() => _biometricTriggered = true);
    final ok = await PinService.instance.authenticateBiometric();
    if (!mounted) return;
    setState(() => _biometricTriggered = false);
    if (ok) {
      widget.onUnlocked();
    }
    // If failed/cancelled — fall through to PIN keypad silently
  }

  void _onKey(String digit) {
    if (_entered.length >= 4) return;
    final next = _entered + digit;
    setState(() => _entered = next);
    if (next.length == 4) {
      _verify(next);
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _verify(String pin) async {
    final ok = await PinService.instance.verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.lightImpact();
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);
      setState(() {
        _entered = '';
        _isError = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isError = false);
      });
    }
  }

  void _forgotPin() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reset PIN?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will remove your PIN and unlock the app. You can set a new PIN in Settings.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () async {
              await PinService.instance.clearPin();
              if (mounted) {
                Navigator.pop(context);
                widget.onUnlocked();
              }
            },
            child: const Text('Reset', style: TextStyle(color: AppColors.negative, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showBiometricButton = _canUseBiometric && _biometricEnabled;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // App logo / title
              Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.lock_rounded, color: AppColors.gold, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Shibre',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isError
                        ? 'Incorrect PIN. Try again.'
                        : showBiometricButton
                            ? 'Use fingerprint or enter PIN'
                            : 'Enter your PIN to continue',
                    style: TextStyle(
                      color: _isError ? AppColors.negative : Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // PIN dot indicators with shake animation
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (context, child) {
                  final offset = _shakeController.isAnimating
                      ? _shakeAnim.value * ((_shakeController.value * 6).round().isEven ? 1 : -1)
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _entered.length;
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
                                ? AppColors.gold
                                : AppColors.surfaceElevated,
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
                    _buildNumRow(['1', '2', '3']),
                    const SizedBox(height: 16),
                    _buildNumRow(['4', '5', '6']),
                    const SizedBox(height: 16),
                    _buildNumRow(['7', '8', '9']),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Biometric button — tappable to re-prompt fingerprint
                        showBiometricButton
                            ? _buildNumKey(
                                child: Icon(
                                  Icons.fingerprint_rounded,
                                  color: _biometricTriggered
                                      ? AppColors.gold
                                      : Colors.white,
                                  size: 30,
                                ),
                                onTap: _tryBiometric,
                              )
                            : const SizedBox(width: 72, height: 72),
                        _buildNumKey(
                          child: const Text('0',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600)),
                          onTap: () => _onKey('0'),
                        ),
                        _buildNumKey(
                          child: const Icon(Icons.backspace_outlined,
                              color: Colors.white, size: 22),
                          onTap: _onBackspace,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Forgot PIN
              GestureDetector(
                onTap: _forgotPin,
                child: Text(
                  'Forgot PIN?',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map((d) => _buildNumKey(
                child: Text(d,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600)),
                onTap: () => _onKey(d),
              ))
          .toList(),
    );
  }

  Widget _buildNumKey({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
