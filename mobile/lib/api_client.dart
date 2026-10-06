import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  final String baseUrl;
  final http.Client client;
  ApiClient({
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:5080',
    ),
    http.Client? client,
  }) : client = client ?? http.Client();

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl/api$path').replace(queryParameters: query);
    final req = http.Request(method, uri);
    req.headers['Content-Type'] = 'application/json';
    if (body != null) req.body = jsonEncode(body);
    try {
      final response = await (() async => http.Response.fromStream(
        await client.send(req),
      ))().timeout(const Duration(seconds: 10));
      dynamic data;
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(utf8.decode(response.bodyBytes));
        } on FormatException {
          data = null;
        }
      }
      if (response.statusCode >= 400) {
        throw ApiException(
          data is Map && data['message'] is String
              ? data['message'] as String
              : 'Yêu cầu thất bại (${response.statusCode}). Hãy tải lại và thử lại.',
        );
      }
      return data;
    } on TimeoutException {
      throw ApiException(
        'API phản hồi quá lâu. Nội dung đã được giữ. Nếu đang lưu, hãy kiểm tra danh sách trước khi thử lại.',
      );
    } on http.ClientException {
      throw ApiException(
        'Không kết nối được API. Kiểm tra mạng và backend rồi thử lại.',
      );
    }
  }

  Future<List<Category>> categories() async {
    final data = await request('GET', '/categories') as List;
    return data
        .map((x) => Category.fromJson(x as Map<String, dynamic>))
        .toList();
  }

  void close() => client.close();
}
