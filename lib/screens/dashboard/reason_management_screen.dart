import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/reason.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../shell/custom_bottom_nav_bar.dart';

class ReasonManagementScreen extends StatefulWidget {
  const ReasonManagementScreen({super.key});

  @override
  State<ReasonManagementScreen> createState() => _ReasonManagementScreenState();
}

class _ReasonManagementScreenState extends State<ReasonManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().loadReasons();
    });
  }

  // ── Add / Edit reason ──────────────────────────────────────────
  void _showAddEditDialog(BuildContext context, FinanceProvider provider,
      {AppReason? existing}) {
    final ctrl = TextEditingController(text: existing?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) {
        String? errorMsg;
        return StatefulBuilder(builder: (ctx, setInner) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(existing == null ? 'New Reason' : 'Edit Reason',
                style: const TextStyle(color: AppColors.textWhite)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.textWhite),
                  onChanged: (_) {
                    if (errorMsg != null) setInner(() => errorMsg = null);
                  },
                  decoration: InputDecoration(
                    hintText: 'Reason name…',
                    hintStyle: TextStyle(
                        color: AppColors.textGray.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: AppColors.surfaceLight.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: errorMsg != null
                          ? BorderSide(
                              color: AppColors.alertRed.withValues(alpha: 0.7))
                          : BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: errorMsg != null
                          ? BorderSide(
                              color: AppColors.alertRed.withValues(alpha: 0.7))
                          : BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: errorMsg != null
                          ? const BorderSide(color: AppColors.alertRed)
                          : BorderSide(
                              color:
                                  AppColors.textWhite.withValues(alpha: 0.5)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.alertRed, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          errorMsg!,
                          style: const TextStyle(
                              color: AppColors.alertRed, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textGray)),
              ),
              TextButton(
                onPressed: () async {
                  final name = ctrl.text.trim();
                  if (name.isEmpty) return;

                  // Block if name matches a system reason (case-insensitive)
                  final conflictsSystem = provider.reasons
                      .where((r) => r.isSystem)
                      .any((r) => r.name.toLowerCase() == name.toLowerCase());
                  if (conflictsSystem) {
                    setInner(() => errorMsg =
                        '"$name" is a system reason and cannot be duplicated.');
                    return;
                  }

                  // Block duplicate custom reasons (allow same name when editing itself)
                  final conflictsUser = provider.reasons
                      .where((r) => !r.isSystem)
                      .any((r) =>
                          r.name.toLowerCase() == name.toLowerCase() &&
                          r.id != existing?.id);
                  if (conflictsUser) {
                    setInner(() => errorMsg =
                        'You already have a custom reason called "$name".');
                    return;
                  }

                  if (existing == null) {
                    await provider.addReason(name);
                  } else {
                    await provider.editReason(existing, name);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(existing == null ? 'Add' : 'Save',
                    style: const TextStyle(color: AppColors.primaryBlue)),
              ),
            ],
          );
        });
      },
    );
  }

  // ── Link dialog ─────────────────────────────────────────────────
  void _showLinkDialog(
      BuildContext context, FinanceProvider provider, AppReason reason) {
    final nameCtrl = TextEditingController();
    String linkType = 'sender';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setInner) {
          final existingLinks = provider.linksForReason(reason.id!);
          return Dialog(
            alignment: Alignment.topCenter,
            backgroundColor: AppColors.surfaceDark,
            insetPadding:
                const EdgeInsets.only(top: 80, left: 16, right: 16, bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Links for "${reason.name}"',
                            style: const TextStyle(
                                color: AppColors.textWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close,
                            color: AppColors.textGray, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Existing links
                  if (existingLinks.isNotEmpty) ...[
                    const Text('Current links',
                        style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...existingLinks.map((link) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                link.linkType == 'sender'
                                    ? Icons.upload_outlined
                                    : Icons.download_outlined,
                                color:
                                    AppColors.textWhite.withValues(alpha: 0.5),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${link.linkType == 'sender' ? 'Sender' : 'Receiver'}: ${link.linkedName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppColors.textWhite, fontSize: 13),
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  await provider.deleteReasonLink(link.id!);
                                  setInner(() {});
                                },
                                child: const Icon(Icons.close,
                                    color: AppColors.alertRed, size: 18),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 16),
                  ],

                  // Add new link
                  const Text('Add new link',
                      style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Type toggle
                      GestureDetector(
                        onTap: () => setInner(() {
                          linkType =
                              linkType == 'sender' ? 'receiver' : 'sender';
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.textWhite.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    AppColors.textWhite.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            linkType == 'sender' ? '↑ Sender' : '↓ Receiver',
                            style: TextStyle(
                                color:
                                    AppColors.textWhite.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            final options = provider.transactions
                                .map((t) => t.sender)
                                .toSet()
                                .toList();
                            return options.where((String option) {
                              return option.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase());
                            });
                          },
                          onSelected: (String selection) {
                            nameCtrl.text = selection;
                          },
                          optionsViewBuilder: (ctx, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  width: MediaQuery.of(ctx).size.width * 0.5,
                                  constraints:
                                      const BoxConstraints(maxHeight: 200),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: AppColors.surfaceLight
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, i) {
                                      final option = options.elementAt(i);
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          child: Text(option,
                                              style: const TextStyle(
                                                  color: AppColors.textWhite,
                                                  fontSize: 14)),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                          fieldViewBuilder: (context, controller, focusNode,
                              onEditingComplete) {
                            // Keep the parent nameCtrl synced
                            controller.addListener(() {
                              nameCtrl.text = controller.text;
                            });
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              style: const TextStyle(
                                  color: AppColors.textWhite, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search or type name…',
                                hintStyle: TextStyle(
                                    color: AppColors.textGray
                                        .withValues(alpha: 0.6),
                                    fontSize: 13),
                                filled: true,
                                fillColor: AppColors.surfaceLight
                                    .withValues(alpha: 0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: AppColors.textWhite
                                          .withValues(alpha: 0.5)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          await provider.addReasonLink(
                            reasonId: reason.id!,
                            linkedName: name,
                            linkType: linkType,
                          );
                          nameCtrl.clear();
                          setInner(() {});
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.textWhite.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.add,
                              color: AppColors.textWhite.withValues(alpha: 0.9),
                              size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final systemReasons = provider.reasons.where((r) => r.isSystem).toList();
    final userReasons = provider.reasons.where((r) => !r.isSystem).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1F1F25),
        extendBody: true,
        bottomNavigationBar: DynamicNavBarWrapper(
          currentIndex: 4, // Assuming it's opened from Settings (index 4)
          onTap: (_) {},
          isDynamic: true,
          heroTag: 'navbar_reason_management',
          dynamicActionLabel: 'Add Reason',
          dynamicActionIcon: Icons.add,
          onDynamicAdd: () => _showAddEditDialog(context, provider),
          onDynamicBack: () => Navigator.pop(context),
        ),
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(
                left: 20, right: 20, top: 16, bottom: 120),
            children: [
              // ── Header ───────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reason Management',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3)),
                    Text(
                      'Manage transaction reasons and bank links',
                      style:
                          TextStyle(color: AppColors.labelGray, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // ── System Reasons ───────────────────────────────────
              _sectionHeader('System Reasons', Icons.verified_outlined,
                  AppColors.textWhite),
              const SizedBox(height: 10),
              ...systemReasons.map((r) => _ReasonTile(
                    reason: r,
                    onLinkTap: () => _showLinkDialog(context, provider, r),
                    provider: provider,
                  )),

              const SizedBox(height: 24),

              // ── User Reasons ─────────────────────────────────────
              _sectionHeader(
                  'My Reasons', Icons.person_outline, AppColors.textWhite),
              const SizedBox(height: 10),
              if (userReasons.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Text('No custom reasons yet. Tap + to add one.',
                      style: TextStyle(
                          color: AppColors.textGray.withValues(alpha: 0.7),
                          fontSize: 13)),
                ),
              ...userReasons.map((r) => _ReasonTile(
                    reason: r,
                    onLinkTap: () => _showLinkDialog(context, provider, r),
                    provider: provider,
                    onEditTap: () =>
                        _showAddEditDialog(context, provider, existing: r),
                    onDeleteTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surfaceDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          title: const Text('Delete Reason?',
                              style: TextStyle(color: AppColors.textWhite)),
                          content: Text(
                              'Delete "${r.name}"? Any links will also be removed.',
                              style:
                                  const TextStyle(color: AppColors.textGray)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel',
                                  style: TextStyle(color: AppColors.textGray)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete',
                                  style: TextStyle(color: AppColors.alertRed)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await provider.deleteReason(r.id!);
                      }
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color.withValues(alpha: 0.5), size: 16),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
class _ReasonTile extends StatelessWidget {
  final AppReason reason;
  final FinanceProvider provider;
  final VoidCallback onLinkTap;
  final VoidCallback? onEditTap;
  final VoidCallback? onDeleteTap;

  const _ReasonTile({
    required this.reason,
    required this.provider,
    required this.onLinkTap,
    this.onEditTap,
    this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final links = provider.linksForReason(reason.id!);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (reason.isSystem)
                Icon(Icons.verified_outlined,
                    size: 14,
                    color: AppColors.textWhite.withValues(alpha: 0.7)),
              if (reason.isSystem) const SizedBox(width: 6),
              Expanded(
                child: Text(reason.name,
                    style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              // Link icon — always shown
              GestureDetector(
                onTap: onLinkTap,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.textWhite.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.link,
                      color: AppColors.textWhite.withValues(alpha: 0.9),
                      size: 16),
                ),
              ),
              if (reason.name.toLowerCase() == 'loan') ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    provider.setScreenIndex(3);
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3EB489).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              const Color(0xFF3EB489).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.handshake_outlined,
                            color: Color(0xFF3EB489), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Manage',
                          style: TextStyle(
                            color: Color(0xFF3EB489),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (!reason.isSystem) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onEditTap,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_outlined,
                        color: AppColors.textGray, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDeleteTap,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.alertRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: AppColors.alertRed, size: 16),
                  ),
                ),
              ],
            ],
          ),
          if (links.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: links.map((l) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.textWhite.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.textWhite.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        l.linkType == 'sender'
                            ? Icons.upload_outlined
                            : Icons.download_outlined,
                        size: 11,
                        color: AppColors.textWhite.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          l.linkedName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textWhite.withValues(alpha: 0.8),
                              fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
