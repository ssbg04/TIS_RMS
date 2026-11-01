import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/template_model.dart';
import '../../domain/repositories/template_repository.dart';

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return TemplateRepository();
});

final templatesListProvider =
    FutureProvider.autoDispose<List<DocumentTemplateModel>>((ref) async {
  final repo = ref.watch(templateRepositoryProvider);
  return repo.getTemplates();
});

final templateDetailsProvider = FutureProvider.family
    .autoDispose<DocumentTemplateModel, int>((ref, id) async {
  final repo = ref.watch(templateRepositoryProvider);
  return repo.getTemplateById(id);
});

class TemplateMutationNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<int> createTemplate({
    required String name,
    String? description,
    int? requirementId,
    bool isActive = true,
    File? file,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(templateRepositoryProvider);
      final id = await repo.createTemplate(
        name: name,
        description: description,
        requirementId: requirementId,
        isActive: isActive,
        file: file,
      );
      state = const AsyncData(null);
      ref.invalidate(templatesListProvider);
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateTemplate(
    int id, {
    String? name,
    String? description,
    int? requirementId,
    bool? isActive,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(templateRepositoryProvider);
      await repo.updateTemplate(
        id,
        name: name,
        description: description,
        requirementId: requirementId,
        isActive: isActive,
      );
      state = const AsyncData(null);
      ref.invalidate(templatesListProvider);
      ref.invalidate(templateDetailsProvider(id));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<int> uploadTemplateVersion(int templateId, File file) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(templateRepositoryProvider);
      final ver = await repo.uploadTemplateVersion(templateId, file);
      state = const AsyncData(null);
      ref.invalidate(templatesListProvider);
      ref.invalidate(templateDetailsProvider(templateId));
      return ver;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteTemplate(int id) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(templateRepositoryProvider);
      await repo.deleteTemplate(id);
      state = const AsyncData(null);
      ref.invalidate(templatesListProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<String> downloadTemplate(int templateId, String savePath) async {
    final repo = ref.read(templateRepositoryProvider);
    return repo.downloadTemplate(templateId, savePath);
  }
}

final templateMutationProvider =
    AsyncNotifierProvider<TemplateMutationNotifier, void>(
  TemplateMutationNotifier.new,
);
