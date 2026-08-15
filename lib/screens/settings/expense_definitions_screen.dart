import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../models/expense_definition.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_badges.dart';
import 'add_edit_expense_definition_screen.dart';

class ExpenseDefinitionsScreen extends StatelessWidget {
  const ExpenseDefinitionsScreen({super.key});

  String _getRecurringText(ExpenseDefinition def) {
    if (!def.isRecurring) return 'One-time template';
    if (def.recurringType == 'daily') {
      final times = def.timesPerDay;
      return times == 1 ? 'Recurs Daily' : 'Recurs Daily ($times times/day)';
    }
    if (def.recurringType == 'interval') {
      return 'Recurs every ${def.intervalDays ?? 0} days';
    }
    if (def.recurringType == 'specific_day') {
      return 'Recurs on day ${def.specificDay ?? '??'} of month';
    }
    if (def.recurringType == 'days_of_week' && def.selectedDaysOfWeek != null) {
      final map = {
        1: 'Mon',
        2: 'Tue',
        3: 'Wed',
        4: 'Thu',
        5: 'Fri',
        6: 'Sat',
        7: 'Sun'
      };
      final days = def.selectedDaysOfWeek!
          .split(',')
          .map((e) => map[int.tryParse(e.trim())])
          .where((e) => e != null)
          .join(', ');
      return days.isEmpty ? 'Recurring' : 'Recurs on $days';
    }
    return 'Recurring';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    const AppBackButton(),
                    const SizedBox(width: 8),
                    const Text(
                      'Expense Definitions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<FinanceProvider>(
                  builder: (context, provider, child) {
                    final defs = provider.expenseDefinitions;

                    if (defs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'No Expense Templates Defined.\n\nCreate templates for manual or recurring cash expenses.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textSoft,
                                fontSize: 15,
                                height: 1.5),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 16, bottom: 120),
                      itemCount: defs.length,
                      itemBuilder: (context, index) {
                        final def = defs[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // Icon Section
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: (def.isRecurring && def.isActive)
                                        ? AppColors.gold
                                            .withValues(alpha: 0.12)
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    def.reasonId != null
                                        ? Icons.category
                                        : (def.isRecurring
                                            ? Icons.autorenew
                                            : Icons.receipt_long),
                                    color: (def.isRecurring && def.isActive)
                                        ? AppColors.gold
                                        : AppColors.textSoft,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Text Details Section
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        def.name,
                                        style: TextStyle(
                                            color: def.isActive
                                                ? Colors.white
                                                : AppColors.textSoft,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            '${def.defaultAmount.toStringAsFixed(2)} ETB',
                                            style: const TextStyle(
                                                color: AppColors.textSoft,
                                                fontSize: 12),
                                          ),
                                          if (def.reasonId != null) ...[
                                            const SizedBox(width: 8),
                                            const Text('•',
                                                style: TextStyle(
                                                    color: AppColors.textSecondary,
                                                    fontSize: 12)),
                                            const SizedBox(width: 8),
                                            Text(
                                              provider.reasons
                                                      .where((r) =>
                                                          r.id == def.reasonId)
                                                      .firstOrNull
                                                      ?.name ??
                                                  'Categorized',
                                              style: const TextStyle(
                                                  color: AppColors.gold,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            _getRecurringText(def),
                                            style: TextStyle(
                                                color: (def.isRecurring &&
                                                        def.isActive)
                                                    ? AppColors.positive
                                                    : AppColors.textSoft,
                                                fontSize: 12,
                                                fontWeight: def.isRecurring
                                                    ? FontWeight.w500
                                                    : FontWeight.normal),
                                          ),
                                          if (def.isRecurring) ...[
                                            const SizedBox(width: 6),
                                            def.isActive
                                                ? const AppBadge.success(
                                                    text: 'ACTIVE',
                                                    size: AppBadgeSize.micro,
                                                  )
                                                : const AppBadge.neutral(
                                                    text: 'INACTIVE',
                                                    size: AppBadgeSize.micro,
                                                  ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Action Section
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (def.isRecurring)
                                      SizedBox(
                                        height: 32,
                                        child: Transform.scale(
                                          scale: 0.75,
                                          alignment: Alignment.centerRight,
                                          child: AppSwitch(
                                            value: def.isActive,
                                            onChanged: (val) {
                                              provider.updateExpenseDefinition(
                                                  def.copyWith(isActive: val));
                                            },
                                          ),
                                        ),
                                      ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(8),
                                          icon: const Icon(Icons.edit_outlined,
                                              color: AppColors.textSecondary,
                                              size: 18),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    AddEditExpenseDefinitionScreen(
                                                        expenseDefinition: def),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(8),
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: AppColors.negative,
                                              size: 18),
                                          onPressed: () {
                                            AppConfirmDialog.show(
                                              context: context,
                                              title: 'Delete Template',
                                              icon: Icons.delete_outline_rounded,
                                              iconColor: AppColors.negative,
                                              message:
                                                  'Are you sure you want to delete "${def.name}"?',
                                              confirmText: 'Delete',
                                              cancelText: 'Cancel',
                                              isDestructive: true,
                                              onConfirm: () {
                                                provider.deleteExpenseDefinition(def.id!);
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: AppButton.primary(
              text: 'Add Definition',
              icon: Icons.add_rounded,
              height: 50,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const AddEditExpenseDefinitionScreen(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
