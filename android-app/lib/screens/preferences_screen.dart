import 'package:flutter/material.dart';
import '../models/shopping_decision.dart';
import '../services/api_service.dart';

/// Explicit, local single-user preference editing; no model inferred writes.
class PreferencesScreen extends StatefulWidget {
  final ShoppingDecision? decision;
  const PreferencesScreen({super.key, this.decision});
  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  Map<String, dynamic>? _profile;
  bool _busy = true;
  final Set<String> _selected = {};
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> get _items =>
      _profile == null ? [] : ShoppingDecision.rows(_profile!['items']);
  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await ApiService().preferences();
      if (mounted) {
        setState(() {
          _profile = profile;
          _selected.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '暂时无法读取长期偏好。可以返回并手动描述本轮需求，不影响基础购物功能。');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _save(List<Map<String, dynamic>> items) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await ApiService().preferences(update: {
        'expected_revision': _profile!['revision'],
        'confirmed': true,
        'items': items
      });
      if (mounted) {
        setState(() {
          _profile = profile;
          _selected.clear();
        });
      }
    } catch (_) {
      // A failed response may follow a successful save. Refresh before another edit.
      if (mounted) {
        setState(() {
          _profile = null;
          _error = '保存状态无法确认，或版本已更新。请刷新后重新确认，不会自动重发。';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete(Map<String, dynamic>? item) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(item == null ? '删除全部长期偏好？' : '删除这条长期偏好？'),
              content: const Text('只删除长期记录。已经确认应用到会话的条件仍属于该会话，需在聊天中另行撤销。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确认删除'))
              ],
            ));
    if (yes == true && mounted) {
      await _save(item == null
          ? []
          : _items.where((e) => e['id'] != item['id']).toList());
    }
  }

  String _label(Map<String, dynamic> item) {
    final c = ShoppingDecision.object(item['condition']);
    final field = {'budget': '预算', 'brand': '品牌', 'use_case': '用途'}[c['field']];
    final op =
        {'max': '不超过', 'min': '至少', 'eq': '偏好', 'ne': '排除'}[c['operator']];
    return '${item['category'] ?? '所有品类'} · $field $op ${c['value']} ${c['unit'] ?? ''} · ${c['strength'] == 'hard' ? '硬条件' : '软偏好'}';
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final existing =
        item == null ? null : ShoppingDecision.object(item['condition']);
    var field = existing?['field'] as String? ?? 'budget';
    var op = existing?['operator'] as String? ?? 'max';
    var strength = existing?['strength'] as String? ?? 'hard';
    var category = item?['category'] as String?;
    final value =
        TextEditingController(text: existing?['value'].toString() ?? '');
    String? error;
    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setLocal) => AlertDialog(
                  title: Text(item == null ? '明确添加稳定偏好' : '修改稳定偏好'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('仅保存你明确确认的常用条件，不会从对话自动推测或自动应用。'),
                    DropdownButtonFormField<String>(
                        value: field,
                        items: const [
                          DropdownMenuItem(
                              value: 'budget', child: Text('常用预算（元）')),
                          DropdownMenuItem(value: 'brand', child: Text('品牌')),
                          DropdownMenuItem(value: 'use_case', child: Text('用途'))
                        ],
                        onChanged: (v) => setLocal(() {
                              field = v!;
                              op = field == 'budget' ? 'max' : 'eq';
                              value.clear();
                            })),
                    DropdownButtonFormField<String>(
                        value: category ?? '',
                        items: const [
                          DropdownMenuItem(value: '', child: Text('所有品类')),
                          DropdownMenuItem(value: '耳机', child: Text('仅耳机')),
                          DropdownMenuItem(value: '运动鞋', child: Text('仅运动鞋')),
                          DropdownMenuItem(value: '双肩包', child: Text('仅双肩包'))
                        ],
                        onChanged: (v) =>
                            setLocal(() => category = v == '' ? null : v)),
                    DropdownButtonFormField<String>(
                        value: op,
                        items: field == 'budget'
                            ? const [
                                DropdownMenuItem(
                                    value: 'max', child: Text('预算上限')),
                                DropdownMenuItem(
                                    value: 'min', child: Text('预算下限'))
                              ]
                            : const [
                                DropdownMenuItem(
                                    value: 'eq', child: Text('偏好')),
                                DropdownMenuItem(
                                    value: 'ne', child: Text('明确排除'))
                              ],
                        onChanged: (v) => setLocal(() => op = v!)),
                    TextField(
                        controller: value,
                        maxLength: 80,
                        decoration: InputDecoration(
                            labelText:
                                field == 'budget' ? '金额（CNY）' : '明确的品牌或用途',
                            errorText: error)),
                    DropdownButtonFormField<String>(
                        value: strength,
                        items: const [
                          DropdownMenuItem(
                              value: 'hard', child: Text('必须满足：硬条件')),
                          DropdownMenuItem(
                              value: 'soft', child: Text('尽量满足：软偏好'))
                        ],
                        onChanged: (v) => setLocal(() => strength = v!)),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消')),
                    TextButton(
                        onPressed: () {
                          final text = value.text.trim();
                          final number = num.tryParse(text);
                          if (text.isEmpty ||
                              (field == 'budget' &&
                                  (number == null ||
                                      !number.isFinite ||
                                      number < 0 ||
                                      number > 1000000))) {
                            setLocal(() => error = '请输入有效条件；预算范围0至1000000元。');
                            return;
                          }
                          final condition = <String, dynamic>{
                            'field': field,
                            'operator': op,
                            'value': field == 'budget' ? number : text,
                            'strength': strength,
                            if (field == 'budget') 'unit': 'CNY'
                          };
                          Navigator.pop(context, <String, dynamic>{
                            'id': item?['id'] ??
                                'pref-${DateTime.now().microsecondsSinceEpoch}',
                            'condition': condition,
                            'category': category,
                            'confirmation_text':
                                '用户在长期偏好编辑器确认：${category ?? '所有品类'} $field $op $text $strength'
                          });
                        },
                        child: const Text('确认长期保存'))
                  ],
                )));
    // Dialog route may still animate out with its controller; let route dispose its field first.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    value.dispose();
    if (result != null && mounted) {
      await _save([..._items.where((e) => e['id'] != result['id']), result]);
    }
  }

  Future<void> _apply() async {
    final selected = _items.where((i) => _selected.contains(i['id'])).toList();
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('应用到当前会话？'),
                content: Text(
                    '${selected.map(_label).join('\n')}\n\n现有硬条件不会被覆盖；冲突会要求进一步确认。品类限定偏好只能应用到已确认的相同品类。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('确认应用'))
                ]));
    if (yes == true && mounted) {
      Navigator.pop(context, {
        'preference_ids': _selected.toList(),
        'preference_revision': _profile!['revision'],
        'confirm_preferences': true
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('长期偏好（本地单用户）'), actions: [
          IconButton(
              tooltip: '刷新',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh))
        ]),
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                const Text(
                    '长期偏好由你明确保存；会话需求和识别结果不会自动写入。当前存储为本地SQLite，不依赖Redis或PostgreSQL。'),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_error!)),
                if (_profile != null) ...[
                  Text('偏好版本 ${_profile!['revision']}'),
                  if (_items.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('尚未保存任何稳定偏好。')),
                  for (final item in _items)
                    Card(
                        child: Column(children: [
                      CheckboxListTile(
                          value: _selected.contains(item['id']),
                          onChanged: widget.decision == null
                              ? null
                              : (v) => setState(() {
                                    if (v == true) {
                                      _selected.add(item['id'] as String);
                                    } else {
                                      _selected.remove(item['id']);
                                    }
                                  }),
                          title: Text(_label(item)),
                          subtitle: Text(item['confirmation_text'] as String)),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(
                            onPressed: () => _edit(item),
                            child: const Text('修改')),
                        TextButton(
                            onPressed: () => _delete(item),
                            child: const Text('删除'))
                      ])
                    ])),
                  OutlinedButton(
                      onPressed: _items.length >= 32 ? null : () => _edit(),
                      child: const Text('添加并确认稳定偏好')),
                  if (_items.isNotEmpty)
                    TextButton(
                        onPressed: () => _delete(null),
                        child: const Text('删除全部长期偏好')),
                  if (widget.decision != null)
                    ElevatedButton(
                        onPressed: _selected.isEmpty ? null : _apply,
                        child: const Text('确认应用勾选偏好到本轮'))
                  else
                    const Text('先在聊天确认本轮需求，再从这里选择应用。'),
                ]
              ]),
      );
}
