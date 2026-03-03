import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import 'add_edit_expense_definition_screen.dart';
import '../shell/custom_bottom_nav_bar.dart';

class ExpenseDefinitionsScreen extends StatelessWidget {
  const ExpenseDefinitionsScreen({super.key});

  String _getRecurringText(var def) {
    if (!def.isRecurring) return 'One-time template';
    if (def.recurringType == 'daily') {
      final times = def.timesPerDay;
      return times == 1 ? 'Recurs Daily' : 'Recurs Daily ($times times/day)';
    }
    if (def.recurringType == 'interval') {
      return 'Recurs every ${def.intervalDays} days';
    }
    if (def.recurringType == 'specific_day') {
      return 'Recurs on day ${def.specificDay} of month';
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
        backgroundColor: const Color(0xFF1F1F25),
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 20.0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Expense Definitions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                            style: TextStyle(
                                color: AppColors.textGray.withOpacity(0.5),
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
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.02)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                def.isRecurring
                                    ? Icons.autorenew
                                    : Icons.receipt_long,
                                color: AppColors.primaryBlue,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              def.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Default: ${def.defaultAmount.toStringAsFixed(2)} ETB',
                                    style: const TextStyle(
                                        color: AppColors.textGray,
                                        fontSize: 12),
                                  ),
                                  Text(_getRecurringText(def),
                                      style: TextStyle(
                                          color: def.isRecurring
                                              ? AppColors.mintGreen
                                              : AppColors.textGray
                                                  .withOpacity(0.6),
                                          fontSize: 12,
                                          fontWeight: def.isRecurring
                                              ? FontWeight.w500
                                              : FontWeight.normal)),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      color: AppColors.textGray, size: 20),
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
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: AppColors.alertRed, size: 20),
                                  onPressed: () {
                                    showDialog(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                              backgroundColor:
                                                  const Color(0xFF1C1F24),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20)),
                                              title: const Text(
                                                  'Delete Template',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                              content: Text(
                                                  'Are you sure you want to delete "${def.name}"?',
                                                  style: const TextStyle(
                                                      color:
                                                          AppColors.textGray)),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(c),
                                                    child: const Text('Cancel',
                                                        style: TextStyle(
                                                            color: AppColors
                                                                .textGray))),
                                                TextButton(
                                                    onPressed: () {
                                                      provider
                                                          .deleteExpenseDefinition(
                                                              def.id!);
                                                      Navigator.pop(c);
                                                    },
                                                    child: const Text('Delete',
                                                        style: TextStyle(
                                                            color: AppColors
                                                                .alertRed))),
                                              ],
                                            ));
                                  },
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
        bottomNavigationBar: DynamicNavBarWrapper(
          currentIndex:
              4, // Settings is typically active here, but hidden by dynamic state
          onTap: (_) {},
          isDynamic: true,
          onDynamicAdd: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddEditExpenseDefinitionScreen(),
              ),
            );
          },
          onDynamicBack: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
