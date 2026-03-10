import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/reason.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';

class ReasonSelectionSheet extends StatefulWidget {
  final AppReason? initialReason;
  final Function(AppReason) onReasonSelected;

  const ReasonSelectionSheet({
    super.key,
    this.initialReason,
    required this.onReasonSelected,
  });

  @override
  State<ReasonSelectionSheet> createState() => _ReasonSelectionSheetState();
}

class _ReasonSelectionSheetState extends State<ReasonSelectionSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final reasons = provider.reasons
        .where((r) => r.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1F24),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Reason',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.labelGray),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search for a reason...',
              hintStyle: const TextStyle(color: AppColors.labelGray),
              prefixIcon: const Icon(Icons.search, color: AppColors.labelGray),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: reasons.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No reasons found.',
                          style: TextStyle(color: AppColors.labelGray),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (_searchQuery.trim().isNotEmpty) {
                              final newReason =
                                  await provider.addReason(_searchQuery.trim());
                              widget.onReasonSelected(newReason);
                              if (mounted) Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: Text('Create "$_searchQuery"'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: reasons.length,
                    itemBuilder: (context, index) {
                      final reason = reasons[index];
                      final isSelected = widget.initialReason?.id == reason.id;

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.category_outlined,
                            color: AppColors.primaryBlue,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          reason.name,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primaryBlue
                                : Colors.white,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: AppColors.primaryBlue)
                            : null,
                        onTap: () {
                          widget.onReasonSelected(reason);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
