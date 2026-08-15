import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/sender.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_toast.dart';

class ManageBankScreen extends StatefulWidget {
  final AppSender sender;

  const ManageBankScreen({super.key, required this.sender});

  @override
  State<ManageBankScreen> createState() => _ManageBankScreenState();
}

class _ManageBankScreenState extends State<ManageBankScreen> {
  late TextEditingController _accountController;
  late TextEditingController _pinController;
  bool _isPinVisible = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _accountController =
        TextEditingController(text: widget.sender.accountNumber);
    _pinController = TextEditingController(text: widget.sender.pin);
  }

  @override
  void dispose() {
    _accountController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final provider = Provider.of<FinanceProvider>(context, listen: false);

    final updated = AppSender(
      id: widget.sender.id,
      senderName: widget.sender.senderName,
      depositKeywords: widget.sender.depositKeywords,
      expenseKeywords: widget.sender.expenseKeywords,
      accountNumber: _accountController.text.trim(),
      pin: _pinController.text.trim(),
    );

    await provider.updateSender(updated);
    setState(() => _isSaving = false);

    if (mounted) {
      AppToast.success(
        context,
        message: 'Credentials Updated',
        subtitle: '${widget.sender.senderName} information saved successfully',
      );
      Navigator.pop(context);
    }
  }

  void _handleDelete() {
    AppConfirmDialog.show(
      context: context,
      title: 'Unlink Account',
      icon: Icons.link_off_rounded,
      iconColor: AppColors.negative,
      message:
          'Are you sure you want to unlink your ${widget.sender.senderName} account? This will remove your saved credentials.',
      confirmText: 'Unlink',
      cancelText: 'Cancel',
      isDestructive: true,
      onConfirm: () async {
        await _performDelete();
      },
    );
  }

  Future<void> _performDelete() async {
    final updated = AppSender(
      id: widget.sender.id,
      senderName: widget.sender.senderName,
      depositKeywords: widget.sender.depositKeywords,
      expenseKeywords: widget.sender.expenseKeywords,
      accountNumber: null,
      pin: null,
    );

    await Provider.of<FinanceProvider>(context, listen: false)
        .updateSender(updated);

    if (mounted) {
      AppToast.warning(
        context,
        message: 'Account Unlinked',
        subtitle: '${widget.sender.senderName} credentials removed',
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Manage ${widget.sender.senderName}',
            style: const TextStyle(fontSize: 18)),
        leading: const AppBackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Account Credentials",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "View or update your linked account details.",
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
            ),
            const SizedBox(height: 32),
            _buildField("Account Number", _accountController,
                Icons.account_balance_rounded),
            const SizedBox(height: 16),
            _buildField("PIN", _pinController, Icons.lock_rounded,
                isPassword: true),
            const SizedBox(height: 40),
            _buildActionButtons(),
            const SizedBox(height: 24),
            Center(
              child: AppButton.destructive(
                onPressed: _handleDelete,
                icon: Icons.link_off_rounded,
                text: "Unlink This Account",
                fullWidth: false,
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
      String label, TextEditingController controller, IconData icon,
      {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textSoft, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && !_isPinVisible,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.textSoft, size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                          _isPinVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.textSoft,
                          size: 20),
                      onPressed: () =>
                          setState(() => _isPinVisible = !_isPinVisible),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return AppButton.primary(
      text: "Save Changes",
      isLoading: _isSaving,
      height: 52,
      onPressed: _isSaving ? null : _handleSave,
    );
  }
}
