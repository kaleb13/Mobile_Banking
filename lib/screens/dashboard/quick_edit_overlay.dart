import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_text_field.dart';

enum _QuickEditView {
  categories,
  internalTransfer,
  loan,
}

/// Top-down 3/4 screen height drawer for transaction categorization.
///
/// Displayed inside the transparent [TransactionQuickEditActivity].
/// Features:
/// 1. Minimalistic 2x2 Special Reasons Grid (Internal Transfer, Loan, Pass-Through, Cash).
/// 2. In-place interactive workflows for Internal Transfer linking (with dual-SMS cleanup)
///    and Loan record creation without launching the full application.
/// 3. Grouped parent categories with drill-down subcategories ("Go Deeper").
class QuickEditOverlay extends StatefulWidget {
  const QuickEditOverlay({super.key});

  @override
  State<QuickEditOverlay> createState() => _QuickEditOverlayState();
}

class _QuickEditOverlayState extends State<QuickEditOverlay>
    with SingleTickerProviderStateMixin {
  static const _channel = MethodChannel('com.shibre/quick_edit');

  _QuickEditView _currentView = _QuickEditView.categories;

  String _bankName = '';
  String _amount = '';
  double _rawAmount = 0.0;
  String _type = 'expense';
  String _sender = '';
  String _dateStr = '';

  List<_CategoryGroup> _categoryGroups = [];
  int? _expandedGroupId;
  int? _selectedReasonId;
  String? _selectedReasonName;
  bool _loaded = false;
  bool _isSaving = false;
  bool _linkReasonRule = false;

  // Internal Transfer Sub-flow state
  List<Map<String, dynamic>> _transferCandidates = [];
  bool _loadingCandidates = false;
  String? _selectedCandidateId;

  // Loan Sub-flow state
  late final TextEditingController _loanPersonController;
  late final TextEditingController _loanNoteController;
  String _loanType = 'lent';
  DateTime _loanDueDate = DateTime.now().add(const Duration(days: 30));

  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _loanPersonController = TextEditingController();
    _loanNoteController = TextEditingController();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _loadTransactionData();
  }

  @override
  void dispose() {
    _loanPersonController.dispose();
    _loanNoteController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactionData() async {
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'getTransactionData',
      );
      if (data == null) return;

      final reasonsList = (data['reasons'] as List?)?.cast<Map>() ?? [];

      setState(() {
        _bankName = data['bankName'] as String? ?? '';
        _amount = data['amount'] as String? ?? '';
        _rawAmount = (data['rawAmount'] as num?)?.toDouble() ?? 0.0;
        _type = data['type'] as String? ?? 'expense';
        _sender = data['sender'] as String? ?? '';
        _dateStr = data['date'] as String? ?? '';

        _loanType = _type == 'income' ? 'borrowed' : 'lent';
        if (_sender.isNotEmpty && _sender != 'Unknown') {
          _loanPersonController.text = _sender;
        }

        // Separate parents and subcategories (excluding special reasons from standard hierarchy)
        final allReasons = reasonsList
            .map((m) => _ReasonItem(
                  id: m['id'] as int,
                  name: m['name'] as String,
                  parentId: m['parentId'] as int?,
                  isSpecial: (m['isSpecial'] as bool?) ?? false,
                ))
            .where((r) => !r.isSpecial)
            .toList();

        final parents = allReasons.where((r) => r.parentId == null).toList();

        // Sort top-level categories by frequent expense hierarchy
        const canonicalOrder = [
          'food',
          'drink',
          'transportation',
          'transport',
          'housing',
          'utilities',
          'mobile & internet',
          'goods',
          'entertainment',
          'health & personal care',
          'education',
          'investment & savings',
          'salary',
        ];
        parents.sort((a, b) {
          final aName = a.name.trim().toLowerCase();
          final bName = b.name.trim().toLowerCase();
          final aIdx = canonicalOrder.indexOf(aName);
          final bIdx = canonicalOrder.indexOf(bName);
          if (aIdx != -1 && bIdx != -1) return aIdx.compareTo(bIdx);
          if (aIdx != -1) return -1;
          if (bIdx != -1) return 1;
          return a.name.compareTo(b.name);
        });

        if (parents.isEmpty) {
          _categoryGroups = [
            _CategoryGroup(
              parent: const _ReasonItem(id: 1, name: 'Food'),
              subcategories: const [
                _ReasonItem(id: 101, name: 'Breakfast', parentId: 1),
                _ReasonItem(id: 102, name: 'Lunch', parentId: 1),
                _ReasonItem(id: 103, name: 'Dinner', parentId: 1),
                _ReasonItem(id: 104, name: 'Bakery', parentId: 1),
                _ReasonItem(id: 105, name: 'Snacks', parentId: 1),
              ],
            ),
            _CategoryGroup(
              parent: const _ReasonItem(id: 2, name: 'Drink'),
              subcategories: const [
                _ReasonItem(id: 201, name: 'Coffee', parentId: 2),
                _ReasonItem(id: 202, name: 'Tea', parentId: 2),
                _ReasonItem(id: 203, name: 'Keshir', parentId: 2),
                _ReasonItem(id: 204, name: 'Beer & Alcohol', parentId: 2),
                _ReasonItem(id: 205, name: 'Soft Drinks', parentId: 2),
                _ReasonItem(id: 206, name: 'Juices', parentId: 2),
              ],
            ),
            _CategoryGroup(
              parent: const _ReasonItem(id: 3, name: 'Transportation'),
              subcategories: const [
                _ReasonItem(id: 301, name: 'Fuel & Gas', parentId: 3),
                _ReasonItem(id: 302, name: 'Taxi & Rideshare', parentId: 3),
                _ReasonItem(id: 303, name: 'Public Transit', parentId: 3),
                _ReasonItem(id: 304, name: 'Parking & Tolls', parentId: 3),
                _ReasonItem(id: 305, name: 'Vehicle Maintenance', parentId: 3),
              ],
            ),
            _CategoryGroup(
              parent: const _ReasonItem(id: 4, name: 'Housing'),
              subcategories: const [
                _ReasonItem(id: 401, name: 'Rent', parentId: 4),
                _ReasonItem(id: 402, name: 'Mortgage', parentId: 4),
                _ReasonItem(id: 403, name: 'Property Tax', parentId: 4),
                _ReasonItem(id: 404, name: 'Home Repairs', parentId: 4),
                _ReasonItem(id: 405, name: 'Furniture', parentId: 4),
              ],
            ),
            _CategoryGroup(
              parent: const _ReasonItem(id: 5, name: 'Utilities'),
              subcategories: const [
                _ReasonItem(id: 501, name: 'Electricity', parentId: 5),
                _ReasonItem(id: 502, name: 'Water', parentId: 5),
                _ReasonItem(id: 503, name: 'Gas', parentId: 5),
                _ReasonItem(id: 504, name: 'Garbage & Sewer', parentId: 5),
              ],
            ),
            _CategoryGroup(
              parent: const _ReasonItem(id: 6, name: 'Mobile & Internet'),
              subcategories: const [
                _ReasonItem(id: 601, name: 'Airtime', parentId: 6),
                _ReasonItem(id: 602, name: 'Package', parentId: 6),
                _ReasonItem(id: 603, name: 'Internet', parentId: 6),
                _ReasonItem(id: 604, name: 'Wifi', parentId: 6),
              ],
            ),
            _CategoryGroup(
              parent: const _ReasonItem(id: 7, name: 'Goods'),
              subcategories: const [
                _ReasonItem(id: 701, name: 'Clothing & Apparel', parentId: 7),
                _ReasonItem(id: 702, name: 'Electronics', parentId: 7),
                _ReasonItem(id: 703, name: 'Household Supplies', parentId: 7),
                _ReasonItem(id: 704, name: 'Supermarket Goods', parentId: 7),
                _ReasonItem(id: 705, name: 'Gifts', parentId: 7),
              ],
            ),
          ];
        } else {
          _categoryGroups = parents.map((p) {
            final subs = allReasons.where((r) => r.parentId == p.id).toList();
            return _CategoryGroup(parent: p, subcategories: subs);
          }).toList();
        }

        _loaded = true;
      });

      _animController.forward();
    } catch (e) {
      debugPrint('QuickEditOverlay: failed to load data: $e');
    }
  }

  void _selectReason(_ReasonItem item) {
    setState(() {
      _selectedReasonId = item.id;
      _selectedReasonName = item.name;
    });
  }

  void _toggleGroup(_CategoryGroup group) {
    setState(() {
      if (_expandedGroupId == group.parent.id) {
        _expandedGroupId = null;
      } else {
        _expandedGroupId = group.parent.id;
      }
    });
  }

  // ── SPECIAL REASON 1: Direct Pass-Through / Reversal Save ─────────────────
  Future<void> _savePassThrough() async {
    setState(() => _isSaving = true);
    try {
      await _channel.invokeMethod('saveReason', {
        'reasonName': 'Pass-Through',
        'reasonId': null,
      });
    } catch (e) {
      debugPrint('QuickEditOverlay: savePassThrough failed: $e');
    }
    SystemNavigator.pop();
  }

  // ── SPECIAL REASON 2: Direct Cash Save ───────────────────────────────────
  Future<void> _saveCash() async {
    setState(() => _isSaving = true);
    final cashReason = _type == 'income' ? 'Cash Deposit' : 'Cash Withdrawal';
    try {
      await _channel.invokeMethod('saveReason', {
        'reasonName': cashReason,
        'reasonId': null,
      });
    } catch (e) {
      debugPrint('QuickEditOverlay: saveCash failed: $e');
    }
    SystemNavigator.pop();
  }

  // ── SPECIAL REASON 3: Open Internal Transfer Matcher ─────────────────────
  Future<void> _openInternalTransferFlow() async {
    setState(() {
      _currentView = _QuickEditView.internalTransfer;
      _loadingCandidates = true;
      _selectedCandidateId = null;
    });

    try {
      final candidates = await _channel.invokeListMethod<Map>('getTransferCandidates') ?? [];
      final targetType = _type.toLowerCase() == 'income' ? 'expense' : 'income';
      final currentAmt = _rawAmount > 0
          ? _rawAmount
          : double.tryParse(_amount.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

      final filtered = candidates
          .map((m) => Map<String, dynamic>.from(m))
          .where((item) {
            final cType = (item['type'] as String? ?? '').toLowerCase();
            final cAmt = (item['amount'] as num?)?.toDouble() ?? 0.0;
            if (cType != targetType) return false;
            if (currentAmt > 0 && (cAmt - currentAmt).abs() > 0.01) return false;
            return true;
          })
          .toList();

      if (mounted) {
        setState(() {
          _transferCandidates = filtered;
          _loadingCandidates = false;
        });
      }
    } catch (e) {
      debugPrint('QuickEditOverlay: getTransferCandidates failed: $e');
      if (mounted) {
        setState(() => _loadingCandidates = false);
      }
    }
  }

  Future<void> _confirmInternalTransfer() async {
    if (_selectedCandidateId == null) return;
    setState(() => _isSaving = true);

    try {
      await _channel.invokeMethod('linkInternalTransfer', {
        'targetTxId': _selectedCandidateId,
      });
    } catch (e) {
      debugPrint('QuickEditOverlay: linkInternalTransfer failed: $e');
    }
    SystemNavigator.pop();
  }

  // ── SPECIAL REASON 4: Open Loan Record Creator ───────────────────────────
  void _openLoanFlow() {
    setState(() {
      _currentView = _QuickEditView.loan;
    });
  }

  Future<void> _saveLoanRecord() async {
    final personName = _loanPersonController.text.trim();
    if (personName.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await _channel.invokeMethod('saveLoan', {
        'loanType': _loanType,
        'personName': personName,
        'trackedSenderName': _bankName,
        'amount': _rawAmount > 0 ? _rawAmount : double.tryParse(_amount.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0,
        'loanDate': _dateStr.isNotEmpty ? _dateStr : DateTime.now().toIso8601String(),
        'dueDate': _loanDueDate.toIso8601String(),
        'note': _loanNoteController.text.trim().isNotEmpty ? _loanNoteController.text.trim() : null,
      });
    } catch (e) {
      debugPrint('QuickEditOverlay: saveLoan failed: $e');
    }
    SystemNavigator.pop();
  }

  // ── Standard Category Save ───────────────────────────────────────────────
  Future<void> _saveStandardReason() async {
    if (_selectedReasonName == null) return;
    setState(() => _isSaving = true);
    try {
      if (_linkReasonRule && _sender.isNotEmpty && _sender != 'Unknown') {
        await _channel.invokeMethod('saveReasonWithRule', {
          'reasonName': _selectedReasonName,
          'reasonId': _selectedReasonId,
          'contactName': _sender,
        });
      } else {
        await _channel.invokeMethod('saveReason', {
          'reasonName': _selectedReasonName,
          'reasonId': _selectedReasonId,
        });
      }
    } catch (e) {
      debugPrint('QuickEditOverlay: save failed: $e');
    }
    SystemNavigator.pop();
  }

  Future<void> _openApp() async {
    try {
      await _channel.invokeMethod('openApp');
    } catch (_) {}
    SystemNavigator.pop();
  }

  Future<void> _dismiss() async {
    try {
      await _channel.invokeMethod('dismiss');
    } catch (_) {}
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final threeQuarterHeight = mediaQuery.size.height * 0.80;

    return GestureDetector(
      onTap: _dismiss,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () {}, // Absorb taps on drawer body
                child: _loaded
                    ? FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: _buildTopDrawer(
                              context, topPadding, threeQuarterHeight),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopDrawer(
      BuildContext context, double topPadding, double threeQuarterHeight) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: threeQuarterHeight),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 36,
            spreadRadius: 4,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _buildCurrentViewBody(),
      ),
    );
  }

  Widget _buildCurrentViewBody() {
    switch (_currentView) {
      case _QuickEditView.internalTransfer:
        return _buildInternalTransferView();
      case _QuickEditView.loan:
        return _buildLoanView();
      case _QuickEditView.categories:
        return _buildMainCategoriesView();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW 1: MAIN CATEGORIES & 2x2 SPECIAL REASONS MATRIX
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMainCategoriesView() {
    final isExpense = _type.toLowerCase() == 'expense';

    return Column(
      key: const ValueKey('view_categories'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top Header Row ──────────────────────────────────────────────────
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.category_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Categorize',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: _dismiss,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white70,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Compact Amount & Direction Strip ────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.drawerCard,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isExpense ? AppColors.warning : AppColors.positive)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isExpense
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: isExpense ? AppColors.warning : AppColors.positive,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _bankName.isNotEmpty ? _bankName : 'Transaction',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _amount.isNotEmpty ? _amount : 'ETB 0.00',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── Minimalistic 2x2 Special Reasons Grid (No wordy descriptions) ──
        Row(
          children: [
            Expanded(
              child: _buildSpecialReasonCard(
                icon: Icons.sync_alt_rounded,
                title: 'Internal Transfer',
                onTap: _openInternalTransferFlow,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSpecialReasonCard(
                icon: Icons.handshake_outlined,
                title: 'Record Loan',
                onTap: _openLoanFlow,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildSpecialReasonCard(
                icon: Icons.undo_rounded,
                title: 'Pass-Through',
                onTap: _savePassThrough,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSpecialReasonCard(
                icon: Icons.account_balance_wallet_outlined,
                title: isExpense ? 'Cash Out' : 'Cash In',
                onTap: _saveCash,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Grouped Standard Categories List ────────────────────────────────
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            'OR SELECT CATEGORY',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 6),

        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: _categoryGroups.length,
            itemBuilder: (context, index) {
              final group = _categoryGroups[index];
              return _buildGroupCard(group);
            },
          ),
        ),
        const SizedBox(height: 10),

        // ── Auto-Link Reason Rule Section ──────────────────────────────────
        GestureDetector(
          onTap: _selectedReasonName != null
              ? () {
                  HapticFeedback.lightImpact();
                  setState(() => _linkReasonRule = !_linkReasonRule);
                }
              : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _selectedReasonName != null
                  ? (_linkReasonRule
                      ? AppColors.positive.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.05))
                  : Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 16,
                  color: _selectedReasonName != null
                      ? (_linkReasonRule ? AppColors.positive : Colors.white70)
                      : AppColors.textSoft.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedReasonName != null
                            ? (_sender.isNotEmpty && _sender != 'Unknown'
                                ? 'Auto-link to "$_sender"'
                                : 'Always auto-link this reason')
                            : 'Select a reason to enable auto-linking',
                        style: TextStyle(
                          color: _selectedReasonName != null
                              ? Colors.white
                              : AppColors.textSoft.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: _selectedReasonName != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_selectedReasonName != null)
                        Text(
                          'Categorize future SMS automatically',
                          style: TextStyle(
                            color: _linkReasonRule
                                ? AppColors.positive.withValues(alpha: 0.8)
                                : AppColors.textSoft,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _linkReasonRule && _selectedReasonName != null
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: _selectedReasonName != null
                      ? (_linkReasonRule
                          ? AppColors.positive
                          : AppColors.textSoft)
                      : AppColors.textSoft.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Bottom Action Row (Save & Open App) ─────────────────────────────
        Row(
          children: [
            Expanded(
              child: AppButton.primary(
                text: _selectedReasonName != null
                    ? (_linkReasonRule ? 'Save & Link Rule' : 'Save as "$_selectedReasonName"')
                    : 'Select Category',
                height: 44,
                isLoading: _isSaving,
                onPressed: _selectedReasonName != null ? _saveStandardReason : null,
              ),
            ),
            const SizedBox(width: 8),
            AppButton.secondary(
              text: 'Open App',
              icon: Icons.arrow_forward_rounded,
              fullWidth: false,
              height: 44,
              onPressed: _openApp,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecialReasonCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(_CategoryGroup group) {
    final isParentSelected = _selectedReasonId == group.parent.id;
    final isExpanded = _expandedGroupId == group.parent.id;
    final hasSubcategories = group.subcategories.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isParentSelected
            ? AppColors.positive.withValues(alpha: 0.12)
            : AppColors.drawerCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              _selectReason(group.parent);
              if (hasSubcategories && !isExpanded) {
                setState(() => _expandedGroupId = group.parent.id);
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(group.parent.name),
                    size: 16,
                    color: isParentSelected
                        ? AppColors.positive
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.parent.name,
                      style: TextStyle(
                        color: isParentSelected ? Colors.white : Colors.white70,
                        fontSize: 13,
                        fontWeight: isParentSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (hasSubcategories) ...[
                    AppBadge.success(
                      text: 'Go deeper',
                      icon: isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.chevron_right_rounded,
                      size: AppBadgeSize.small,
                      onTap: () => _toggleGroup(group),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (hasSubcategories && isExpanded) ...[
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: group.subcategories.map((sub) {
                  final isSubSelected = _selectedReasonId == sub.id;
                  return GestureDetector(
                    onTap: () => _selectReason(sub),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSubSelected
                            ? AppColors.positive.withValues(alpha: 0.20)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSubSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 10,
                            color: isSubSelected
                                ? AppColors.positive
                                : AppColors.textSoft,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            sub.name,
                            style: TextStyle(
                              color: isSubSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: isSubSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW 2: IN-PLACE INTERNAL TRANSFER LINKER (With Dual-SMS Auto-Dismiss)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildInternalTransferView() {
    final fmt = NumberFormat('#,##0.00');

    return Column(
      key: const ValueKey('view_internal_transfer'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header Row with Back Button
        Row(
          children: [
            AppBackButton.dark(
              onPressed: () {
                setState(() => _currentView = _QuickEditView.categories);
              },
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Link Transfer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: _dismiss,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white70,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Information banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Select counterpart transaction to match this transfer and clear both notifications.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
          ),
        ),
        const SizedBox(height: 10),

        // Candidate List
        Expanded(
          child: _loadingCandidates
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                )
              : _transferCandidates.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching transactions found.',
                        style: TextStyle(color: AppColors.textSoft, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _transferCandidates.length,
                      itemBuilder: (context, index) {
                        final item = _transferCandidates[index];
                        final cId = item['id'] as String? ?? '';
                        final cBank = item['name'] as String? ?? '';
                        final cAmt = (item['amount'] as num?)?.toDouble() ?? 0.0;
                        final cType = item['type'] as String? ?? 'expense';
                        final cDateStr = item['date'] as String? ?? '';
                        DateTime? parsedDate;
                        try {
                          parsedDate = DateTime.parse(cDateStr);
                        } catch (_) {}

                        final isSelected = _selectedCandidateId == cId;
                        final isExpense = cType == 'expense';

                        return GestureDetector(
                          onTap: () => setState(() => _selectedCandidateId = cId),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.positive.withValues(alpha: 0.16)
                                  : AppColors.drawerCard,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: (isExpense
                                            ? AppColors.warning
                                            : AppColors.positive)
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isExpense
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    color: isExpense
                                        ? AppColors.warning
                                        : AppColors.positive,
                                    size: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cBank,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (parsedDate != null)
                                        Text(
                                          DateFormat('MMM d, HH:mm')
                                              .format(parsedDate),
                                          style: const TextStyle(
                                            color: AppColors.textSoft,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${fmt.format(cAmt)} ETB',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 18,
                                  color: isSelected
                                      ? AppColors.positive
                                      : AppColors.textSoft,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        const SizedBox(height: 10),

        // Confirm / Cancel Action Row
        Row(
          children: [
            Expanded(
              child: AppButton.primary(
                text: 'Confirm Link',
                height: 44,
                isLoading: _isSaving,
                onPressed: _selectedCandidateId != null
                    ? _confirmInternalTransfer
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            AppButton.secondary(
              text: 'Cancel',
              fullWidth: false,
              height: 44,
              onPressed: () {
                setState(() => _currentView = _QuickEditView.categories);
              },
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW 3: IN-PLACE LOAN RECORD CREATOR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLoanView() {
    return Column(
      key: const ValueKey('view_loan'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header Row with Back Button
        Row(
          children: [
            AppBackButton.dark(
              onPressed: () {
                setState(() => _currentView = _QuickEditView.categories);
              },
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'New Loan Record',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: _dismiss,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white70,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              // Auto-detected Loan Type Indicator (No manual tab needed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (_loanType == 'lent'
                          ? AppColors.positive
                          : AppColors.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _loanType == 'lent'
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: _loanType == 'lent'
                          ? AppColors.positive
                          : AppColors.warning,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _loanType == 'lent'
                            ? 'Money Lent Out (Expense)'
                            : 'Money Borrowed / Debt (Income)',
                        style: TextStyle(
                          color: _loanType == 'lent'
                              ? AppColors.positive
                              : AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Person Name Field
              AppTextField.modal(
                controller: _loanPersonController,
                hint: 'Contact or Person Name...',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 12, right: 8),
                  child: Icon(Icons.person_outline_rounded,
                      color: AppColors.textSecondary, size: 16),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),

              // Amount Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.drawerCard,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Text(
                      'PRINCIPAL AMOUNT',
                      style: TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _amount.isNotEmpty ? _amount : 'ETB 0.00',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Due Date Presets
              const Text(
                'REPAYMENT DUE DATE',
                style: TextStyle(
                  color: AppColors.textSoft,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final days in [15, 30, 60, 90]) ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: AppButton.pill(
                          text: '${days}d',
                          isSelected: _loanDueDate.difference(DateTime.now()).inDays == days,
                          height: 32,
                          onPressed: () {
                            setState(() {
                              _loanDueDate = DateTime.now().add(Duration(days: days));
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Optional Note Field
              AppTextField.modal(
                controller: _loanNoteController,
                hint: 'Optional note or purpose...',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 12, right: 8),
                  child: Icon(Icons.notes_rounded,
                      color: AppColors.textSecondary, size: 16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Action Row
        Row(
          children: [
            Expanded(
              child: AppButton.primary(
                text: 'Save Loan Record',
                height: 44,
                isLoading: _isSaving,
                onPressed: _loanPersonController.text.trim().isNotEmpty
                    ? _saveLoanRecord
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            AppButton.secondary(
              text: 'Cancel',
              fullWidth: false,
              height: 44,
              onPressed: () {
                setState(() => _currentView = _QuickEditView.categories);
              },
            ),
          ],
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('food') || lower.contains('dining')) {
      return Icons.restaurant_rounded;
    } else if (lower.contains('goods') || lower.contains('shopping')) {
      return Icons.shopping_bag_outlined;
    } else if (lower.contains('bill') || lower.contains('utility')) {
      return Icons.bolt_rounded;
    } else if (lower.contains('transport') || lower.contains('travel')) {
      return Icons.directions_bus_rounded;
    } else if (lower.contains('personal') || lower.contains('transfer')) {
      return Icons.swap_horiz_rounded;
    } else if (lower.contains('health') || lower.contains('medical')) {
      return Icons.local_hospital_outlined;
    } else if (lower.contains('education')) {
      return Icons.school_outlined;
    } else if (lower.contains('entertainment')) {
      return Icons.movie_outlined;
    }
    return Icons.category_outlined;
  }
}

class _ReasonItem {
  final int id;
  final String name;
  final int? parentId;
  final bool isSpecial;

  const _ReasonItem({
    required this.id,
    required this.name,
    this.parentId,
    this.isSpecial = false,
  });
}

class _CategoryGroup {
  final _ReasonItem parent;
  final List<_ReasonItem> subcategories;

  const _CategoryGroup({
    required this.parent,
    required this.subcategories,
  });
}
