import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/recognition_result.dart';
import '../utils/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String _baseUrl = Constants.apiBaseUrl;

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<RecognitionResult?> recognize(File image, BuildContext context) async {
    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/recognize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64Image}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return RecognitionResult.fromJson(data);
      } else {
        _showError(context, '识别失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _showError(context, '网络错误: $e');
      return null;
    }
  }

  Future<List<Product>> getSuggestions(
    String category, {
    String? brand,
    String? color,
    BuildContext? context,
  }) async {
    try {
      final queryParams = <String, String>{'category': category};
      if (brand != null) queryParams['brand'] = brand;
      if (color != null) queryParams['color'] = color;

      final uri = Uri.parse('$_baseUrl/api/v1/suggest')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['products'] ?? data['data'] ?? data ?? [];
        return (list as List<dynamic>)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        if (context != null) _showError(context, '获取建议失败: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      if (context != null) _showError(context, '网络错误: $e');
      return [];
    }
  }

  Future<List<Product>> compare(
    String category, {
    String? brand,
    String? color,
    BuildContext? context,
  }) async {
    try {
      final queryParams = <String, String>{'category': category};
      if (brand != null) queryParams['brand'] = brand;
      if (color != null) queryParams['color'] = color;

      final uri = Uri.parse('$_baseUrl/api/v1/compare')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['products'] ?? data['data'] ?? data ?? [];
        return (list as List<dynamic>)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        if (context != null) _showError(context, '比价失败: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      if (context != null) _showError(context, '网络错误: $e');
      return [];
    }
  }

  Future<List<Product>> sendFilter(String query, {BuildContext? context}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/filter'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['products'] ?? data['data'] ?? data ?? [];
        return (list as List<dynamic>)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        if (context != null) _showError(context, '筛选失败: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      if (context != null) _showError(context, '网络错误: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getTrend(String productId,
      {BuildContext? context}) async {
    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/api/v1/trend/$productId'));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        if (context != null) _showError(context, '获取价格走势失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      if (context != null) _showError(context, '网络错误: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> generateReport(String productId,
      {BuildContext? context}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'product_id': productId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        if (context != null) _showError(context, '生成报告失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      if (context != null) _showError(context, '网络错误: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> sendChat(
    String message, {
    String? sessionId,
    BuildContext? context,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'session_id': sessionId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        if (context != null) _showError(context, '发送消息失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      if (context != null) _showError(context, '网络错误: $e');
      return null;
    }
  }
}
