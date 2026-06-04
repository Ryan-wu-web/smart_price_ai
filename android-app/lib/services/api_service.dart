import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/recognition_result.dart';
import '../utils/constants.dart';
import '../utils/error_messages.dart';
import '../utils/network_checker.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String _baseUrl = Constants.apiBaseUrl;

  Future<RecognitionResult?> recognize(File image) async {
    if (!await NetworkChecker.isOnline()) {
      throw ApiException(ErrorMessages.noInternet);
    }
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/recognize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_base64': base64Image}),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic> || data['category'] == null) {
          throw ApiException('Invalid server response');
        }
        return RecognitionResult.fromJson(data);
      } else {
        throw ApiException('识别失败: ${response.statusCode}');
      }
    } on TimeoutException catch (_) {
      throw ApiException(ErrorMessages.timeout);
    }
  }

  Future<Map<String, dynamic>?> recognizeMultiple(File image) async {
    if (!await NetworkChecker.isOnline()) {
      throw ApiException(ErrorMessages.noInternet);
    }
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/recognize/multi'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_base64': base64Image}),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic>) {
          throw ApiException('Invalid server response');
        }
        return data;
      } else {
        throw ApiException('多目标识别失败: ${response.statusCode}');
      }
    } on TimeoutException catch (_) {
      throw ApiException(ErrorMessages.timeout);
    }
  }

  Future<List<Product>> getSuggestions(
    String category, {
    String? brand,
    String? color,
  }) async {
    if (!await NetworkChecker.isOnline()) {
      throw ApiException(ErrorMessages.noInternet);
    }
    final queryParams = <String, String>{'category': category};
    if (brand != null) queryParams['brand'] = brand;
    if (color != null) queryParams['color'] = color;

    final uri = Uri.parse('$_baseUrl/api/v1/suggest')
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic>) {
          throw ApiException('Invalid server response');
        }
        final list = data['products'] ?? data['data'] ?? [];
        return (list as List<dynamic>)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException('获取建议失败: ${response.statusCode}');
      }
    } on TimeoutException catch (_) {
      throw ApiException(ErrorMessages.timeout);
    }
  }

  Future<List<Product>> compare(
    String category, {
    String? brand,
    String? color,
    String? sortBy,
    String? filterMode,
  }) async {
    if (!await NetworkChecker.isOnline()) {
      throw ApiException(ErrorMessages.noInternet);
    }
    final queryParams = <String, String>{'category': category};
    if (brand != null) queryParams['brand'] = brand;
    if (color != null) queryParams['color'] = color;
    if (sortBy != null) queryParams['sort_by'] = sortBy;
    if (filterMode != null) queryParams['filter_mode'] = filterMode;

    final uri = Uri.parse('$_baseUrl/api/v1/compare')
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic>) {
          throw ApiException('Invalid server response');
        }
        final list = data['products'] ?? data['data'] ?? [];
        return (list as List<dynamic>)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException('比价失败: ${response.statusCode}');
      }
    } on TimeoutException catch (_) {
      throw ApiException(ErrorMessages.timeout);
    }
  }

  Future<List<Product>> sendFilter(String query) async {
    if (!await NetworkChecker.isOnline()) {
      throw ApiException(ErrorMessages.noInternet);
    }
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/filter'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query_text': query}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic>) {
          throw ApiException('Invalid server response');
        }
        final list = data['products'] ?? data['data'] ?? [];
        return (list as List<dynamic>)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException('筛选失败: ${response.statusCode}');
      }
    } on TimeoutException catch (_) {
      throw ApiException(ErrorMessages.timeout);
    }
  }

  Future<Map<String, dynamic>?> getTrend(String productId) async {
    if (!await NetworkChecker.isOnline()) {
      throw ApiException(ErrorMessages.noInternet);
    }
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/v1/trend/$productId'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException('获取价格走势失败: ${response.statusCode}');
      }
    } on TimeoutException catch (_) {
      throw ApiException(ErrorMessages.timeout);
    }
  }

  Future<Map<String, dynamic>?> generateReport({
    required String productName,
    required Map<String, dynamic> bestChoice,
    List<Map<String, dynamic>>? alternatives,
  }) async {
    if (!await NetworkChecker.isOnline()) {
      throw ApiException(ErrorMessages.noInternet);
    }
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'product_name': productName,
          'best_choice': bestChoice,
          'alternatives': alternatives ?? [],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException('生成报告失败: ${response.statusCode}');
      }
    } on TimeoutException catch (_) {
      throw ApiException(ErrorMessages.timeout);
    }
  }

  Future<Map<String, dynamic>?> sendChat(
    String message, {
    String? sessionId,
    Map<String, dynamic>? currentProduct,
  }) async {
    if (!await NetworkChecker.isOnline()) {
      throw ApiException(ErrorMessages.noInternet);
    }
    final body = <String, dynamic>{
      'message': message,
    };
    if (sessionId != null) {
      body['session_id'] = sessionId;
    }
    if (currentProduct != null) {
      body['current_product'] = currentProduct;
    }

    // 聊天接口：60秒超时 + 1次重试
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/api/v1/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } else {
          throw ApiException('发送消息失败: ${response.statusCode}');
        }
      } on TimeoutException catch (_) {
        if (attempt == 2) {
          throw ApiException(ErrorMessages.timeout);
        }
        // 重试前等待 1 秒
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }

  /// SSE 流式聊天：逐字返回 AI 回复
  Future<void> sendChatStream(
    String message, {
    String? sessionId,
    Map<String, dynamic>? currentProduct,
    required void Function(String chunk) onChunk,
    required void Function(Map<String, dynamic> finalData) onDone,
    required void Function(String error) onError,
  }) async {
    if (!await NetworkChecker.isOnline()) {
      onError(ErrorMessages.noInternet);
      return;
    }

    final body = <String, dynamic>{'message': message};
    if (sessionId != null) body['session_id'] = sessionId;
    if (currentProduct != null) body['current_product'] = currentProduct;

    try {
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/api/v1/chat/stream'),
      )
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);

      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode == 200) {
        await for (final line in streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            final jsonData = jsonDecode(data) as Map<String, dynamic>;
            if (jsonData['done'] == true) {
              onDone(jsonData);
            } else {
              onChunk(jsonData['reply']?.toString() ?? '');
            }
          }
        }
      } else {
        onError('发送消息失败: ${streamedResponse.statusCode}');
      }
    } on TimeoutException catch (_) {
      onError(ErrorMessages.timeout);
    } catch (e) {
      onError('发送消息失败: $e');
    }
  }
}
