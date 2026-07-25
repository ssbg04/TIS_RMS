import re

with open('lib/ui/screens/documents/widgets/upload_ocr_modal.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update constructor
content = content.replace(
    '  final List<File>? preloadedFiles;\n\n  const UploadOcrModal({super.key, this.prefilledStudentId, this.preloadedFiles});',
    '  final List<File>? preloadedFiles;\n  final ValueNotifier<int>? stepNotifier;\n\n  const UploadOcrModal({super.key, this.prefilledStudentId, this.preloadedFiles, this.stepNotifier});'
)

# 2. Update show method
show_old = '''  static void show(
    BuildContext context, {
    int? prefilledStudentId,
    List<File>? preloadedFiles,
  }) {
    WoltModalSheet.show<void>(
      context: context,
      useSafeArea: false,
      pageListBuilder: (modalSheetContext) {
        return [
          WoltModalSheetPage(
            backgroundColor: AppColors.surfaceWhite,
            hasSabGradient: false,
            hasTopBarLayer: true,
            isTopBarLayerAlwaysVisible: true,
            child: UploadOcrModal(
              prefilledStudentId: prefilledStudentId,
              preloadedFiles: preloadedFiles,
            ),
          ),
        ];
      },
    );
  }'''

show_new = '''  static void show(
    BuildContext context, {
    int? prefilledStudentId,
    List<File>? preloadedFiles,
  }) {
    final stepNotifier = ValueNotifier<int>(preloadedFiles != null && preloadedFiles.isNotEmpty ? 1 : 0);
    
    WoltModalSheet.show<void>(
      context: context,
      useSafeArea: false,
      pageListBuilder: (modalSheetContext) {
        return [
          WoltModalSheetPage(
            backgroundColor: AppColors.surfaceWhite,
            hasSabGradient: false,
            hasTopBarLayer: true,
            isTopBarLayerAlwaysVisible: true,
            navBarHeight: 120, // Enough height for header and stepper
            topBarTitle: ValueListenableBuilder<int>(
              valueListenable: stepNotifier,
              builder: (ctx, step, _) => _UploadModalHeaderWidget(step: step),
            ),
            child: UploadOcrModal(
              prefilledStudentId: prefilledStudentId,
              preloadedFiles: preloadedFiles,
              stepNotifier: stepNotifier,
            ),
          ),
        ];
      },
    );
  }'''
content = content.replace(show_old, show_new)

# 3. sync _currentStep
content = content.replace(
    '    if (widget.preloadedFiles != null && widget.preloadedFiles!.isNotEmpty) {\n',
    '    if (widget.preloadedFiles != null && widget.preloadedFiles!.isNotEmpty) {\n'
)
content = content.replace(
    '      _currentStep = 1; // Jump to review step\n',
    '      _currentStep = 1; // Jump to review step\n      widget.stepNotifier?.value = 1;\n'
)

content = content.replace(
    'setState(() => _currentStep = 1);',
    'setState(() { _currentStep = 1; widget.stepNotifier?.value = 1; });'
)

content = content.replace(
    'setState(() => _currentStep = 0);',
    'setState(() { _currentStep = 0; widget.stepNotifier?.value = 0; });'
)

# 4. Remove Header and Stepper from build method
build_old = '''          // -- Header --
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.cloud_upload_rounded,
                  color: AppColors.primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Upload Documents',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (Platform.isWindows)
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
            ],
          ),
          const SizedBox(height: 4),

          // Step chips
          Row(
            children: [
              _buildStepChip(1, 'Select Files', _currentStep >= 0),
              _buildStepConnector(_currentStep >= 1),
              _buildStepChip(2, 'Review & Upload', _currentStep >= 1),
            ],
          ),
          const Divider(height: 20),'''

content = content.replace(build_old, '')

# 5. Remove _buildStepChip and _buildStepConnector from _UploadOcrModalState and append _UploadModalHeaderWidget
content = re.sub(r'  Widget _buildStepChip.*?}\n\n  Widget _buildStepConnector.*?}\n', '', content, flags=re.DOTALL)

append_code = '''
class _UploadModalHeaderWidget extends StatelessWidget {
  final int step;
  
  const _UploadModalHeaderWidget({required this.step});

  Widget _buildStepChip(int stepNum, String label, bool active) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.primaryGreen : Colors.grey.shade300,
          ),
          child: Center(
            child: Text(
              '',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? AppColors.primaryGreen : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 28,
        height: 2,
        color: active ? AppColors.primaryGreen : Colors.grey.shade300,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cloud_upload_rounded,
                color: AppColors.primaryGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Upload Documents',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (Platform.isWindows)
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildStepChip(1, 'Select Files', step >= 0),
            _buildStepConnector(step >= 1),
            _buildStepChip(2, 'Review & Upload', step >= 1),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
'''
content = content.rstrip()
if content.endswith('}'):
    content = content[:-1] + append_code + '}\n'
else:
    content += append_code

with open('lib/ui/screens/documents/widgets/upload_ocr_modal.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Done refactoring upload_ocr_modal")
