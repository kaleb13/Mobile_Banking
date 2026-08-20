import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../models/cash_transaction.dart';
import '../../models/expense_definition.dart';
import '../../models/reason.dart';
import '../../models/transaction.dart';
import '../../models/transaction_attachment.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_note_card.dart';
import '../../widgets/app_drawer.dart';
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
                AppColors.background,
                AppColors.bgMid,
              ],
            ),
          ),
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(
                      top: 16, left: 12, right: 16, bottom: 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const AppBackButton(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                'assets/images/Wallet Icon.svg',
                                width: 20,
                                height: 20,
                                fit: BoxFit.contain,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Cash Wallet',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 36), // Spacer to balance 36px back button
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Available Cash',
                        style:
                            TextStyle(color: AppColors.textSoft, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          '${fmt.format(provider.cashBalance)} ETB',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
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
        final isWithdrawal = tx.type == 'expense'; // Bank withdrawal = physical cash IN into wallet (+)
        allTxs.add({
          'appTransaction': tx,
          'date': tx.date,
          'title': isWithdrawal ? 'Bank Cash Withdrawal' : 'Bank Cash Deposit',
          'subtitle': tx.name, // Bank name
          'amount': tx.amount,
          'isPositive': isWithdrawal,
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
              style: TextStyle(color: AppColors.textSoft)));
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
                    _showTransactionActions(
                        context, provider, tx['id'], tx['amount'],
                        tx['title'] as String);
                  }
                : null,
            borderRadius: BorderRadius.circular(16),
            child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    ),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isPositive
                          ? AppColors.positive.withValues(alpha: 0.1)
                          : AppColors.negative.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                      color:
                          isPositive ? AppColors.positive : AppColors.negative,
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
                                      color: AppColors.textSoft,
                                      fontSize: 12))),
                        const SizedBox(height: 4),
                        Text(DateFormat('MMM d, yyyy · hm a').format(date),
                            style: const TextStyle(
                                color: AppColors.textSoft, fontSize: 10)),
                      ])),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      provider.isBalanceVisible
                          ? '${isPositive ? '+' : '-'}${fmtShort.format(tx['amount'])} ETB'
                          : '****',
                      style: TextStyle(
                          color: isPositive ? AppColors.positive : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                    ),
                  ),
                ])),
          );
        });
  }

  void _showUnifiedDeductModal(BuildContext context, FinanceProvider provider) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final pendingAttachments = <TransactionAttachment>[];
    AppReason? selectedReason;
    ExpenseDefinition? selectedTemplate;
    AppTransaction? selectedWithdrawal;
    bool isRecurring = false;
    final fmtShort = NumberFormat('#,##0.00');

    AppDrawer.show(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          final enteredAmt = double.tryParse(amountController.text.trim());
          String? limitError;
          if (enteredAmt != null && enteredAmt > 0) {
            if (selectedWithdrawal != null) {
              final rem = provider.getCashWithdrawalRemainingAmount(
                  selectedWithdrawal!.id!, selectedWithdrawal!.amount);
              if (enteredAmt > rem) {
                limitError = 'Exceeds remaining withdrawal balance of ${fmtShort.format(rem)} ETB';
              }
            } else if (provider.cashBalance > 0 && enteredAmt > provider.cashBalance) {
              limitError = 'Exceeds available cash balance of ${fmtShort.format(provider.cashBalance)} ETB';
            }
          }
          final bool isExceeded = limitError != null;
          final bool isValid = enteredAmt != null && enteredAmt > 0 && !isExceeded && selectedReason != null;
          final String buttonText = isExceeded
              ? 'Exceeds Available Balance'
              : (selectedReason == null
                  ? 'Select Reason to Record'
                  : (enteredAmt == null || enteredAmt <= 0
                      ? 'Enter Amount'
                      : 'Record Expense'));

          return AppDrawer(
            heightFactor: 0.88,
            headerCard: AppDrawerHeaderCard(
              icon: Icons.money_off_rounded,
              iconColor: AppColors.positive,
              title: 'Deduct Cash Expense',
              subtitle: 'Available: ${fmtShort.format(provider.cashBalance)} ETB',
            ),
            bottomAction: AppButton.primary(
              text: buttonText,
              height: 48,
              onPressed: !isValid
                  ? null
                  : () async {
                      final amtStr = amountController.text.trim();
                      final amt = double.tryParse(amtStr);
                      if (amt == null || amt <= 0 || selectedReason == null) return;

                      if (selectedWithdrawal != null) {
                        final rem = provider.getCashWithdrawalRemainingAmount(
                            selectedWithdrawal!.id!, selectedWithdrawal!.amount);
                        if (amt > rem) return;
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
                        linkedTransactionId: selectedWithdrawal?.id,
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
                          isRecurring: false,
                          reasonId: selectedReason?.id,
                        );
                        await provider.addExpenseDefinition(newDef);
                      }

                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
            ),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                // Template Quick Selector
                if (provider.expenseDefinitions.isNotEmpty) ...[
                  const Text('Saved Templates',
                      style: TextStyle(
                          color: AppColors.textSoft, fontSize: 13)),
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
                                AppColors.gold.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? AppColors.gold
                                  : Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Amount Field
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                      color: isExceeded ? AppColors.negative : Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  onChanged: (_) => setModalState(() {}),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.1)),
                    suffixText: provider.currentCurrency.shortLabel,
                    suffixStyle: TextStyle(
                        color: isExceeded ? AppColors.negative : AppColors.textSoft, fontSize: 16),
                    enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide.none),
                    focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide.none),
                  ),
                ),
                if (isExceeded) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: AppBadge.destructive(
                      text: limitError,
                      icon: Icons.error_outline_rounded,
                      size: AppBadgeSize.medium,
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Reason Selector
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          AppBottomSheet.show(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => ReasonSelectionSheet(
                              initialReason: selectedReason,
                              transactionType: 'expense',
                              isCashSpending: true,
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
                            color: selectedReason != null
                                ? AppColors.positive.withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.category_rounded,
                                  color: selectedReason != null
                                      ? AppColors.positive
                                      : AppColors.gold,
                                  size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedReason?.name ?? 'Select Reason (Required)',
                                  style: TextStyle(
                                      color: selectedReason != null
                                          ? Colors.white
                                          : AppColors.gold,
                                      fontSize: 14,
                                      fontWeight: selectedReason != null
                                          ? FontWeight.w600
                                          : FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_right,
                                  color: AppColors.textSoft, size: 18),
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
                        color: AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add,
                            color: AppColors.gold, size: 24),
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

                // Note & Receipt Card
                AppNoteCard(
                  controller: noteController,
                  title: 'NOTE & RECEIPT',
                  hintText: 'Short note (optional)...',
                  attachments: pendingAttachments,
                  isCollapsible: true,
                  initialExpanded: false,
                  accentColor: AppColors.gold,
                  onAttachMedia: (filePath, fileType, fileName) async {
                    setModalState(() {
                      pendingAttachments.add(TransactionAttachment(
                        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                        transactionId: selectedWithdrawal?.id ?? 'cash_expense',
                        filePath: filePath,
                        fileType: fileType,
                        fileName: fileName,
                        createdAt: DateTime.now().toIso8601String(),
                      ));
                    });
                  },
                  onDeleteAttachment: (att) {
                    setModalState(() {
                      pendingAttachments.removeWhere((a) => a.id == att.id);
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Bank Cash Withdrawal Linkage Selector
                if (provider.activeBankCashWithdrawals.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: PopupMenuButton<AppTransaction?>(
                      initialValue: selectedWithdrawal,
                      onSelected: (tx) {
                        setModalState(() {
                          selectedWithdrawal = tx;
                        });
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: AppColors.surface,
                      itemBuilder: (ctx) => [
                        const PopupMenuItem<AppTransaction?>(
                          value: null,
                          child: Text('General Cash Wallet (No specific withdrawal link)',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ),
                        ...provider.activeBankCashWithdrawals.map((w) {
                          final rem = provider.getCashWithdrawalRemainingAmount(w.id!, w.amount);
                          return PopupMenuItem<AppTransaction?>(
                            value: w,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${w.name} Withdrawal (${fmtShort.format(w.amount)} ETB)',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                Text('${fmtShort.format(rem)} ETB remaining · ${DateFormat('MMM d').format(w.date)}',
                                    style: const TextStyle(color: AppColors.positive, fontSize: 11)),
                              ],
                            ),
                          );
                        }),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.link_rounded, color: AppColors.positive, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedWithdrawal != null
                                        ? '${selectedWithdrawal!.name} (${fmtShort.format(selectedWithdrawal!.amount)} ETB)'
                                        : 'Source Bank Withdrawal (Optional)',
                                    style: TextStyle(
                                      color: selectedWithdrawal != null ? Colors.white : AppColors.textSoft,
                                      fontSize: 13,
                                      fontWeight: selectedWithdrawal != null ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  if (selectedWithdrawal != null)
                                    Text(
                                      '${fmtShort.format(provider.getCashWithdrawalRemainingAmount(selectedWithdrawal!.id!, selectedWithdrawal!.amount))} ETB remaining',
                                      style: const TextStyle(color: AppColors.positive, fontSize: 10),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: AppColors.textSoft),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

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
                                  color: AppColors.textSoft, fontSize: 11)),
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
              ],
            ),
          );
        });
      },
    );
  }

  void _showAddCashModal(BuildContext context, FinanceProvider provider) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    AppDrawer.show(
      context: context,
      builder: (context) {
        return AppDrawer(
          heightFactor: null,
          isBodyScrollable: false,
          headerCard: AppDrawerHeaderCard(
            icon: Icons.add_circle_outline_rounded,
            iconColor: AppColors.positive,
            title: 'Add Cash',
            subtitle: 'Manually add funds to your cash wallet',
          ),
          bottomAction: AppButton.primary(
            text: 'Add to Balance',
            height: 48,
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
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                      const TextStyle(color: AppColors.textSoft, fontSize: 16),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide.none),
                  focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Source / Note (Optional)',
                  labelStyle: const TextStyle(color: AppColors.textSoft),
                  prefixIcon:
                      const Icon(Icons.notes, color: AppColors.textSoft),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Long-press action sheet ─────────────────────────────────────────────

  void _showTransactionActions(BuildContext context, FinanceProvider provider,
      int id, double amount, String title) {
    AppDrawer.show(
      context: context,
      builder: (_) {
        return AppDrawer(
          heightFactor: null,
          isBodyScrollable: false,
          headerCard: AppDrawerHeaderCard(
            icon: Icons.receipt_long_rounded,
            iconColor: AppColors.gold,
            title: title,
            subtitle: 'ETB ${NumberFormat("#,##0.00").format(amount)}',
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit Amount
              _actionTile(
                icon: Icons.edit_rounded,
                iconColor: AppColors.gold,
                label: 'Edit Amount',
                sublabel: 'Change the recorded amount',
                onTap: () {
                  Navigator.pop(context);
                  _showEditAmountDialog(context, provider, id, amount);
                },
              ),
              const SizedBox(height: 10),

              // Delete Transaction
              _actionTile(
                icon: Icons.delete_rounded,
                iconColor: AppColors.negative,
                label: 'Delete Transaction',
                sublabel: 'Permanently remove this entry',
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, provider, id, title);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
                  ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sublabel,
                      style: const TextStyle(
                          color: AppColors.textSoft, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSoft, size: 18),
          ],
        ),
      ),
    );
  }

  void _showEditAmountDialog(BuildContext context, FinanceProvider provider,
      int id, double oldAmount) {
    final controller =
        TextEditingController(text: oldAmount.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Edit Amount', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 20),
          autofocus: true,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '0.00',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            suffixText: 'ETB',
            suffixStyle:
                const TextStyle(color: AppColors.textSoft, fontSize: 14),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide.none),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide.none),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          AppButton.secondary(
            text: 'Cancel',
            fullWidth: false,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: () => Navigator.pop(c),
          ),
          const SizedBox(width: 8),
          AppButton.primary(
            text: 'Save',
            fullWidth: false,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: () {
              final amt = double.tryParse(controller.text.trim());
              if (amt != null && amt > 0) {
                provider.updateCashTransactionAmount(id, amt);
                Navigator.pop(c);
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, FinanceProvider provider, int id, String title) {
    AppConfirmDialog.show(
      context: context,
      title: 'Delete Transaction',
      icon: Icons.delete_outline_rounded,
      iconColor: AppColors.negative,
      message: 'Remove "$title" permanently? This cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
      onConfirm: () {
        provider.deleteCashTransaction(id);
      },
    );
  }

  Widget _actionButton(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSoft,
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
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Reason', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g., Snacks, Taxi...',
            hintStyle: const TextStyle(color: AppColors.textSoft),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide.none),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide.none),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          AppButton.secondary(
            text: 'Cancel',
            fullWidth: false,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          AppButton.primary(
            text: 'Add',
            fullWidth: false,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
          ),
        ],
      ),
    );
  }
}
