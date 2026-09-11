import 'dart:convert';

/// UI projection of an already schema-checked, evidence-backed workflow.
/// No ranking, invented parameters, or price fallbacks live in the client.
class ShoppingDecision {
  final Map<String, dynamic> data;
  ShoppingDecision._(this.data);

  static Map<String, dynamic> object(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid shopping object');
    }
    return value;
  }

  static List<Map<String, dynamic>> rows(dynamic value) {
    if (value is! List) throw const FormatException('Invalid shopping list');
    return value.map(object).toList(growable: false);
  }

  static String text(dynamic value) => value?.toString() ?? '未知';
  static void _require(bool valid) {
    if (!valid) throw const FormatException('Invalid shopping decision');
  }

  factory ShoppingDecision.fromJson(Map<String, dynamic> source) {
    final data = object(jsonDecode(jsonEncode(source)));
    _require(data['version'] == 1 && data['session_id'] is String);
    _require(const [
      'ready',
      'needs_clarification',
      'conflict',
      'no_candidates',
      'unavailable'
    ].contains(data['status']));
    _require(
        data['notice'] is String && (data['notice'] as String).contains('样例'));
    final requirements = object(data['requirements']);
    _require(requirements['revision'] is int && requirements['revision'] >= 1);
    for (final c in rows(requirements['conditions'])) {
      _require(
          c['id'] is String && c['field'] is String && c['strength'] is String);
    }
    for (final p in rows(requirements['pending'])) {
      _require(p['id'] is String && object(p['source'])['quote'] is String);
    }
    final assessment = object(data['assessment']);
    _require(
        object(assessment['state'])['revision'] == requirements['revision']);
    _require(assessment['questions'] is List);
    rows(data['trace']);
    rows(data['errors']);
    final rec =
        data['recommendation'] == null ? null : object(data['recommendation']);
    final candidates =
        rec == null ? <Map<String, dynamic>>[] : rows(rec['recommendations']);
    _require(data['status'] != 'ready' || candidates.isNotEmpty);
    _require(data['status'] == 'ready' || candidates.isEmpty);
    if (rec != null) {
      _require(object(rec['catalog'])['data_kind'] == 'sample' &&
          object(rec['catalog'])['sha256'] is String);
      _require(rec['warnings'] is List);
      rows(rec['constraint_impacts']);
      final hardIds =
          rows(assessment['hard_constraints']).map((c) => c['id']).toSet();
      for (final row in candidates) {
        final p = object(row['product']);
        _require(p['data_kind'] == 'sample');
        for (final key in [
          'product_id',
          'evidence_id',
          'source_id',
          'brand',
          'model',
          'category'
        ]) {
          _require(p[key] is String);
        }
        final price = object(p['price_range']);
        _require(price['min'] is num &&
            price['max'] is num &&
            price['min'] >= 0 &&
            price['min'] <= price['max']);
        _require(row['score'] is num &&
            row['score'] >= 0 &&
            row['score'] <= 100 &&
            row['rank'] is int);
        for (final value in object(p['parameters']).values) {
          object(value);
        }
        _require(row['reasons'] is List);
        for (final key in [
          'use_cases',
          'advantages',
          'disadvantages',
          'exclusions',
          'buying_advice'
        ]) {
          _require(p[key] is List);
        }
        for (final c in rows(row['components'])) {
          _require(c['contribution'] is num);
        }
        final hard = rows(row['hard_checks']);
        _require(hard.length == hardIds.length &&
            hard.map((c) => c['condition_id']).toSet().containsAll(hardIds));
        _require(hard.every((c) => c['status'] == 'matched'));
        for (final check in [...hard, ...rows(row['soft_checks'])]) {
          _require(const ['matched', 'not_matched', 'unknown']
              .contains(check['status']));
          final evidence = rows(check['evidence']);
          _require(evidence.isNotEmpty);
          for (final e in evidence) {
            _require(e['product_id'] == p['product_id'] &&
                e['evidence_id'] == p['evidence_id'] &&
                e['source_id'] == p['source_id']);
            _require(e['locator'] is String && e['field'] is String);
          }
        }
      }
    }
    if (data['report'] != null) {
      final report = object(data['report']);
      _require(data['status'] == 'ready' &&
          report['requirements_revision'] == requirements['revision']);
      _require(report['catalog_sha256'] == object(rec!['catalog'])['sha256']);
      _require(report['limitations'] is List);
      _require(jsonEncode(report['choices']) == jsonEncode(candidates));
    }
    return ShoppingDecision._(data);
  }

  int get revision => object(data['requirements'])['revision'] as int;
  String get sessionId => data['session_id'] as String;
  String get status => data['status'] as String;
  String get notice => data['notice'] as String;
  bool get hasReport => data['report'] != null;
  List<Map<String, dynamic>> get conditions =>
      rows(object(data['requirements'])['conditions'])
          .where((c) => c['removed_turn'] == null)
          .toList();
  List<Map<String, dynamic>> get pending =>
      rows(object(data['requirements'])['pending'])
          .where((c) => c['resolved_turn'] == null)
          .toList();
  List<Map<String, dynamic>> get candidates => data['recommendation'] == null
      ? []
      : rows(object(data['recommendation'])['recommendations']);
  List<String> get questions =>
      (object(data['assessment'])['questions'] as List).map(text).toList();
  List<String> get warnings => data['recommendation'] == null
      ? []
      : (object(data['recommendation'])['warnings'] as List).map(text).toList();
  String get statusLabel => const {
        'ready': '推荐已核验',
        'needs_clarification': '需要补充信息',
        'conflict': '条件存在冲突',
        'no_candidates': '没有满足全部硬条件的样例',
        'unavailable': '商品知识暂时不可用'
      }[status]!;

  String conditionLabel(Map<String, dynamic> c) {
    final field = const {
          'budget': '预算',
          'category': '品类',
          'brand': '品牌',
          'use_case': '用途',
          'feature': '功能',
          'parameter': '参数'
        }[c['field']] ??
        text(c['field']);
    final operator = const {
          'eq': '=',
          'ne': '≠',
          'min': '≥',
          'max': '≤'
        }[c['operator']] ??
        text(c['operator']);
    final value = c['value'] is bool
        ? (c['value'] == true ? '是' : '否')
        : text(c['value']);
    final key = c['key'] == null ? '' : ' ${c['key']}';
    return '$field$key $operator $value ${c['unit'] ?? ''} · ${c['strength'] == 'hard' ? '硬条件' : '软偏好'}';
  }

  String labelForId(dynamic id) {
    for (final c in conditions) {
      if (c['id'] == id) return conditionLabel(c);
    }
    return text(id);
  }

  String get reportText {
    if (!hasReport) throw StateError('No verified report');
    final report = object(data['report']);
    final out = StringBuffer(
        '样例商品购物决策报告\n$notice\n需求版本：$revision\n目录SHA-256：${report['catalog_sha256']}\n');
    for (final c in conditions) {
      out.writeln('条件 ${c['id']}：${conditionLabel(c)}');
    }
    for (final row in candidates) {
      final p = object(row['product']);
      final price = object(p['price_range']);
      out.writeln(
          '\n${row['rank']}. ${p['brand']} ${p['model']} [${p['product_id']}]\n样例价格区间：¥${price['min']}–${price['max']}；偏好分数：${row['score']}/100\n证据：${p['evidence_id']}；来源：${p['source_id']}');
      for (final entry in object(p['parameters']).entries) {
        out.writeln('参数 ${entry.key}：${jsonEncode(entry.value)}');
      }
      for (final key in [
        'advantages',
        'disadvantages',
        'exclusions',
        'buying_advice'
      ]) {
        out.writeln('$key：${(p[key] as List).join('；')}');
      }
      for (final part in rows(row['components'])) {
        out.writeln(
            '评分 ${part['dimension']}：匹配${part['matched_preferences']}/${part['unique_preferences']}，权重${part['weight']}，贡献${part['contribution']}');
      }
      for (final c in [
        ...rows(row['hard_checks']),
        ...rows(row['soft_checks'])
      ]) {
        out.writeln(
            '${labelForId(c['condition_id'])}：${c['status']}；${c['reason']}');
        for (final e in rows(c['evidence'])) {
          out.writeln(
              '  ${e['evidence_id']} ${e['locator']} = ${jsonEncode(e['value'])}');
        }
      }
    }
    out.writeln('\n限制：${(report['limitations'] as List).join('；')}');
    return out.toString();
  }
}
