import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/entities/system_user.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository());

final usersProvider = AsyncNotifierProvider<UsersNotifier, List<SystemUser>>(() {
  return UsersNotifier();
});

class UsersNotifier extends AsyncNotifier<List<SystemUser>> {
  @override
  Future<List<SystemUser>> build() async {
    return await ref.read(userRepositoryProvider).getUsers();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(userRepositoryProvider).getUsers());
  }

  /// Returns the generated temporary password to display once.
  Future<String> createUser({
    required String username,
    String? password,
    required String firstName,
    String? middleName,
    required String lastName,
    String? extension,
    required String role,
    String? email,
    String? phone,
  }) async {
    try {
      final tempPassword = await ref.read(userRepositoryProvider).createUser(
        username: username, password: password, firstName: firstName,
        middleName: middleName, lastName: lastName, extension: extension,
        role: role, email: email, phone: phone,
      );
      await refresh();
      return tempPassword;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> updateUser({
    required int id, required String firstName, String? middleName,
    required String lastName, String? extension, required String role,
    String? email, String? phone,
  }) async {
    try {
      await ref.read(userRepositoryProvider).updateUser(
        id: id, firstName: firstName, middleName: middleName, lastName: lastName,
        extension: extension, role: role, email: email, phone: phone,
      );
      await refresh();
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> resetPassword(int id) async {
    try {
      await ref.read(userRepositoryProvider).resetPassword(id);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      await ref.read(userRepositoryProvider).deleteUser(id);
      await refresh();
      return true;
    } catch (e) {
      rethrow;
    }
  }
}
