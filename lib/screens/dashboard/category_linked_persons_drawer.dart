import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/reason.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/counterparty_matcher.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/app_text_field.dart';
import 'reason_link_drawer.dart';

/// Standard drawer to view, manage, and link counterparties/persons to a specific
/// category or subcategory.
class CategoryLinkedPersonsDrawer extends StatelessWidget {
  final AppReason reason;

  const CategoryLinkedPersonsDrawer({
    super.key,
    required this.reason,
  });

  static Future<void> show(
    BuildContext context, {
    required AppReason reason,
  }) {
    return AppDrawer.show(
      context: context,
      builder: (_) => CategoryLinkedPersonsDrawer(reason: reason),
    );
  }

  void _showLinkPersonDrawer(
    BuildContext context,
    TransactionsViewModel txVM,
  ) {
    final nameCtrl = TextEditingController();
    String linkType = 'receiver'; // 'receiver' (Expense) or 'sender' (Income)
    LinkScope scope = LinkScope.allTransactions;
    int selectedReasonId = reason.id!;
    String selectedReasonName = reason.name;

    final subcategories = reason.isTopLevelCategory
        ? txVM.subcategoriesFor(reason.id!)
        : <AppReason>[];

    final knownNames = txVM.uniqueCounterparties;

    AppDrawer.show(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setInner) {
            final query = nameCtrl.text.trim().toLowerCase();
            final filteredSuggestions = query.isEmpty
                ? knownNames.take(3).toList()
                : knownNames
                    .where((n) => n.toLowerCase().contains(query))
                    .take(3)
                    .toList();

            return AppDrawer(
              heightFactor: 0.88,
              maxHeightFactor: 0.94,
              headerCard: AppDrawerHeaderCard(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Link Person',
                subtitle: 'Auto-categorize transactions for "${reason.name}"',
              ),
              bottomAction: Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      text: 'Cancel',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: AppButton.primary(
                      text: 'Link Person',
                      icon: Icons.link_rounded,
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          AppToast.warning(context,
                              message: 'Please enter a person name');
                          return;
                        }

                        await txVM.addReasonLinkScoped(
                          reasonId: selectedReasonId,
                          linkedName: name,
                          linkType: linkType,
                          scope: scope,
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          AppToast.success(
                            context,
                            message:
                                'Linked "$name" to "$selectedReasonName" (${linkType == 'sender' ? 'Income' : 'Expense'})',
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Person Name Field with Clean White Person Icon
                    AppTextField.modal(
                      controller: nameCtrl,
                      hint: 'Person or counterparty name...',
                      maxLength: 60,
                      prefixIcon: Icons.person_outline_rounded,
                      prefixIconColor: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      onChanged: (_) => setInner(() {}),
                    ),

                    // Suggestions Chips (Max 3, Pill Shaped)
                    if (filteredSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        query.isEmpty ? 'RECENT CONTACTS' : 'MATCHING CONTACTS',
                        style: const TextStyle(
                          color: AppColors.textSoft,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: filteredSuggestions.map((n) {
                          final isSelected =
                              nameCtrl.text.trim().toLowerCase() ==
                                  n.toLowerCase();
                          return AppButton.pill(
                            text: n,
                            isSelected: isSelected,
                            onPressed: () {
                              setInner(() {
                                nameCtrl.text = n;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    // 2. Subcategory Picker (if top-level category has subcategories)
                    if (subcategories.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'TARGET REASON / SUBCATEGORY',
                        style: TextStyle(
                          color: AppColors.textSoft,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          AppButton.pill(
                            text: '${reason.name} (General)',
                            isSelected: selectedReasonId == reason.id,
                            onPressed: () {
                              setInner(() {
                                selectedReasonId = reason.id!;
                                selectedReasonName = reason.name;
                              });
                            },
                          ),
                          ...subcategories.map((sub) {
                            final isSelected = selectedReasonId == sub.id;
                            return AppButton.pill(
                              text: sub.name,
                              isSelected: isSelected,
                              onPressed: () {
                                setInner(() {
                                 selectedReasonId = sub.id!;
                                 selectedReasonName = sub.name;
                                });
                              },
                            );
                          }),
                        ],
                      ),
                    ],

                    // 3. Transaction Direction (Expense vs Income)
                    const SizedBox(height: 16),
                    const Text(
                      'TRANSACTION DIRECTION',
                      style: TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton.pill(
                            text: 'Outgoing (Expenses)',
                            icon: Icons.arrow_outward_rounded,
                            isSelected: linkType == 'receiver',
                            onPressed: () {
                              setInner(() => linkType = 'receiver');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton.pill(
                            text: 'Incoming (Income)',
                            icon: Icons.arrow_downward_rounded,
                            isSelected: linkType == 'sender',
                            onPressed: () {
                              setInner(() => linkType = 'sender');
                            },
                          ),
                        ),
                      ],
                    ),

                    // 4. Linking Scope
                    const SizedBox(height: 16),
                    const Text(
                      'LINKING SCOPE',
                      style: TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton.pill(
                            text: 'All (Past & Future)',
                            isSelected: scope == LinkScope.allTransactions,
                            onPressed: () {
                              setInner(() => scope = LinkScope.allTransactions);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton.pill(
                            text: 'From Now On (Future)',
                            isSelected:
                                scope == LinkScope.futureTransactionsOnly,
                            onPressed: () {
                              setInner(() =>
                                  scope = LinkScope.futureTransactionsOnly);
                            },
                          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final txVM = Provider.of<TransactionsViewModel>(context);

    final List<AppReasonLink> links = reason.isTopLevelCategory
        ? txVM.allLinksForCategoryTree(reason.id!)
        : txVM.linksForReason(reason.id!);

    return AppDrawer(
      heightFactor: 0.85,
      maxHeightFactor: 0.92,
      headerCard: AppDrawerHeaderCard(
        icon: Icons.people_outline_rounded,
        title: 'Linked Persons',
        subtitle: 'Auto-categorization rules for "${reason.name}"',
        trailing: AppBadge.neutral(
          text: '${links.length} ${links.length == 1 ? 'person' : 'persons'}',
          size: AppBadgeSize.small,
        ),
      ),
      bottomAction: AppButton.primary(
        text: 'Link New Person',
        icon: Icons.person_add_alt_1_rounded,
        onPressed: () => _showLinkPersonDrawer(context, txVM),
      ),
      child: links.isEmpty
          ? _buildEmptyState(context, txVM)
          : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: links.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final link = links[index];
                return _buildLinkCard(context, txVM, link);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, TransactionsViewModel txVM) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.link_off_rounded,
                color: Colors.white38,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Persons Linked Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Link contacts or counterparties so incoming or outgoing transfers are automatically categorized under "${reason.name}".',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkCard(
    BuildContext context,
    TransactionsViewModel txVM,
    AppReasonLink link,
  ) {
    final expectedType = link.linkType == 'sender' ? 'income' : 'expense';
    final matchingCount = txVM.transactions.where((t) {
      final matchesName =
          CounterpartyMatcher.matches(t.sender, link.linkedName);
      final matchesType = t.type.toLowerCase() == expectedType;
      return matchesName && matchesType;
    }).length;

    // Resolve reason name if this is a subcategory link inside a parent category view
    String? subcategoryName;
    if (reason.isTopLevelCategory && link.reasonId != reason.id) {
      final sub = txVM.reasons.firstWhere(
        (r) => r.id == link.reasonId,
        orElse: () => AppReason(name: ''),
      );
      if (sub.name.isNotEmpty) {
        subcategoryName = sub.name;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.drawerCard,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              link.linkType == 'sender'
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_outward_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        link.linkedName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AppBadge.neutral(
                      text:
                          '$matchingCount ${matchingCount == 1 ? 'tx' : 'txs'}',
                      size: AppBadgeSize.micro,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      link.linkType == 'sender'
                          ? 'Incoming (Sender)'
                          : 'Outgoing (Receiver)',
                      style: const TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 11,
                      ),
                    ),
                    if (subcategoryName != null) ...[
                      const Text(
                        ' • ',
                        style: TextStyle(color: Colors.white24, fontSize: 11),
                      ),
                      Text(
                        subcategoryName,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Unlink button (IconButton)
          IconButton(
            icon: const Icon(Icons.link_off_rounded,
                color: AppColors.textSoft, size: 20),
            tooltip: 'Unlink Person',
            onPressed: () {
              UnlinkReasonDrawer.show(
                context: context,
                link: link,
                reasonName: subcategoryName ?? reason.name,
                contactName: link.linkedName,
              );
            },
          ),
        ],
      ),
    );
  }
}
