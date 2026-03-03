import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/expense_definition.dart';
import '../../providers/finance_provider.dart';
import '../shell/custom_bottom_nav_bar.dart';

class AddEditExpenseDefinitionScreen extends StatefulWidget {
  final ExpenseDefinition? expenseDefinition;

  const AddEditExpenseDefinitionScreen({super.key, this.expenseDefinition});

  @override
  State<AddEditExpenseDefinitionScreen> createState() =>
      _AddEditExpenseDefinitionScreenState();
}

class _AddEditExpenseDefinitionScreenState
    extends State<AddEditExpenseDefinitionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _intervalDaysController;
  late TextEditingController _specificDayController;

  bool _isRecurring = false;
  String _recurringType = 'daily'; // 'daily', 'interval', 'specific_day'

  @override
  void initState() {
    super.initState();
    final def = widget.expenseDefinition;
    _nameController = TextEditingController(text: def?.name ?? '');
    _amountController = TextEditingController(
        text: def != null ? def.defaultAmount.toStringAsFixed(2) : '');
    _intervalDaysController =
        TextEditingController(text: def?.intervalDays?.toString() ?? '');
    _specificDayController =
        TextEditingController(text: def?.specificDay?.toString() ?? '');

    _isRecurring = def?.isRecurring ?? false;
    _recurringType = def?.recurringType ?? 'daily';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _intervalDaysController.dispose();
    _specificDayController.dispose();
    super.dispose();
  }

  void _saveDefinition() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    int? intervalDays;
    int? specificDay;

    if (_isRecurring) {
      if (_recurringType == 'daily') {
        int times = int.tryParse(_intervalDaysController.text.trim()) ?? 1;
        if (times < 1 || times > 10) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Please enter a valid number of times per day (1-10).')));
          return;
        }
        intervalDays = times;
      } else if (_recurringType == 'interval') {
        intervalDays = int.tryParse(_intervalDaysController.text.trim());
        if (intervalDays == null || intervalDays <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Please enter a valid interval in days.')));
          return;
        }
      } else if (_recurringType == 'specific_day') {
        specificDay = int.tryParse(_specificDayController.text.trim());
        if (specificDay == null || specificDay < 1 || specificDay > 31) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Please enter a valid day between 1 and 31.')));
          return;
        }
      }
    }

    final newDef = ExpenseDefinition(
      id: widget.expenseDefinition?.id,
      name: name,
      defaultAmount: amount,
      isRecurring: _isRecurring,
      recurringType: _isRecurring ? _recurringType : null,
      intervalDays: _isRecurring &&
              (_recurringType == 'interval' || _recurringType == 'daily')
          ? intervalDays
          : null,
      specificDay:
          _isRecurring && _recurringType == 'specific_day' ? specificDay : null,
      lastAppliedDate: widget.expenseDefinition?.lastAppliedDate,
    );

    final provider = Provider.of<FinanceProvider>(context, listen: false);
    if (widget.expenseDefinition == null) {
      provider.addExpenseDefinition(newDef);
    } else {
      provider.updateExpenseDefinition(newDef);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F25),
      extendBody: true,
      bottomNavigationBar: DynamicNavBarWrapper(
        currentIndex: 4,
        onTap: (_) {},
        isDynamic: true,
        dynamicActionLabel: 'Save Expense Definition',
        dynamicActionIcon: Icons.check, // Or any relevant save icon
        onDynamicAdd: _saveDefinition,
        onDynamicBack: () => Navigator.pop(context),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading:
            false, // Ensures a back button isn't auto-generated here
        title: Text(
          widget.expenseDefinition == null
              ? 'New Expense Definition'
              : 'Edit Expense Definition',
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Expense Details',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nameController,
                label: 'Expense Name (e.g., Lunch, Coffee)',
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _amountController,
                label: 'Default Amount (ETB)',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter amount';
                  if (double.tryParse(val.trim()) == null) {
                    return 'Invalid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              const Divider(color: Color(0x33FFFFFF)),
              const SizedBox(height: 16),
              Theme(
                data: ThemeData(
                  unselectedWidgetColor: const Color(0xFF9CA3AF),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Recurring Expense',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                  subtitle: const Text(
                      'Automatically deduct this expense on a schedule',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                  value: _isRecurring,
                  activeThumbColor: const Color(0xFFF0B90B), // primaryBlue
                  onChanged: (val) {
                    setState(() {
                      _isRecurring = val;
                    });
                  },
                ),
              ),
              if (_isRecurring) ...[
                const SizedBox(height: 24),
                const Text('Schedule Type',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _recurringType,
                  dropdownColor: const Color(0xFF2A2A34),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1C1F24),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'daily', child: Text('Daily (Every day)')),
                    DropdownMenuItem(
                        value: 'interval',
                        child: Text('Custom Interval (Every X days)')),
                    DropdownMenuItem(
                        value: 'specific_day',
                        child: Text('Specific Day of Month')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _recurringType = val!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (_recurringType == 'interval')
                  _buildTextField(
                    controller: _intervalDaysController,
                    label: 'Interval (Days)',
                    hintText: 'e.g., 2 (for every other day)',
                    keyboardType: TextInputType.number,
                  ),
                if (_recurringType == 'daily')
                  _buildTextField(
                    controller: _intervalDaysController,
                    label: 'Times per Day',
                    hintText: 'e.g., 3 (for breakfast, lunch, dinner)',
                    keyboardType: TextInputType.number,
                  ),
                if (_recurringType == 'specific_day')
                  _buildTextField(
                    controller: _specificDayController,
                    label: 'Day of the Month (1-31)',
                    keyboardType: TextInputType.number,
                  ),
              ],
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFF1C1F24),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF0B90B), width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1),
        ),
      ),
      validator: validator,
    );
  }
}
