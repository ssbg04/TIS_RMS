class DashboardCardConfig {
  final String id;
  final String title;
  final int colSpan; // 6 = Half Width (50%), 12 = Full Width (100%)
  final bool isVisible;

  const DashboardCardConfig({
    required this.id,
    required this.title,
    this.colSpan = 12,
    this.isVisible = true,
  });

  DashboardCardConfig copyWith({
    String? id,
    String? title,
    int? colSpan,
    bool? isVisible,
  }) {
    return DashboardCardConfig(
      id: id ?? this.id,
      title: title ?? this.title,
      colSpan: colSpan ?? this.colSpan,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'colSpan': colSpan,
        'isVisible': isVisible,
      };

  factory DashboardCardConfig.fromJson(Map<String, dynamic> json) {
    return DashboardCardConfig(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      colSpan: (json['colSpan'] as num?)?.toInt() ?? 12,
      isVisible: json['isVisible'] as bool? ?? true,
    );
  }

  /// Default cards layout for administrators with separated KPI widgets
  static List<DashboardCardConfig> defaultAdminCards() => const [
        DashboardCardConfig(
          id: 'stats',
          title: 'Key Statistics',
          colSpan: 12,
          isVisible: true,
        ),
        DashboardCardConfig(
          id: 'needs_attention',
          title: 'Needs Attention Alerts',
          colSpan: 12,
          isVisible: true,
        ),
        DashboardCardConfig(
          id: 'kpi_digitalization',
          title: 'Digitalization Progress',
          colSpan: 6,
          isVisible: true,
        ),
        DashboardCardConfig(
          id: 'kpi_status',
          title: 'Status Distribution',
          colSpan: 6,
          isVisible: true,
        ),
        DashboardCardConfig(
          id: 'kpi_doc_types',
          title: 'Document Type Breakdown',
          colSpan: 12,
          isVisible: true,
        ),
        DashboardCardConfig(
          id: 'kpi_upload_trend',
          title: 'Upload Trends',
          colSpan: 6,
          isVisible: true,
        ),
        DashboardCardConfig(
          id: 'kpi_storage',
          title: 'Storage Analytics',
          colSpan: 6,
          isVisible: true,
        ),
        DashboardCardConfig(
          id: 'recent_activity',
          title: 'Recent Activity Feed',
          colSpan: 12,
          isVisible: true,
        ),
      ];

  /// Default cards layout for teachers
  static List<DashboardCardConfig> defaultTeacherCards() => const [
        DashboardCardConfig(
          id: 'stats',
          title: 'Key Statistics',
          colSpan: 12,
          isVisible: true,
        ),
        DashboardCardConfig(
          id: 'needs_attention',
          title: 'Needs Attention Alerts',
          colSpan: 12,
          isVisible: true,
        ),
        DashboardCardConfig(
          id: 'recent_activity',
          title: 'Recent Activity Feed',
          colSpan: 12,
          isVisible: true,
        ),
      ];
}
