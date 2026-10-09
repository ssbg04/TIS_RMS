import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import 'custom_modal.dart';

class ViewActivityModal extends StatefulWidget {
  final String title;
  final String description;
  final String date;
  final String? performedBy;
  final String? action;
  final Color? actionColor;
  final IconData icon;
  final String? entityType;
  final String? entityId;
  final String? rawLog;
  final Map<String, dynamic>? technicalDetails;

  const ViewActivityModal({
    super.key,
    required this.title,
    required this.description,
    required this.date,
    this.performedBy,
    this.action,
    this.actionColor,
    required this.icon,
    this.entityType,
    this.entityId,
    this.rawLog,
    this.technicalDetails,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String description,
    required String date,
    String? performedBy,
    String? action,
    Color? actionColor,
    required IconData icon,
    String? entityType,
    String? entityId,
    String? rawLog,
    Map<String, dynamic>? technicalDetails,
  }) {
    return CustomModal.show(
      context: context,
      title: 'Activity Details',
      icon: icon,
      maxWidth: 520,
      content: ViewActivityModal(
        title: title,
        description: description,
        date: date,
        performedBy: performedBy,
        action: action,
        actionColor: actionColor,
        icon: icon,
        entityType: entityType,
        entityId: entityId,
        rawLog: rawLog,
        technicalDetails: technicalDetails,
      ),
    );
  }

  @override
  State<ViewActivityModal> createState() => _ViewActivityModalState();
}

class _ViewActivityModalState extends State<ViewActivityModal> {
  bool _showTechnicalDetails = false;

  void _copyTechnicalJson() {
    final payload = {
      'action': widget.action ?? 'N/A',
      'entity_type': widget.entityType ?? 'N/A',
      'entity_id': widget.entityId ?? 'N/A',
      'performed_by': widget.performedBy ?? 'System',
      'timestamp': widget.date,
      'description': widget.description,
      'raw_log': widget.rawLog ?? widget.description,
      if (widget.technicalDetails != null) ...widget.technicalDetails!,
    };
    Clipboard.setData(ClipboardData(text: payload.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Technical activity data copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Action Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                      ),
                    ),
                    if (widget.action != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (widget.actionColor ?? AppColors.primaryGreen).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.action!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: widget.actionColor ?? AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Description Card
          Text(
            'Activity Summary',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface2 : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
            ),
            child: Text(
              widget.description,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.5,
                color: isDark ? AppColors.darkTextPrimary : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Metadata Info Rows
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.access_time_rounded, size: 16, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Timestamp',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            widget.date,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.performedBy != null) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person_rounded, size: 16, color: Colors.purple),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Action By',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              widget.performedBy!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Progressive Disclosure: Technical Information
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard.withValues(alpha: 0.6) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
              ),
            ),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() {
                      _showTechnicalDetails = !_showTechnicalDetails;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Row(
                      children: [
                        Icon(
                          Icons.terminal_rounded,
                          size: 16,
                          color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Technical Details',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade800,
                            ),
                          ),
                        ),
                        Icon(
                          _showTechnicalDetails ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showTechnicalDetails) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTechRow('Entity Type', widget.entityType ?? 'N/A', isDark),
                        if (widget.entityId != null)
                          _buildTechRow('Entity ID', '#${widget.entityId}', isDark),
                        _buildTechRow('Raw Action', widget.action ?? 'N/A', isDark),
                        _buildTechRow(
                          'Raw Description / Log',
                          widget.rawLog ?? widget.description,
                          isDark,
                          isCode: true,
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: _copyTechnicalJson,
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: const Text('Copy JSON Log', style: TextStyle(fontSize: 11.5)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechRow(String label, String value, bool isDark, {bool isCode = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isCode ? 8 : 4),
            decoration: isCode
                ? BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: isCode ? 'monospace' : null,
                color: isDark ? AppColors.darkTextPrimary : Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

