import 'package:flutter/material.dart';
import '../models/transaction_attachment.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

/// Reusable, system-wide Personal Note & Media Attachment Card Component.
/// Adheres strictly to:
/// - Standalone surface card with zero borders (`BorderRadius.circular(20)`).
/// - Default collapsed state with smooth expanding animation.
/// - 100% fully rounded pill action buttons & attachment chips.
/// - Media attachment management (images, PDFs, audio, receipts).
class AppNoteCard extends StatefulWidget {
  final TextEditingController controller;
  final String title;
  final String hintText;
  final List<TransactionAttachment> attachments;
  final bool isCollapsible;
  final bool initialExpanded;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final Future<void> Function(String filePath, String fileType, String? fileName)? onAttachMedia;
  final ValueChanged<TransactionAttachment>? onDeleteAttachment;
  final EdgeInsetsGeometry margin;
  final Color? accentColor;
  final Color? backgroundColor;

  const AppNoteCard({
    super.key,
    required this.controller,
    this.title = 'PERSONAL NOTE',
    this.hintText = 'Add a private note...',
    this.attachments = const [],
    this.isCollapsible = true,
    this.initialExpanded = false,
    this.onChanged,
    this.onEditingComplete,
    this.onAttachMedia,
    this.onDeleteAttachment,
    this.margin = EdgeInsets.zero,
    this.accentColor,
    this.backgroundColor,
  });

  @override
  State<AppNoteCard> createState() => _AppNoteCardState();
}

class _AppNoteCardState extends State<AppNoteCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded || !widget.isCollapsible;
  }

  Future<void> _showAttachMediaModal() async {
    final pathController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              Icons.attach_file_rounded,
              color: widget.accentColor ?? AppColors.positive,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Attach Media / Receipt',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: pathController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Enter local file path or URL...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          AppButton.secondary(
            text: 'Cancel',
            fullWidth: false,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: () => Navigator.pop(ctx),
          ),
          const SizedBox(width: 8),
          AppButton.primary(
            text: 'Attach',
            fullWidth: false,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: () => Navigator.pop(ctx, pathController.text.trim()),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && widget.onAttachMedia != null) {
      final ext = result.toLowerCase();
      String type = 'image';
      if (ext.endsWith('.pdf')) {
        type = 'pdf';
      } else if (ext.endsWith('.mp3') || ext.endsWith('.wav') || ext.endsWith('.m4a')) {
        type = 'audio';
      }

      final fileName = result.contains('/') ? result.split('/').last : result.split('\\').last;
      await widget.onAttachMedia!(result, type, fileName);
      if (mounted) {
        setState(() {
          _isExpanded = true;
        });
      }
    }
  }

  IconData _getAttachmentIcon(String fileType) {
    if (fileType == 'pdf') return Icons.picture_as_pdf_rounded;
    if (fileType == 'audio') return Icons.audiotrack_rounded;
    return Icons.image_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppColors.positive;
    final cardBg = widget.backgroundColor ?? Colors.white.withValues(alpha: 0.05);

    final bool hasContent = widget.controller.text.trim().isNotEmpty || widget.attachments.isNotEmpty;

    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          onTap: widget.isCollapsible
              ? () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Row
                Row(
                  children: [
                    Icon(Icons.note_alt_outlined, color: accent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.3,
                              ),
                            ),
                          ),
                          if (!_isExpanded && hasContent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                widget.attachments.isNotEmpty
                                    ? '${widget.attachments.length} attached'
                                    : 'Added',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (widget.onAttachMedia != null) ...[
                      AppButton.secondary(
                        text: 'Attach Media',
                        icon: Icons.attach_file_rounded,
                        fullWidth: false,
                        height: 28,
                        fontSize: 11,
                        iconSize: 13,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        onPressed: _showAttachMediaModal,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (widget.isCollapsible)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),

                // Expanded Content
                if (!widget.isCollapsible) ...[
                  const SizedBox(height: 12),
                  Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                  const SizedBox(height: 12),
                  _buildContent(accent),
                ] else ...[
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity, height: 0),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                        const SizedBox(height: 12),
                        _buildContent(accent),
                      ],
                    ),
                    crossFadeState: _isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 280),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: widget.onChanged,
          onEditingComplete: () {
            FocusScope.of(context).unfocus();
            widget.onEditingComplete?.call();
          },
        ),
        if (widget.attachments.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'ATTACHMENTS',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.attachments.map((att) {
              final attIcon = _getAttachmentIcon(att.fileType);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(attIcon, color: accent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      att.fileName ?? att.fileType.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    if (widget.onDeleteAttachment != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => widget.onDeleteAttachment!(att),
                        child: const Icon(Icons.close_rounded, color: Colors.white38, size: 14),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
