import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';
import 'app_drawer.dart';
import 'app_text_field.dart';

/// Shows a drawer allowing the user to select an existing counterparty or enter a new one.
class CounterpartySelectorModal {
  static Future<String?> show({
    required BuildContext context,
    required List<String> existingCounterparties,
    String? currentCounterparty,
    String title = 'Select Counterparty',
    String subtitle = 'Choose who this transaction was with',
  }) {
    return AppDrawer.show<String>(
      context: context,
      builder: (context) => _CounterpartySelectorContent(
        existingCounterparties: existingCounterparties,
        currentCounterparty: currentCounterparty,
        title: title,
      ),
    );
  }
}

class _CounterpartySelectorContent extends StatefulWidget {
  final List<String> existingCounterparties;
  final String? currentCounterparty;
  final String title;

  const _CounterpartySelectorContent({
    required this.existingCounterparties,
    this.currentCounterparty,
    required this.title,
  });

  @override
  State<_CounterpartySelectorContent> createState() =>
      _CounterpartySelectorContentState();
}

class _CounterpartySelectorContentState
    extends State<_CounterpartySelectorContent> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cleanList = widget.existingCounterparties
        .where((c) =>
            c.trim().isNotEmpty &&
            c != 'Unspecified' &&
            c != 'Manual Entry' &&
            c != 'Cash')
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final filtered = _searchQuery.isEmpty
        ? cleanList
        : cleanList
            .where((c) => c.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    final bool isQueryNew = _searchQuery.isNotEmpty &&
        !cleanList.any((c) => c.toLowerCase() == _searchQuery.toLowerCase());

    return AppDrawer(
      heightFactor: 0.85,
      headerCard: AppDrawerHeaderCard(
        icon: Icons.person_search_rounded,
        title: widget.title,
      ),
      bottomAction: isQueryNew
          ? AppButton.primary(
              text: 'Use "$_searchQuery"',
              icon: Icons.add_rounded,
              height: 48,
              onPressed: () {
                Navigator.pop(context, _searchQuery);
              },
            )
          : null,
      child: Column(
        children: [
          AppTextField(
            controller: _searchController,
            label: 'SEARCH OR ENTER COUNTERPARTY',
            hint: 'e.g. Abebe, Supermarket, Mom...',
            prefixIcon: Icons.search_rounded,
            backgroundColor: AppColors.previewCardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          const SizedBox(height: 14),
          if (isQueryNew) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context, _searchQuery),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.previewCardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.buttonSecondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: AppColors.buttonSecondaryText, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add "$_searchQuery"',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Text(
                            'Create as a new counterparty',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No counterparties recorded yet'
                          : 'No matching counterparties found',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isSelected =
                          widget.currentCounterparty?.toLowerCase() ==
                              item.toLowerCase();

                      return GestureDetector(
                        onTap: () => Navigator.pop(context, item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.surfaceElevated
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(
                                  color: AppColors.buttonSecondary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    item.isNotEmpty
                                        ? item[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: AppColors.buttonSecondaryText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.positive, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
