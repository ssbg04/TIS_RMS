import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

class LoginLog {
  final int id;
  final int userId;
  final String username;
  final String fullName;
  final String role;
  final String platform;
  final String? ipAddress;
  final String loginAt;
  final String? logoutAt;

  const LoginLog({
    required this.id,
    required this.userId,
    required this.username,
    required this.fullName,
    required this.role,
    required this.platform,
    this.ipAddress,
    required this.loginAt,
    this.logoutAt,
  });

  bool get isActive => logoutAt == null || logoutAt!.isEmpty;

  factory LoginLog.fromJson(Map<String, dynamic> json) {
    return LoginLog(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      platform: json['platform']?.toString() ?? 'unknown',
      ipAddress: json['ip_address']?.toString(),
      loginAt: json['login_at']?.toString() ?? '',
      logoutAt: json['logout_at']?.toString(),
    );
  }
}

class PaginatedLoginLogs {
  final int total;
  final int page;
  final int limit;
  final List<LoginLog> logs;

  const PaginatedLoginLogs({
    required this.total,
    required this.page,
    required this.limit,
    required this.logs,
  });

  int get totalPages => (total / limit).ceil().clamp(1, 9999);
}

class LoginSessionsQueryParams {
  final int page;
  final int limit;
  final String search;
  final String dateFrom;
  final String dateTo;

  const LoginSessionsQueryParams({
    this.page = 1,
    this.limit = 20,
    this.search = '',
    this.dateFrom = '',
    this.dateTo = '',
  });

  LoginSessionsQueryParams copyWith({
    int? page,
    int? limit,
    String? search,
    String? dateFrom,
    String? dateTo,
  }) {
    return LoginSessionsQueryParams(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      search: search ?? this.search,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
    );
  }
}

final loginSessionsQueryProvider =
    NotifierProvider.autoDispose<
      LoginSessionsQueryNotifier,
      LoginSessionsQueryParams
    >(LoginSessionsQueryNotifier.new);

class LoginSessionsQueryNotifier
    extends AutoDisposeNotifier<LoginSessionsQueryParams> {
  @override
  LoginSessionsQueryParams build() => const LoginSessionsQueryParams();

  void setPage(int page) => state = state.copyWith(page: page);
  void setLimit(int limit) => state = state.copyWith(limit: limit, page: 1);
  void setSearch(String v) => state = state.copyWith(search: v, page: 1);
  void setDateFrom(String v) => state = state.copyWith(dateFrom: v, page: 1);
  void setDateTo(String v) => state = state.copyWith(dateTo: v, page: 1);
  void reset() => state = const LoginSessionsQueryParams();
}

final loginSessionsPageProvider =
    FutureProvider.autoDispose<PaginatedLoginLogs>((ref) async {
      final query = ref.watch(loginSessionsQueryProvider);
      final repo = ref.read(authRepositoryProvider);
      final res = await repo.getLoginLogs(
        page: query.page,
        limit: query.limit,
        search: query.search.isEmpty ? null : query.search,
        dateFrom: query.dateFrom.isEmpty ? null : query.dateFrom,
        dateTo: query.dateTo.isEmpty ? null : query.dateTo,
      );

      final total = res['total'] as int? ?? 0;
      final page = res['page'] as int? ?? 1;
      final limit = res['limit'] as int? ?? 20;
      final rawLogs = (res['logs'] as List?) ?? [];
      final logs = rawLogs
          .map((e) => LoginLog.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      return PaginatedLoginLogs(
        total: total,
        page: page,
        limit: limit,
        logs: logs,
      );
    });
