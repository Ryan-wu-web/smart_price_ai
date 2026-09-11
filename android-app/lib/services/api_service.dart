import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'chat_stream_decoder.dart';
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

/// Per-screen cancellation, never shared by the singleton API service.
class ChatStreamCancellation {
  bool _cancelled = false;
  void Function()? _close;

  void cancel() {
    _cancelled = true;
    _close?.call();
  }
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
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/recognize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'image_base64': base64Image}),
          )
          .timeout(const Duration(seconds: 120));

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
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/recognize/multi'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'image_base64': base64Image}),
          )
          .timeout(const Duration(seconds: 120));

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
    if (brand != null && brand.trim().isNotEmpty) queryParams['brand'] = brand;
    if (color != null && color.trim().isNotEmpty) queryParams['color'] = color;

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
    if (brand != null && brand.trim().isNotEmpty) queryParams['brand'] = brand;
    if (color != null && color.trim().isNotEmpty) queryParams['color'] = color;
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
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/filter'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query_text': query}),
          )
          .timeout(const Duration(seconds: 30));

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
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/report'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'product_name': productName,
              'best_choice': bestChoice,
              'alternatives': alternatives ?? [],
            }),
          )
          .timeout(const Duration(seconds: 30));

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
    Map<String, dynamic>? shopping,
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

    if (shopping != null) body['shopping'] = shopping;

    // A timeout does not prove the server failed to save the turn. Do not replay POSTs.
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiException(_chatError(response.statusCode));
    } on TimeoutException {
      throw ApiException('等待回复超时，请稍后查看或手动重试；不会自动重复发送。');
    }
  }

  static String _chatError(int statusCode) {
    switch (statusCode) {
      case 409:
        return '会话忙碌、需求版本已更新或历史无法读取。请先刷新会话再操作；原历史保留。';
      case 413:
        return '会话过长，请新建对话并带上关键需求。原历史未删除。';
      case 422:
        return '消息、商品信息或会话格式无效，请检查后重试。';
      case 504:
        return '等待回复超时，请先刷新会话查看保存状态。';
      default:
        return '暂时无法完成对话，请稍后重试。';
    }
  }

  Future<Map<String, dynamic>> preferences(
      {Map<String, dynamic>? update}) async {
    final client = http.Client();
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/preferences');
      final response = await (update == null
              ? client.get(uri)
              : client.post(uri,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(update)))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw ApiException('长期偏好暂时不可用，或版本已更新。请刷新后重新确认。');
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> ||
          data['revision'] is! int ||
          data['items'] is! List) {
        throw const FormatException('Invalid preferences');
      }
      return data;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> readShoppingSession(String sessionId) async {
    final client = http.Client();
    try {
      final response = await client
          .get(Uri.parse(
              '$_baseUrl/api/v1/chat/sessions/${Uri.encodeComponent(sessionId)}'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw ApiException(response.statusCode == 404
            ? '会话不存在或尚未保存，请新建对话。'
            : _chatError(response.statusCode));
      }
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid session');
      }
      return value;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('暂时无法恢复会话，请确认后端已启动后重试。');
    } finally {
      client.close();
    }
  }

  /// SSE v1 with old-server fallback; never automatically replay a chat POST.
  Future<void> sendChatStream(
    String message, {
    String? sessionId,
    Map<String, dynamic>? currentProduct,
    Map<String, dynamic>? shopping,
    required void Function(String chunk) onChunk,
    required void Function(Map<String, dynamic> finalData) onDone,
    required void Function(String error) onError,
    void Function(Map<String, dynamic> status)? onStatus,
    ChatStreamCancellation? cancellation,
  }) async {
    if (cancellation?._cancelled == true) return;
    final client = http.Client();
    cancellation?._close = client.close;
    var notified = false;
    var totalTimedOut = false;
    final totalTimer = Timer(const Duration(seconds: 240), () {
      totalTimedOut = true;
      client.close();
    });
    void fail(String message) {
      if (!notified && cancellation?._cancelled != true) {
        notified = true;
        onError(message);
      }
    }

    try {
      if (!await NetworkChecker.isOnline()
          .timeout(const Duration(seconds: 10))) {
        fail(ErrorMessages.noInternet);
        return;
      }
      if (cancellation?._cancelled == true) return;
      final body = <String, dynamic>{'message': message};
      if (sessionId != null) body['session_id'] = sessionId;
      if (currentProduct != null) body['current_product'] = currentProduct;
      if (shopping != null) body['shopping'] = shopping;
      final request =
          http.Request('POST', Uri.parse('$_baseUrl/api/v1/chat/stream'))
            ..headers['Content-Type'] = 'application/json'
            ..headers['Accept'] = 'text/event-stream'
            ..body = jsonEncode(body);
      final response =
          await client.send(request).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        fail(_chatError(response.statusCode));
        return;
      }
      if (!(response.headers['content-type'] ?? '')
          .toLowerCase()
          .startsWith('text/event-stream')) {
        throw const FormatException('Expected event stream');
      }
      final decoder = ChatStreamDecoder();
      // Idle timeout is deliberately longer than the backend's maximum 180s turn.
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 195))) {
        if (cancellation?._cancelled == true) return;
        final data = decoder.addLine(line);
        if (data == null) continue;
        if (data['type'] == 'status') {
          onStatus?.call(data);
        } else if (data['type'] == 'delta' ||
            (!data.containsKey('type') && data['done'] != true)) {
          onChunk(data['reply'] as String);
        }
        if (decoder.ended) break;
      }
      decoder.finish();
      if (decoder.error != null) {
        fail(decoder.error!);
      } else if (!notified && cancellation?._cancelled != true) {
        if (shopping != null &&
            !(decoder.result!['action_data'] as Map<String, dynamic>)
                .containsKey('workflow')) {
          fail('后端尚未返回有据购物工作流，请确认服务端已升级。');
          return;
        }
        notified = true;
        onDone(decoder.result!);
      }
    } on TimeoutException {
      fail('等待回复超时，未能确认本轮是否保存；不会自动重发，请稍后查看。');
    } catch (_) {
      fail(totalTimedOut
          ? '等待回复超时，未能确认本轮是否保存；不会自动重发，请稍后查看。'
          : '连接中断或回复不完整，未能确认本轮是否保存；不会自动重发。');
    } finally {
      totalTimer.cancel();
      cancellation?._close = null;
      client.close();
    }
  }
}
