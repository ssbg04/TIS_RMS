import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/document_model.dart';
import '../../domain/repositories/document_repository.dart';
import 'archives_provider.dart';
import 'document_provider.dart';

final conversionProvider =
    StateNotifierProvider<ConversionNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(documentRepositoryProvider);
  return ConversionNotifier(repository, ref);
});

class ConversionNotifier extends StateNotifier<AsyncValue<void>> {
  final DocumentRepository _repository;
  final Ref _ref;
  int? _convertingDocId;

  ConversionNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  int? get convertingDocId => _convertingDocId;
  bool isConverting(int docId) =>
      state.isLoading && _convertingDocId == docId;

  Future<DocumentModel> convertToPdf(int documentId) async {
    _convertingDocId = documentId;
    state = const AsyncValue.loading();

    try {
      final convertedDoc = await _repository.convertExcelToPdf(documentId);

      // Invalidate relevant providers to automatically refresh lists
      _ref.invalidate(documentPageProvider);
      _ref.invalidate(studentFoldersProvider);
      _ref.invalidate(archiveDocumentPageProvider);
      _ref.invalidate(archiveStudentFoldersProvider);

      state = const AsyncValue.data(null);
      return convertedDoc;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    } finally {
      _convertingDocId = null;
    }
  }
}
