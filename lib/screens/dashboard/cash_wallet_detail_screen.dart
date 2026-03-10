import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../models/cash_transaction.dart';
import '../../models/expense_definition.dart';
import '../../models/reason.dart';
import '../../theme/app_theme.dart';
import '../settings/expense_definitions_screen.dart';
import 'transaction_detail_screen.dart';
import 'reason_selection_sheet.dart';

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
                            TextStyle(color: AppColors.labelGray, fontSize: 14),
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
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _actionButton(
                            context,
                            icon: Icons.add,
                            label: 'Add Cash',
                            onTap: () {
                              _showAddCashModal(context, provider);
                            },
                          ),
                          const SizedBox(width: 32),
                          _actionButton(
                            context,
                            icon: Icons.money_off,
                            label: 'Deduct',
                            onTap: () {
                              _showUnifiedDeductModal(context, provider);
                            },
                          ),
                          const SizedBox(width: 32),
                          _actionButton(
                            context,
                            icon: Icons.settings_rounded,
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
          'appTransaction': tx,
          'date': tx.date,
          'title': 'Bank SMS Injection',
          'subtitle': tx.name, // Bank name
          'amount': tx.amount,
          'isPositive':
              true, // Cash withdrawn from bank -> added to cash wallet
          'isCashTx': false,
        });
      }
    }

    for (var ctx in provider.cashTransactions) {
      String sub = ctx.description ?? '';
      if (ctx.reasonName != null && ctx.reasonName!.isNotEmpty) {
        sub = ctx.reasonName!;
        if (ctx.description != null && ctx.description!.isNotEmpty) {
          sub += ' (${ctx.description})';
        }
      }

      allTxs.add({
        'id': ctx.id,
        'date': ctx.date,
        'title': ctx.type == 'addition'
            ? 'Manual Addition'
            : (ctx.reasonName ?? 'Cash Expense'),
        'subtitle': sub,
        'amount': ctx.amount,
        'isPositive': ctx.type == 'addition',
        'isCashTx': true,
      });
    }

    if (allTxs.isEmpty) {
      return const Center(
          child: Text('No cash transactions yet.',
              style: TextStyle(color: AppColors.labelGray)));
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
            onTap: tx['isCashTx'] == false && tx['appTransaction'] != null
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransactionDetailScreen(
                            transaction: tx['appTransaction']),
                      ),
                    );
                  }
                : null,
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
                                      color: AppColors.labelGray,
                                      fontSize: 12))),
                        const SizedBox(height: 4),
                        Text(DateFormat('MMM d, yyyy · hm a').format(date),
                            style: const TextStyle(
                                color: AppColors.labelGray, fontSize: 10)),
                      ])),
                  Text(
                    provider.isBalanceVisible
                        ? '${isPositive ? '+' : '-'}${fmtShort.format(tx['amount'])} ETB'
                        : '****',
                    style: TextStyle(
                        color: isPositive ? AppColors.mintGreen : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ])),
          );
        });
  }

  void _showUnifiedDeductModal(BuildContext context, FinanceProvider provider) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    AppReason? selectedReason;
    ExpenseDefinition? selectedTemplate;
    bool isRecurring = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1F24),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Deduct Cash Expense',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                        icon:
                            const Icon(Icons.close, color: AppColors.labelGray),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Template Quick Selector
                  if (provider.expenseDefinitions.isNotEmpty) ...[
                    const Text('Saved Templates',
                        style: TextStyle(
                            color: AppColors.labelGray, fontSize: 13)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: provider.expenseDefinitions.length,
                        itemBuilder: (context, index) {
                          final def = provider.expenseDefinitions[index];
                          final isSelected = selectedTemplate?.id == def.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Text(def.name),
                              selected: isSelected,
                              onSelected: (val) {
                                setModalState(() {
                                  if (val) {
                                    selectedTemplate = def;
                                    amountController.text =
                                        def.defaultAmount.toStringAsFixed(0);
                                    if (def.reasonId != null) {
                                      selectedReason =
                                          provider.reasons.firstWhere(
                                        (r) => r.id == def.reasonId,
                                        orElse: () => provider.reasons.first,
                                      );
                                    }
                                  } else {
                                    selectedTemplate = null;
                                  }
                                });
                              },
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.05),
                              selectedColor:
                                  AppColors.primaryBlue.withValues(alpha: 0.2),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppColors.primaryBlue
                                    : Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Amount Field
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.1)),
                      suffixText: 'ETB',
                      suffixStyle: const TextStyle(
                          color: AppColors.labelGray, fontSize: 16),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1))),
                      focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: AppColors.primaryBlue, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Reason Selector
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (_) => ReasonSelectionSheet(
                                initialReason: selectedReason,
                                onReasonSelected: (r) {
                                  setModalState(() => selectedReason = r);
                                },
                              ),
                            );
                          },
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.category_rounded,
                                    color: AppColors.primaryBlue, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    selectedReason?.name ?? 'Select Reason',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_right,
                                    color: AppColors.labelGray, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Quick Add Reason Button
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color:
                                  AppColors.primaryBlue.withValues(alpha: 0.3)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add,
                              color: AppColors.primaryBlue, size: 24),
                          onPressed: () {
                            _showQuickAddReasonDialog(context, (newReason) {
                              setModalState(() {
                                selectedReason = newReason;
                              });
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Note Field
                  TextField(
                    controller: noteController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Short Note (Optional)',
                      labelStyle: const TextStyle(color: AppColors.labelGray),
                      prefixIcon:
                          const Icon(Icons.notes, color: AppColors.labelGray),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recurring Toggle
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Save as Template',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text('Easily reuse this amount and reason later',
                                style: TextStyle(
                                    color: AppColors.labelGray, fontSize: 11)),
                          ],
                        ),
                      ),
                      AppSwitch(
                        value: isRecurring,
                        onChanged: (val) {
                          setModalState(() => isRecurring = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final amtStr = amountController.text.trim();
                        final amt = double.tryParse(amtStr);
                        if (amt == null || amt <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invalid amount')));
                          return;
                        }

                        // Create the transaction
                        final tx = CashTransaction(
                          type: 'expense',
                          amount: amt,
                          date: DateTime.now(),
                          description: noteController.text.trim(),
                          reasonId: selectedReason?.id,
                          reasonName: selectedReason?.name,
                          expenseDefinitionId: selectedTemplate?.id,
                        );

                        await provider.addCashTransaction(tx);

                        // If "Save as Template" is on, and no template selected, create it
                        if (isRecurring && selectedTemplate == null) {
                          final newDef = ExpenseDefinition(
                            name: selectedReason?.name ??
                                (noteController.text.trim().isNotEmpty
                                    ? noteController.text.trim()
                                    : 'New Template'),
                            defaultAmount: amt,
                            isRecurring:
                                false, // Start as one-time template unless user edits it in Manage
                            reasonId: selectedReason?.id,
                          );
                          await provider.addExpenseDefinition(newDef);
                        }

                        Navigator.pop(context);
                      },
                      child: const Text('Deduct Cash',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _showAddCashModal(BuildContext context, FinanceProvider provider) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1F24),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add Cash',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.labelGray),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.1)),
                  suffixText: 'ETB',
                  suffixStyle:
                      const TextStyle(color: AppColors.labelGray, fontSize: 16),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1))),
                  focusedBorder: const UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: AppColors.primaryBlue, width: 2)),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Source / Note (Optional)',
                  labelStyle: const TextStyle(color: AppColors.labelGray),
                  prefixIcon:
                      const Icon(Icons.notes, color: AppColors.labelGray),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mintGreen,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    final amtStr = amountController.text.trim();
                    final amt = double.tryParse(amtStr);
                    if (amt != null && amt > 0) {
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
                  child: const Text('Add to Balance',
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

  void _showOverrideAmountDialog(BuildContext context, FinanceProvider provider,
      int id, double oldAmount) {
    final controller =
        TextEditingController(text: oldAmount.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Edit Amount', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'New Amount',
            labelStyle: TextStyle(color: AppColors.labelGray),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final amt = double.tryParse(controller.text);
              if (amt != null) {
                provider.updateCashTransactionAmount(id, amt);
                Navigator.pop(c);
              }
            },
            child: const Text('Update',
                style: TextStyle(color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: AppColors.labelGray,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showQuickAddReasonDialog(
      BuildContext context, Function(AppReason) onCreated) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Reason', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g., Snacks, Taxi...',
            hintStyle: const TextStyle(color: AppColors.labelGray),
            enabledBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primaryBlue)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.labelGray)),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final provider =
                    Provider.of<FinanceProvider>(context, listen: false);
                final newReason = await provider.addReason(name);
                onCreated(newReason);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add',
                style: TextStyle(color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }
}
