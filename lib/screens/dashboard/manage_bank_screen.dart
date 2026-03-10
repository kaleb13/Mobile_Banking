import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/sender.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';

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
    final account = _accountController.text.trim();
    final pin = _pinController.text.trim();

    if (account.isEmpty || pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    _saveSender(account, pin);
  }

  Future<void> _saveSender(String account, String pin) async {
    setState(() => _isSaving = true);
    final updated = AppSender(
      id: widget.sender.id,
      senderName: widget.sender.senderName,
      depositKeywords: widget.sender.depositKeywords,
      expenseKeywords: widget.sender.expenseKeywords,
      accountNumber: account,
      pin: pin,
    );

    await Provider.of<FinanceProvider>(context, listen: false)
        .updateSender(updated);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Information updated successfully')),
      );
      Navigator.pop(context);
    }
  }

  void _handleDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F25),
        title:
            const Text('Unlink Account', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to unlink your ${widget.sender.senderName} account? This will remove your saved credentials.',
          style: const TextStyle(color: AppColors.labelGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.labelGray)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete();
            },
            child: const Text('Unlink',
                style: TextStyle(color: AppColors.alertRed)),
          ),
        ],
      ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account unlinked')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F25),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Manage ${widget.sender.senderName}',
            style: const TextStyle(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
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
                  TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
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
              child: TextButton.icon(
                onPressed: _handleDelete,
                icon: const Icon(Icons.link_off_rounded,
                    color: AppColors.alertRed, size: 18),
                label: const Text("Unlink This Account",
                    style: TextStyle(color: AppColors.alertRed)),
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
            style: const TextStyle(color: AppColors.labelGray, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A34),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && !_isPinVisible,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.labelGray, size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                          _isPinVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.labelGray,
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
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF0B90B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black))
            : const Text("Save Changes",
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
      ),
    );
  }
}
