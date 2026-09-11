import 'dart:convert';

/// Parses blank-line-delimited SSE frames and validates the application protocol.
/// A v1 result is provisional until its matching end(success: true) arrives.
class ChatStreamDecoder {
  final List<String> _data = [];
  String? _event;
  String? _id;
  int _size = 0;
  int _seq = 0;
  bool? _typed;
  String? sessionId;
  String _text = '';
  Map<String, dynamic>? result;
  String? error;
  bool ended = false;

  Never _invalid() => throw const FormatException('Invalid chat stream');

  Map<String, dynamic>? addLine(String line) {
    _size += line.length;
    if (_size > 512000 || ended) _invalid();
    if (line.isNotEmpty) {
      if (line.startsWith(':')) return null;
      final colon = line.indexOf(':');
      final field = colon < 0 ? line : line.substring(0, colon);
      var value = colon < 0 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      switch (field) {
        case 'data':
          _data.add(value);
          break;
        case 'event':
          _event = value;
          break;
        case 'id':
          _id = value;
          break;
      }
      return null;
    }
    // Bound one frame, not cumulative protocol overhead of many tiny deltas.
    _size = 0;
    if (_data.isEmpty) {
      _event = null;
      _id = null;
      return null;
    }
    final decoded = jsonDecode(_data.join('\n'));
    _data.clear();
    if (decoded is! Map<String, dynamic>) _invalid();
    final data = decoded;
    final typed = data.containsKey('type');
    if (_typed != null && _typed != typed) _invalid();
    _typed = typed;
    if (!typed) {
      if (_event != null && _event != 'message') _invalid();
      if (data['done'] == true) {
        if (data['error'] is String) {
          error = data['error'] as String;
        } else {
          _validateResult(data);
          result = data;
        }
        ended = true;
      } else if (data['reply'] is! String) {
        _invalid();
      }
    } else {
      final type = data['type'];
      final sid = data['session_id'];
      if (data['version'] != 1 ||
          data['seq'] is! int ||
          data['seq'] != _seq + 1 ||
          sid is! String ||
          !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$').hasMatch(sid) ||
          (sessionId != null && sessionId != sid) ||
          (_event != null && _event != type) ||
          (_id != null && _id != data['seq'].toString())) {
        _invalid();
      }
      sessionId = sid;
      _seq = data['seq'] as int;
      if ((result != null || error != null) && type != 'end') _invalid();
      switch (type) {
        case 'delta':
          final reply = data['reply'];
          if (reply is! String || reply.isEmpty) _invalid();
          _text += reply;
          if (_text.length > 32000) _invalid();
          break;
        case 'status':
          if (data['node'] is! String ||
              data['message'] is! String ||
              data['status'] != 'running') _invalid();
          break;
        case 'result':
          _validateResult(data);
          if (data['done'] != true || data['reply'] != _text) _invalid();
          result = data;
          break;
        case 'error':
          if (data['error'] is! String || data['code'] is! String) _invalid();
          error = data['error'] as String;
          break;
        case 'end':
          if (data['success'] is! bool ||
              (data['success'] == true && (result == null || error != null)) ||
              (data['success'] == false && error == null)) _invalid();
          ended = true;
          break;
        default:
          _invalid();
      }
    }
    _event = null;
    _id = null;
    return data;
  }

  void _validateResult(Map<String, dynamic> data) {
    if (data['reply'] is! String ||
        (data['reply'] as String).trim().isEmpty ||
        data['session_id'] is! String ||
        !const ['none', 'report', 'trend', 'filter', 'compare']
            .contains(data['action']) ||
        data['action_data'] is! Map<String, dynamic> ||
        (data['current_product'] != null &&
            data['current_product'] is! Map<String, dynamic>)) {
      _invalid();
    }
  }

  void finish() {
    if (!ended || _data.isNotEmpty) _invalid();
  }
}
