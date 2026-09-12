import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/shopping_decision.dart';
import '../utils/constants.dart';

/// Read-only evidence rendering. Changes are explicit actions owned by ChatScreen.
class ShoppingDecisionCard extends StatelessWidget {
  final ShoppingDecision decision;
  final bool editable;
  final void Function(Map<String, dynamic> condition)? onRemove;
  final void Function(Map<String, dynamic> pending)? onDismiss;
  final void Function(Map<String, dynamic> pending, String strength)?
      onChooseStrength;
  final VoidCallback? onReport;
  const ShoppingDecisionCard(
      {super.key,
      required this.decision,
      this.editable = false,
      this.onRemove,
      this.onDismiss,
      this.onChooseStrength,
      this.onReport});

  @override
  Widget build(BuildContext context) {
    final d = decision;
    final rec = d.data['recommendation'] as Map<String, dynamic>?;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.statusLabel, style: Constants.h2),
          const SizedBox(height: 6),
          Text(d.notice,
              style: Constants.caption
                  .copyWith(color: Constants.secondaryTextColor)),
          Text('需求版本 ${d.revision}${editable ? '' : ' · 历史快照／只读'}',
              style: Constants.caption),
          for (final q in d.questions)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(q)),
          for (final e in ShoppingDecision.rows(d.data['errors']))
            Text(ShoppingDecision.text(e['message']),
                style: const TextStyle(color: Constants.errorColor)),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('已确认条件（${d.conditions.length}）'),
            children: [
              for (final c in d.conditions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(d.conditionLabel(c)),
                  subtitle: Text('条件 ${c['id']}'),
                  trailing: IconButton(
                      tooltip: '确认后撤销此条件',
                      onPressed: editable && onRemove != null
                          ? () => onRemove!(c)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline)),
                ),
            ],
          ),
          for (final p in d.pending) _pendingCondition(p),
          if (d.status == 'no_candidates')
            const Text('不会自动放宽。请展开已确认条件，明确确认要撤销的条件。'),
          if (rec != null && rec['constraint_impacts'] is List)
            for (final impact
                in ShoppingDecision.rows(rec['constraint_impacts']))
              Text(
                  '${d.labelForId(impact['condition_id'])}：不满足${impact['not_matched_count']}，证据不足${impact['unknown_count']}；仅撤销此项后可用${impact['eligible_if_only_removed']}件。',
                  style: Constants.caption),
          for (final row in d.candidates) _candidate(row),
          if (d.warnings.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('数据与算法限制'),
              children: d.warnings
                  .map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(w)))
                  .toList(),
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('查看执行节点'),
            children: ShoppingDecision.rows(d.data['trace'])
                .map((n) => ListTile(
                    dense: true,
                    title: Text('${n['node']} · ${n['status']}'),
                    trailing: Text('${n['elapsed_ms']} ms')))
                .toList(),
          ),
          if (d.hasReport && onReport != null)
            OutlinedButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.description_outlined),
                label: const Text('查看／分享有据报告')),
        ]),
      ),
    );
  }

  Widget _pendingCondition(Map<String, dynamic> pending) {
    final options = ShoppingDecision.strengthOptions(pending);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        title:
            Text('待澄清：${ShoppingDecision.object(pending['source'])['quote']}'),
        subtitle: Text(options.isEmpty
            ? '这句话尚未完整理解，会阻止推荐。可明确确认忽略，再重新表述。'
            : '条件内容已识别，但尚未用于筛选或排序。请确认它有多重要。'),
        trailing: IconButton(
            tooltip: '确认忽略这句话',
            onPressed: editable && onDismiss != null
                ? () => onDismiss!(pending)
                : null,
            icon: const Icon(Icons.help_outline)),
      ),
      if (options.isNotEmpty)
        Wrap(spacing: 8, children: [
          for (final option in options)
            OutlinedButton(
              onPressed: editable && onChooseStrength != null
                  ? () =>
                      onChooseStrength!(pending, option['strength'] as String)
                  : null,
              child: Text(option['strength'] == 'hard' ? '必须满足' : '优先考虑'),
            ),
        ]),
    ]);
  }

  Widget _candidate(Map<String, dynamic> row) {
    final p = ShoppingDecision.object(row['product']);
    final price = ShoppingDecision.object(p['price_range']);
    final checks = [
      ...ShoppingDecision.rows(row['hard_checks']),
      ...ShoppingDecision.rows(row['soft_checks'])
    ];
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('${row['rank']}. ${p['brand']} ${p['model']}'),
      subtitle: Text(
          '样例价 ¥${price['min']}–${price['max']} · 偏好得分 ${row['score']}/100'),
      children: [
        Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
                '商品：${p['product_id']}\n证据：${p['evidence_id']}\n来源：${p['source_id']}')),
        for (final reason in row['reasons'] as List) _line('匹配理由', reason),
        if (ShoppingDecision.rows(row['components']).isEmpty)
          _line('排序依据', '没有软偏好，得分均为0，按商品ID稳定排序；不代表质量优劣。'),
        for (final c in ShoppingDecision.rows(row['components']))
          _line('分项 ${c['dimension']}',
              '满足${c['matched_preferences']}/${c['unique_preferences']}；未知${c['unknown_preferences']}；权重${c['weight']}；贡献${(c['contribution'] as num).toStringAsFixed(2)}分'),
        for (final entry in ShoppingDecision.object(p['parameters']).entries)
          _line('参数 ${entry.key}', _parameter(entry.value)),
        _line('适用场景', (p['use_cases'] as List).join('；')),
        _line('优点', (p['advantages'] as List).join('；')),
        _line('缺点', (p['disadvantages'] as List).join('；')),
        _line('排斥场景', (p['exclusions'] as List).join('；')),
        _line('选购建议', (p['buying_advice'] as List).join('；')),
        for (final c in checks)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('${const {
              'matched': '满足',
              'not_matched': '未满足',
              'unknown': '证据不足'
            }[c['status']]}：${decision.labelForId(c['condition_id'])}'),
            subtitle: Text(ShoppingDecision.text(c['reason'])),
            children: ShoppingDecision.rows(c['evidence'])
                .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: SelectableText(
                              '${e['evidence_id']} · ${e['field']}\n${e['locator']}\n${jsonEncode(e['value'])}')),
                    ))
                .toList(),
          ),
      ],
    );
  }

  String _parameter(dynamic value) {
    final p = ShoppingDecision.object(value);
    final fact = p['value'];
    final display = fact == null
        ? '未知'
        : fact is bool
            ? (fact ? '是' : '否')
            : '$fact';
    return '${p['label'] ?? ''} $display ${p['unit'] ?? ''}';
  }

  Widget _line(String label, dynamic value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
            alignment: Alignment.centerLeft, child: Text('$label：$value')),
      );
}
