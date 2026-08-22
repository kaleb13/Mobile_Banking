import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/scan_progress_status.dart';
import '../../widgets/app_button.dart';
import '../../widgets/custom_progress_bar.dart';

/// Represents a single discrete milestone step in data maintenance.
class MaintenanceStep {
  final String label;
  final MaintenanceStepStatus status;

  const MaintenanceStep({
    required this.label,
    this.status = MaintenanceStepStatus.pending,
  });

  MaintenanceStep copyWith({MaintenanceStepStatus? status}) => MaintenanceStep(
        label: label,
        status: status ?? this.status,
      );
}

enum MaintenanceStepStatus { pending, running, done, error }

/// Controller to drive step transitions, progress updates, and results
/// from the caller in an MVVM-compliant manner.
class MaintenanceProgressController extends ChangeNotifier {
  List<MaintenanceStep> _steps = [];
  double _progress = 0.0;
  String _statusText = '';
  bool _isComplete = false;
  ScanProgressStatus? _scanStatus;

  List<MaintenanceStep> get steps => _steps;
  double get progress => _progress;
  String get statusText => _statusText;
  bool get isComplete => _isComplete;
  ScanProgressStatus? get scanStatus => _scanStatus;

  void setSteps(List<MaintenanceStep> steps) {
    _steps = steps;
    notifyListeners();
  }

  void updateStep(int index, MaintenanceStepStatus status) {
    if (index < _steps.length) {
      _steps[index] = _steps[index].copyWith(status: status);
      notifyListeners();
    }
  }

  void setProgress(double progress, String statusText) {
    _progress = progress.clamp(0.0, 1.0);
    _statusText = statusText;
    notifyListeners();
  }

  void setScanStatus(ScanProgressStatus status) {
    _scanStatus = status;
    _progress = status.progress.clamp(0.0, 1.0);
    _statusText = status.stage;
    notifyListeners();
  }

  void complete() {
    _isComplete = true;
    _progress = 1.0;
    _statusText = 'Completed successfully';
    notifyListeners();
  }
}

/// Static helper to launch the maintenance progress modal dialog.
/// Follows the exact same solid-surface, left-aligned typography and
/// button layout as [AppConfirmDialog] and [AppModalDialog].
Future<MaintenanceProgressController> showMaintenanceProgressDialog({
  required BuildContext context,
  required String title,
  Color accentColor = AppColors.positive,
}) async {
  final controller = MaintenanceProgressController();

  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim1, anim2, child) {
      return Stack(
        alignment: Alignment.center,
        children: [
          FadeTransition(
            opacity: anim1,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
              ),
              child: _MaintenanceProgressDialogBody(
                title: title,
                accentColor: accentColor,
                controller: controller,
              ),
            ),
          ),
        ],
      );
    },
  );

  return controller;
}

class _MaintenanceProgressDialogBody extends StatefulWidget {
  final String title;
  final Color accentColor;
  final MaintenanceProgressController controller;

  const _MaintenanceProgressDialogBody({
    required this.title,
    required this.accentColor,
    required this.controller,
  });

  @override
  State<_MaintenanceProgressDialogBody> createState() =>
      _MaintenanceProgressDialogBodyState();
}

class _MaintenanceProgressDialogBodyState
    extends State<_MaintenanceProgressDialogBody> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: AppRadius.dialogRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title (Left-aligned, exact AppConfirmDialog style)
              Text(
                widget.title,
                textAlign: TextAlign.left,
                style: AppTypography.heading2.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle / Current stage
              Text(
                ctrl.isComplete
                    ? 'All processes completed successfully'
                    : ctrl.statusText.isNotEmpty
                        ? ctrl.statusText
                        : 'Processing…',
                textAlign: TextAlign.left,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 16),

              // Standard CustomProgressBar Component (matching analysis & level screens)
              CustomProgressBar(
                progress: ctrl.progress,
                height: 8.0,
                progressColor: ctrl.isComplete
                    ? AppColors.positive
                    : widget.accentColor,
                backgroundColor: AppColors.tabBackground,
              ),

              const SizedBox(height: 12),

              // Percentage indicator
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(ctrl.progress * 100).toInt()}%',
                  style: AppTypography.caption.copyWith(
                    color: ctrl.isComplete
                        ? AppColors.positive
                        : widget.accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              if (ctrl.steps.isNotEmpty) ...[
                const SizedBox(height: 12),
                // Clean text step list with NO ICONS
                ...ctrl.steps.asMap().entries.map((e) {
                  final step = e.value;
                  final isDone = step.status == MaintenanceStepStatus.done;
                  final isRunning =
                      step.status == MaintenanceStepStatus.running;

                  Color textColor = AppColors.textSecondary;
                  if (isDone) textColor = AppColors.positive;
                  if (isRunning) textColor = AppColors.textPrimary;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Text(
                          '${e.key + 1}. ',
                          style: AppTypography.caption.copyWith(
                            color: isRunning
                                ? widget.accentColor
                                : isDone
                                    ? AppColors.positive
                                    : AppColors.textSecondary.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            step.label,
                            style: AppTypography.caption.copyWith(
                              color: textColor,
                              fontWeight: isRunning
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isDone)
                          Text(
                            'Done',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.positive,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else if (isRunning)
                          Text(
                            'Running',
                            style: AppTypography.caption.copyWith(
                              color: widget.accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 18),

              // 100% Fully Rounded Pill Button
              if (ctrl.isComplete)
                AppButton.primary(
                  text: 'Done',
                  height: 42,
                  onPressed: () => Navigator.of(context).pop(),
                )
              else
                AppButton.secondary(
                  text: 'Processing…',
                  height: 42,
                  onPressed: null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
