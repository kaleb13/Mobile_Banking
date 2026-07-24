import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/reason.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interactive_drag_handle.dart';

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

  static const _specialReasonNames = {
    'loan',
    'internal transfer',
    'bounce',
    'cash',
    'airtime',
  };

  bool _isSpecial(AppReason r) {
    final nameLower = r.name.trim().toLowerCase();
    return _specialReasonNames.contains(nameLower) || nameLower.contains('loan');
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final allFiltered = provider.reasons
        .where((r) => r.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    final specialReasons = allFiltered.where(_isSpecial).toList();
    final generalReasons = allFiltered.where((r) => !_isSpecial(r)).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: InteractiveDragHandle(
              color: Colors.white.withValues(alpha: 0.25),
              onTap: () => Navigator.pop(context),
              onVerticalDragUpdate: (details) {
                if ((details.primaryDelta ?? 0) > 3) {
                  Navigator.pop(context);
                }
              },
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Reason',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
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
              hintStyle: const TextStyle(color: AppColors.textSoft, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSoft, size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: allFiltered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No reasons found.',
                          style: TextStyle(color: AppColors.textSoft),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (_searchQuery.trim().isNotEmpty) {
                              final newReason =
                                  await provider.addReason(_searchQuery.trim());
                              widget.onReasonSelected(newReason);
                              if (mounted && context.mounted) {
                                Navigator.pop(context);
                              }
                            }
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: Text('Create "$_searchQuery"'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.positive,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (specialReasons.isNotEmpty) ...[
                        _buildSectionHeader('SPECIAL REASONS', Icons.star_outline_rounded),
                        const SizedBox(height: 8),
                        ...specialReasons.map((r) => _buildReasonTile(r)),
                        const SizedBox(height: 20),
                      ],
                      if (generalReasons.isNotEmpty) ...[
                        _buildSectionHeader('GENERAL REASONS', Icons.category_outlined),
                        const SizedBox(height: 8),
                        ...generalReasons.map((r) => _buildReasonTile(r)),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.positive, size: 14),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSoft,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonTile(AppReason reason) {
    final isSelected = widget.initialReason?.id == reason.id;
    final isLoan = reason.name.toLowerCase().contains('loan');

    IconData iconData = Icons.category_outlined;
    if (isLoan) {
      iconData = Icons.handshake_outlined;
    } else if (reason.name.toLowerCase() == 'internal transfer') {
      iconData = Icons.swap_horiz_rounded;
    } else if (reason.name.toLowerCase() == 'cash') {
      iconData = Icons.payments_outlined;
    } else if (reason.name.toLowerCase() == 'airtime') {
      iconData = Icons.phone_android_rounded;
    } else if (reason.name.toLowerCase() == 'bounce') {
      iconData = Icons.replay_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.positive.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppColors.positive.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.positive.withValues(alpha: 0.2)
                : isLoan
                    ? AppColors.positive.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
          child: Icon(
            iconData,
            color: isSelected
                ? AppColors.positive
                : isLoan
                    ? AppColors.positive
                    : Colors.white70,
            size: 18,
          ),
        ),
        title: Text(
          reason.name,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle_rounded,
                color: AppColors.positive, size: 20)
            : null,
        onTap: () {
          widget.onReasonSelected(reason);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
