import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/transaction_attachment.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';
import 'app_drawer.dart';
import 'app_modal_dialog.dart';
import 'app_text_field.dart';
import 'app_toast.dart';

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

  Future<void> _showAttachMediaPicker() async {
    AppDrawer.show(
      context: context,
      builder: (sheetCtx) {
        Widget option({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap,
        }) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.pop(sheetCtx);
              onTap();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: AppRadius.cardRadius,
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.positive.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppColors.positive, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }

        return AppDrawer(
          headerCard: const AppDrawerHeaderCard(
            icon: Icons.attach_file_rounded,
            iconColor: AppColors.positive,
            title: 'Attach Media / Receipt',
            subtitle: 'Upload a picture, receipt, document, or web link',
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              option(
                icon: Icons.photo_library_rounded,
                title: 'Photo / Receipt Picture',
                subtitle: 'Upload photo from gallery or receipt snapshot',
                onTap: () => _pickFile(FileType.image),
              ),
              option(
                icon: Icons.picture_as_pdf_rounded,
                title: 'PDF / Document',
                subtitle: 'Upload PDF statement, invoice, or report',
                onTap: () => _pickFile(
                  FileType.custom,
                  allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'csv'],
                ),
              ),
              option(
                icon: Icons.folder_open_rounded,
                title: 'Browse Files',
                subtitle: 'Select any file or audio note from storage',
                onTap: () => _pickFile(FileType.any),
              ),
              option(
                icon: Icons.link_rounded,
                title: 'Web Receipt / URL Link',
                subtitle: 'Attach an online payment or invoice URL',
                onTap: _showUrlAttachDialog,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFile(FileType fileType, {List<String>? allowedExtensions}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final path = file.path;
        if (path == null || path.isEmpty) return;

        final ext = (file.extension ?? '').toLowerCase();
        String type = 'image';
        if (['pdf', 'doc', 'docx', 'txt', 'csv'].contains(ext)) {
          type = 'pdf';
        } else if (['mp3', 'wav', 'm4a', 'aac', 'ogg'].contains(ext)) {
          type = 'audio';
        } else if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic'].contains(ext)) {
          type = 'image';
        }

        if (widget.onAttachMedia != null) {
          await widget.onAttachMedia!(path, type, file.name);
          if (mounted) {
            setState(() {
              _isExpanded = true;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking attachment file: $e');
    }
  }

  Future<void> _showUrlAttachDialog() async {
    final pathController = TextEditingController();
    final result = await AppModalDialog.show<String>(
      context: context,
      builder: (ctx) => AppModalDialog(
        title: 'Attach Web Receipt Link',
        subtitle: 'Enter public or web invoice URL',
        confirmText: 'Attach',
        cancelText: 'Cancel',
        onConfirm: () {
          final path = pathController.text.trim();
          if (path.isNotEmpty) {
            Navigator.pop(ctx, path);
          }
        },
        child: AppTextField.modal(
          controller: pathController,
          autofocus: true,
          hint: 'https://...',
          borderRadius: AppRadius.cardRadiusSm,
        ),
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

      final fileName = result.contains('/') ? result.split('/').last : result;
      await widget.onAttachMedia!(result, type, fileName);
      if (mounted) {
        setState(() {
          _isExpanded = true;
        });
      }
    }
  }

  void _previewAttachment(TransactionAttachment att) {
    if (att.filePath.startsWith('http://') || att.filePath.startsWith('https://')) {
      launchUrl(Uri.parse(att.filePath), mode: LaunchMode.externalApplication);
      return;
    }

    final file = File(att.filePath);
    if (att.fileType == 'image' && file.existsSync()) {
      AppModalDialog.show(
        context: context,
        builder: (ctx) => AppModalDialog(
          title: att.fileName ?? 'Receipt Image',
          confirmText: 'Close',
          cancelText: '',
          onConfirm: () => Navigator.pop(ctx),
          child: ClipRRect(
            borderRadius: AppRadius.cardRadius,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 360),
              child: Image.file(file, fit: BoxFit.contain),
            ),
          ),
        ),
      );
    } else {
      AppToast.info(
        context,
        message: att.fileName ?? 'Attachment',
        subtitle: 'File saved at ${att.filePath}',
      );
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
    final cardBg = widget.backgroundColor ?? AppColors.surface;

    final bool hasContent = widget.controller.text.trim().isNotEmpty || widget.attachments.isNotEmpty;

    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                        onPressed: _showAttachMediaPicker,
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
        AppTextField(
          controller: widget.controller,
          hint: widget.hintText,
          maxLines: 3,
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          onChanged: widget.onChanged,
          onSubmitted: (_) {
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

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _previewAttachment(att),
                child: Container(
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
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onDeleteAttachment!(att),
                          child: const Icon(Icons.close_rounded, color: Colors.white38, size: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
