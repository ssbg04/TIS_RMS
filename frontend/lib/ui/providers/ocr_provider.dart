import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/ocr_repository.dart';
import '../../domain/entities/ocr_result_model.dart';

// 1. Provide the Repository
final ocrRepositoryProvider = Provider<OcrRepository>((ref) {
  return OcrRepository();
});

// 2. Provide the State Notifier for UI interaction
// We use AsyncNotifier so the UI can easily check .isLoading, .hasError, etc.
final ocrProvider = AsyncNotifierProvider<OcrNotifier, OcrResultModel?>(
  OcrNotifier.new,
);

class OcrNotifier extends AsyncNotifier<OcrResultModel?> {
  @override
  FutureOr<OcrResultModel?> build() {
    return null; // Initial state is null (no OCR data yet)
  }

  /// Called by the UI when a user picks a file/takes a photo
  Future<OcrResultModel?> processDocument({
    required File file,
    required String fileName,
    required String docType,
  }) async {
    state = const AsyncLoading(); // Sets UI to loading state

    try {
      final repo = ref.read(ocrRepositoryProvider);
      final result = await repo.extractOcrData(
        file: file,
        fileName: fileName,
        docType: docType,
      );
      
      state = AsyncData(result); // Success! Save the data in state.
      return result; // Return it so the UI can use it immediately

    } catch (e, st) {
      state = AsyncError(e, st); // Fails gracefully
      rethrow; // Let the UI catch it to show a SnackBar/Error message
    }
  }
  
  /// Resets the OCR state if the user cancels or closes the modal
  void reset() {
    state = const AsyncData(null);
  }
}