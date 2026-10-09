import 'package:flutter/material.dart';
import '../../settings/requirements_settings_screen.dart';

/// RequirementsSettingsModal presents the document requirements manager.
/// It delegates to [RequirementsModal] to provide a fully responsive,
/// feature-rich requirements configuration experience on all screen sizes and platforms.
class RequirementsSettingsModal extends StatelessWidget {
  const RequirementsSettingsModal({super.key});

  /// Opens the requirements modal intelligently:
  /// - On mobile (<720px / Android), pushes a full-screen route with smooth navigation.
  /// - On desktop (>=720px), opens a centered CustomModal dialog.
  static void show(BuildContext context) {
    RequirementsModal.open(context);
  }

  @override
  Widget build(BuildContext context) {
    return const RequirementsModal();
  }
}
