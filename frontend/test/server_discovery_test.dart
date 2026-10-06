import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
  });

  test('ApiConstants.extractErrorMessage cleans FormatException and HTML', () {
    try {
      const badBody = '<!DOCTYPE html><html><body>Error</body></html>';
      jsonDecode(badBody);
    } catch (e) {
      final message = ApiConstants.extractErrorMessage(e);
      expect(message.contains('FormatUnexpected'), isFalse);
      expect(message.contains('Unexpected character'), isFalse);
      expect(message, contains('invalid response'));
    }

    final dioHtmlError = DioException(
      requestOptions: RequestOptions(path: '/auth/login'),
      response: Response(
        requestOptions: RequestOptions(path: '/auth/login'),
        statusCode: 400,
        data: '<!DOCTYPE html><html><pre>SyntaxError</pre></html>',
      ),
    );
    expect(
      ApiConstants.extractErrorMessage(dioHtmlError),
      'Invalid request. Please check credentials or server URL.',
    );

    final dio401Error = DioException(
      requestOptions: RequestOptions(path: '/auth/login'),
      response: Response(
        requestOptions: RequestOptions(path: '/auth/login'),
        statusCode: 401,
        data: {'message': 'Invalid username or password'},
      ),
    );
    expect(
      ApiConstants.extractErrorMessage(dio401Error),
      'Invalid username or password',
    );
  });
}
