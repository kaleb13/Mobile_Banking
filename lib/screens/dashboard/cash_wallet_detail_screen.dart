import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../models/cash_transaction.dart';
import '../../models/expense_definition.dart';
import '../../theme/app_theme.dart';
import '../settings/expense_definitions_screen.dart';

class CashWalletDetailScreen extends StatefulWidget {
  const CashWalletDetailScreen({super.key});

  @override
  State<CashWalletDetailScreen> createState() => _CashWalletDetailScreenState();
}

class _CashWalletDetailScreenState extends State<CashWalletDetailScreen> {
  @override
  Widget build(BuildContext context) {
    // We'll scaffold this out based on SenderDetailScreen's style.
    final provider = Provider.of<FinanceProvider>(context);
    final fmt = NumberFormat('#,##0.00');

    // Combine SMS cash transactions and manual cash transactions into one list
    // Or we just show cashTransactions, but SMS ones affect the balance too.
    // For now, let's just make it a clean screen showing the balance.

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
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(
                      top: 16, left: 16, right: 16, bottom: 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: SvgPicture.asset(
                              'assets/images/BackForNav.svg',
                              colorFilter: const ColorFilter.mode(
                                  Colors.white, BlendMode.srcIn),
                              width: 20,
                              height: 20,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Text(
                            'Cash Wallet',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 48), // Spacer
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Available Cash',
                        style:
                            TextStyle(color: Color(0xFF6B8FA6), fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${fmt.format(provider.cashBalance)} ETB',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _actionButton(
                            context,
                            icon: Icons.add,
                            label: 'Add Cash',
                            onTap: () {
                              _showAddCashModal(context, provider);
                            },
                          ),
                          _actionButton(
                            context,
                            icon: Icons.receipt_long,
                            label: 'Deduct Expense',
                            onTap: () {
                              _showDeductExpenseModal(context, provider);
                            },
                          ),
                          _actionButton(
                            context,
                            icon: Icons.settings,
                            label: 'Templates',
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ExpenseDefinitionsScreen()));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Body (History)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('History',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildTransactionList(context, provider),
                      ),
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

  Widget _buildTransactionList(BuildContext context, FinanceProvider provider) {
    // Create a unified list of dynamic transaction maps
    final List<Map<String, dynamic>> allTxs = [];
    final fmtShort = NumberFormat('#,##0');

    for (var tx in provider.transactions) {
      final isCash = (tx.reason?.toLowerCase() == 'cash' ||
          tx.customReasonText?.toLowerCase() == 'cash' ||
          tx.resolvedReason?.toLowerCase() == 'cash');
      if (isCash) {
        allTxs.add({
          'date': tx.date,
          'title': 'Bank SMS Injection',
          'subtitle': tx.name, // Bank name
          'amount': tx.amount,
          'isPositive':
              true, // Cash withdrawn from bank -> added to cash wallet
        });
      }
    }

    for (var ctx in provider.cashTransactions) {
      allTxs.add({
        'id': ctx.id,
        'date': ctx.date,
        'title':
            ctx.type == 'addition' ? 'Manual Addition' : 'Expense Deducted',
        'subtitle': ctx.description ?? '',
        'amount': ctx.amount,
        'isPositive': ctx.type == 'addition',
        'isCashTx': true,
      });
    }

    if (allTxs.isEmpty) {
      return const Center(
          child: Text('No cash transactions yet.',
              style: TextStyle(color: AppColors.textGray)));
    }

    allTxs.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: allTxs.length,
        itemBuilder: (context, index) {
          final tx = allTxs[index];
          final date = tx['date'] as DateTime;
          final isPositive = tx['isPositive'] as bool;

          return InkWell(
            onLongPress: tx['isCashTx'] == true
                ? () {
                    _showOverrideAmountDialog(
                        context, provider, tx['id'], tx['amount']);
                  }
                : null,
            borderRadius: BorderRadius.circular(16),
            child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08))),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isPositive
                          ? AppColors.mintGreen.withValues(alpha: 0.1)
                          : AppColors.alertRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                      color:
                          isPositive ? AppColors.mintGreen : AppColors.alertRed,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(tx['title'] as String,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        if ((tx['subtitle'] as String).isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(tx['subtitle'] as String,
                                  style: const TextStyle(
                                      color: AppColors.textGray,
                                      fontSize: 12))),
                        const SizedBox(height: 4),
                        Text(DateFormat('MMM d, yyyy · hm a').format(date),
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 10)),
                      ])),
                  Text(
                    '${isPositive ? '+' : '-'}${fmtShort.format(tx['amount'])} ETB',
                    style: TextStyle(
                        color: isPositive ? AppColors.mintGreen : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ])),
          );
        });
  }

  void _showAddCashModal(BuildContext context, FinanceProvider provider) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1417),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Cash',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Amount (ETB)',
                  labelStyle: const TextStyle(color: AppColors.textGray),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1))),
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primaryBlue)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Note (Optional)',
                  labelStyle: const TextStyle(color: AppColors.textGray),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1))),
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primaryBlue)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mintGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final amountstr = amountController.text.trim();
                    if (amountstr.isNotEmpty &&
                        double.tryParse(amountstr) != null) {
                      final amt = double.parse(amountstr);
                      provider.addCashTransaction(CashTransaction(
                        type: 'addition',
                        amount: amt,
                        date: DateTime.now(),
                        description: noteController.text.trim().isEmpty
                            ? 'Manual Add'
                            : noteController.text.trim(),
                      ));
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add Cash',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showDeductExpenseModal(BuildContext context, FinanceProvider provider) {
    if (provider.expenseDefinitions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No Expense Templates defined! Create one first.')));
      return;
    }

    ExpenseDefinition? selectedDef;
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1417),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Deduct Expense',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<ExpenseDefinition>(
                  decoration: InputDecoration(
                    labelText: 'Select Template',
                    labelStyle: const TextStyle(color: AppColors.textGray),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1))),
                    focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primaryBlue)),
                  ),
                  dropdownColor: const Color(0xFF1E272C),
                  initialValue: selectedDef,
                  items: provider.expenseDefinitions
                      .map((def) => DropdownMenuItem(
                            value: def,
                            child: Text(def.name,
                                style: const TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedDef = val;
                      if (val != null) {
                        amountController.text =
                            val.defaultAmount.toStringAsFixed(2);
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Amount (ETB)',
                    labelStyle: const TextStyle(color: AppColors.textGray),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1))),
                    focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primaryBlue)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.alertRed,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final amountstr = amountController.text.trim();
                      if (selectedDef != null &&
                          amountstr.isNotEmpty &&
                          double.tryParse(amountstr) != null) {
                        final amt = double.parse(amountstr);
                        provider.addCashTransaction(CashTransaction(
                          type: 'expense',
                          amount: amt,
                          date: DateTime.now(),
                          description: 'Used template: ${selectedDef!.name}',
                          expenseDefinitionId: selectedDef!.id,
                        ));
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Deduct Expense',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _actionButton(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: AppColors.textWhite, fontSize: 12)),
        ],
      ),
    );
  }

  void _showOverrideAmountDialog(BuildContext context, FinanceProvider provider,
      int id, double currentAmount) {
    final amountController =
        TextEditingController(text: currentAmount.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Override Amount',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the correct amount for this transaction:',
                style: TextStyle(color: AppColors.textGray, fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textGray)),
          ),
          TextButton(
            onPressed: () {
              final newAmount = double.tryParse(amountController.text.trim());
              if (newAmount != null) {
                provider.updateCashTransactionAmount(id, newAmount);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Amount updated successfully')),
                );
              }
            },
            child: const Text('Update',
                style: TextStyle(
                    color: AppColors.mintGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
