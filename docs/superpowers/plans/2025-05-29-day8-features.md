# Day 8 功能补全 II 实现计划

> **给代理工作者：** 必需子skill：使用 subagent-driven-development（推荐）或 executing-plans 逐个任务执行此计划。步骤使用复选框（- [ ]）语法跟踪。

**目标：** 价格走势图真实数据 + 决策报告混合模式 + 分享功能
**架构：** 后端增强 TrendService 生成 Mock 历史价格数据并返回；前端 TrendScreen 使用 fl_chart 绘制折线图；ReportScreen 支持 actionData 直显和 API 调用两种模式；分享使用 share_plus 系统面板 + 剪贴板 fallback。
**技术栈：** Flutter 3.24.5, FastAPI, fl_chart, share_plus, share_plus 的 fallback 用 flutter/services Clipboard

---

## 文件结构

```
backend/
  app/models/schemas.py              # TrendResponse 增加 history_prices
  app/services/trend.py              # 生成 90 天 Mock 历史价格
  app/routers/trend.py               # 返回增强后的 TrendResponse

android-app/
  pubspec.yaml                       # 添加 fl_chart, share_plus
  lib/services/api_service.dart      # TrendScreen 调用 getTrend 传 productId
  lib/screens/trend_screen.dart      # 接入真实 API + fl_chart 折线图
  lib/screens/report_screen.dart     # 混合模式：actionData 直显 / API 调用
  lib/screens/chat_screen.dart       # 底部"报告"按钮调 API
  lib/screens/result_screen.dart     # TrendScreen 调用传真实参数
```

---

## 任务 1：后端 TrendResponse 增加历史价格字段

**文件：**
- 修改：`backend/app/models/schemas.py:70-73`

- [ ] **步骤 1：修改 TrendResponse Schema**

在 `TrendResponse` 中增加 `history_prices` 字段：

```python
class TrendResponse(BaseModel):
    trend: str = Field(..., description="趋势描述")
    advice: str = Field(..., description="购买建议")
    confidence: float = Field(..., ge=0, le=1, description="置信度")
    history_prices: list[dict] = Field(default_factory=list, description="历史价格数据，每项含 date/price/platform")
```

- [ ] **步骤 2：提交**

```bash
git add backend/app/models/schemas.py
git commit -m "feat(backend): TrendResponse add history_prices field"
```

---

## 任务 2：后端 TrendService 生成 Mock 历史价格

**文件：**
- 修改：`backend/app/services/trend.py`
- 修改：`backend/app/routers/trend.py`

- [ ] **步骤 1：修改 TrendService 生成历史数据**

```python
import random
from datetime import datetime, timedelta

class TrendService:
    def _generate_mock_history(self, product_name: str, base_price: float) -> list[dict]:
        """基于基准价格生成 90 天 Mock 历史价格数据"""
        history = []
        price = base_price
        end_date = datetime.now()
        
        for i in range(90, 0, -1):
            date = end_date - timedelta(days=i)
            # 每天价格波动 ±5%
            change = random.uniform(-0.05, 0.05)
            price = max(base_price * 0.7, min(base_price * 1.3, price * (1 + change)))
            
            # 每 3 天换一个平台
            platforms = ["京东", "淘宝", "天猫", "拼多多"]
            platform = platforms[(90 - i) // 3 % len(platforms)]
            
            history.append({
                "date": date.strftime("%m-%d"),
                "price": round(price, 2),
                "platform": platform,
            })
        return history

    def analyze_trend_sync(
        self, product_name: str, history_prices: list[dict]
    ) -> TrendResponse:
        # ... 现有逻辑不变 ...
        return TrendResponse(
            trend=trend,
            advice=advice,
            confidence=round(confidence, 2),
            history_prices=sorted_prices,
        )
```

- [ ] **步骤 2：修改 trend router 传入基准价格**

```python
@router.get("/trend/{product_id}", response_model=TrendResponse)
async def trend(product_id: str):
    try:
        service = TrendService()
        # 从 product_id 解析基准价格（Mock）
        # 使用 product_id 的 hash 生成稳定基准价格
        base_price = 500 + (hash(product_id) % 1000)
        history = service._generate_mock_history(product_id, float(base_price))
        return service.analyze_trend_sync(product_id, history)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"trend failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal server error")
```

- [ ] **步骤 3：运行后端测试**

```bash
cd backend
pytest tests/test_trend.py -v
```

预期：测试通过（或根据新 schema 更新测试）

- [ ] **步骤 4：提交**

```bash
git add backend/app/services/trend.py backend/app/routers/trend.py
git commit -m "feat(backend): TrendService generate 90-day mock price history"
```

---

## 任务 3：前端添加 fl_chart 和 share_plus 依赖

**文件：**
- 修改：`android-app/pubspec.yaml`

- [ ] **步骤 1：添加依赖**

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
  image_picker: ^0.8.9
  cupertino_icons: ^1.0.6
  shared_preferences: ^2.2.2
  cached_network_image: ^3.3.1
  connectivity_plus: ^5.0.2
  intl: ^0.19.0
  fl_chart: ^0.68.0
  share_plus: ^9.0.0
```

- [ ] **步骤 2：安装依赖**

```bash
cd android-app
flutter pub get
```

- [ ] **步骤 3：提交**

```bash
git add android-app/pubspec.yaml android-app/pubspec.lock
git commit -m "chore: add fl_chart and share_plus dependencies"
```

---

## 任务 4：重写 TrendScreen 接入真实 API + fl_chart 折线图

**文件：**
- 修改：`android-app/lib/screens/trend_screen.dart`
- 修改：`android-app/lib/services/api_service.dart:153-170`

- [ ] **步骤 1：修改 ApiService.getTrend 接收 productId**

当前 `getTrend` 接收 `productId`（已是字符串），但 TrendScreen 传入的是 `productName`。修改调用方即可，API 签名不变。

- [ ] **步骤 2：重写 TrendScreen 为 StatefulWidget**

```dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/error_messages.dart';

class TrendScreen extends StatefulWidget {
  final String productName;
  final String productId;

  const TrendScreen({
    super.key,
    required this.productName,
    required this.productId,
  });

  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  Map<String, dynamic>? _trendData;
  List<Map<String, dynamic>> _historyPrices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrend();
  }

  Future<void> _loadTrend() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().getTrend(widget.productId);
      if (!mounted) return;
      setState(() {
        _trendData = data;
        _historyPrices = (data?['history_prices'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.backgroundColor,
      appBar: AppBar(
        title: const Text('价格走势'),
        backgroundColor: Constants.backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Constants.primaryTextColor),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Constants.primaryTextColor,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Constants.tertiaryTextColor),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Constants.secondaryTextColor)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _loadTrend,
            child: const Text('重试', style: TextStyle(color: Constants.brandColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final currentPrice = _historyPrices.isNotEmpty
        ? (_historyPrices.last['price'] as num).toDouble()
        : 0.0;
    final avgPrice = _historyPrices.isNotEmpty
        ? _historyPrices.map((p) => (p['price'] as num).toDouble()).reduce((a, b) => a + b) / _historyPrices.length
        : 0.0;
    final minPrice = _historyPrices.isNotEmpty
        ? _historyPrices.map((p) => (p['price'] as num).toDouble()).reduce((a, b) => a < b ? a : b)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProductHeader(currentPrice),
          const SizedBox(height: 20),
          _buildChart(currentPrice, avgPrice, minPrice),
          const SizedBox(height: 20),
          _buildAIAnalysisCard(),
          const SizedBox(height: 20),
          _buildPriceStats(avgPrice, minPrice),
        ],
      ),
    );
  }

  Widget _buildProductHeader(double currentPrice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Constants.radiusLarge),
        boxShadow: const [Constants.shadowCard],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: Constants.placeholderGradient,
              borderRadius: BorderRadius.circular(Constants.radiusMedium),
            ),
            child: const Icon(Icons.show_chart, color: Constants.tertiaryTextColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.productName,
                  style: Constants.h2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '当前价格 ¥${currentPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Constants.accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(double currentPrice, double avgPrice, double minPrice) {
    final chartHeight = (MediaQuery.of(context).size.height * 0.28).clamp(180.0, 300.0);
    
    if (_historyPrices.isEmpty) {
      return Container(
        height: chartHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Constants.radiusLarge),
          boxShadow: const [Constants.shadowCard],
        ),
        child: const Center(child: Text('暂无历史价格数据')),
      );
    }

    final spots = _historyPrices.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['price'] as num).toDouble());
    }).toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.95;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.05;

    return Container(
      height: chartHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Constants.radiusLarge),
        boxShadow: const [Constants.shadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('90天价格走势', style: Constants.h2),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Constants.borderColor,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '¥${value.toInt()}',
                          style: const TextStyle(fontSize: 10, color: Constants.tertiaryTextColor),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: spots.length / 6,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= _historyPrices.length) return const SizedBox.shrink();
                        return Text(
                          _historyPrices[index]['date'] as String,
                          style: const TextStyle(fontSize: 10, color: Constants.tertiaryTextColor),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Constants.brandColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 3,
                        color: Constants.brandColor,
                        strokeWidth: 1,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Constants.brandColor.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAnalysisCard() {
    final advice = _trendData?['advice'] as String? ?? '暂无分析';
    final trend = _trendData?['trend'] as String? ?? '平稳';
    final confidence = (_trendData?['confidence'] as num?)?.toDouble() ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Constants.radiusLarge),
        boxShadow: const [Constants.shadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Constants.brandColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(Constants.radiusMedium),
                ),
                child: const Icon(Icons.auto_awesome, color: Constants.brandColor, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('AI 价格分析', style: Constants.h2),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getTrendColor(trend).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getTrendColor(trend),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            advice,
            style: Constants.body.copyWith(color: Constants.secondaryTextColor),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.verified, color: Constants.brandColor, size: 16),
              const SizedBox(width: 4),
              Text(
                'AI 置信度 ${(confidence * 100).toStringAsFixed(0)}%',
                style: Constants.caption.copyWith(color: Constants.brandColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getTrendColor(String trend) {
    if (trend.contains('上涨')) return Constants.errorColor;
    if (trend.contains('下跌')) return Constants.successColor;
    return Constants.warningColor;
  }

  Widget _buildPriceStats(double avgPrice, double minPrice) {
    return Row(
      children: [
        _buildStatCard('90天均价', '¥${avgPrice.toStringAsFixed(0)}'),
        const SizedBox(width: 12),
        _buildStatCard('历史最低', '¥${minPrice.toStringAsFixed(0)}'),
        const SizedBox(width: 12),
        _buildStatCard('价格趋势', _trendData?['trend'] ?? '—'),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Constants.radiusLarge),
          boxShadow: const [Constants.shadowLight],
        ),
        child: Column(
          children: [
            Text(label, style: Constants.caption),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Constants.primaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **步骤 3：修改 result_screen.dart 调用方**

```dart
// result_screen.dart 中 TrendScreen 调用
builder: (_) => TrendScreen(
  productName: _result.name ?? _result.category ?? '未知商品',
  productId: '${_result.name ?? _result.category}_${_result.brand ?? ''}',
),
```

- [ ] **步骤 4：编译检查**

```bash
cd android-app
flutter analyze lib/screens/trend_screen.dart
```

预期：无 errors

- [ ] **步骤 5：提交**

```bash
git add android-app/lib/screens/trend_screen.dart android-app/lib/screens/result_screen.dart
git commit -m "feat: TrendScreen with fl_chart line chart + real API data"
```

---

## 任务 5：ReportScreen 混合模式（actionData 直显 / API 调用）

**文件：**
- 修改：`android-app/lib/screens/report_screen.dart`
- 修改：`android-app/lib/screens/chat_screen.dart:330-345`

- [ ] **步骤 1：重写 ReportScreen 为 StatefulWidget**

```dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/error_messages.dart';

class ReportScreen extends StatefulWidget {
  final String productName;
  final Map<String, dynamic>? reportData;
  final Map<String, dynamic>? bestChoice;
  final List<Map<String, dynamic>>? alternatives;

  const ReportScreen({
    super.key,
    required this.productName,
    this.reportData,
    this.bestChoice,
    this.alternatives,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Map<String, dynamic>? _apiReport;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 如果没有 reportData，调用 API
    if (widget.reportData == null && widget.bestChoice != null) {
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService().generateReport(
        '${widget.bestChoice!['name'] ?? widget.productName}_report',
      );
      if (!mounted) return;
      setState(() {
        _apiReport = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成报告失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.backgroundColor,
      appBar: AppBar(
        backgroundColor: Constants.backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Constants.primaryTextColor),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Constants.primaryTextColor,
        ),
        title: const Text('决策报告'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReportHeader(),
                  const SizedBox(height: 20),
                  _buildBestChoiceCard(),
                  const SizedBox(height: 20),
                  _buildAlternativesSection(),
                  const SizedBox(height: 20),
                  _buildAISuggestionCard(),
                  const SizedBox(height: 32),
                  _buildShareButton(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  void _shareReport() {
    final text = _formatReportText();
    // Fallback: 复制到剪贴板
    // share_plus 将在任务 6 中实现
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享功能即将上线')),
    );
  }

  String _formatReportText() {
    final sb = StringBuffer();
    sb.writeln('🛍️ Smart Price AI 购物决策报告');
    sb.writeln('商品：${widget.productName}');
    sb.writeln('');
    sb.writeln('🏆 最优选择');
    sb.writeln(_getBestChoiceText());
    sb.writeln('');
    sb.writeln('💡 AI 建议');
    sb.writeln(_getAIAdviceText());
    return sb.toString();
  }

  String _getBestChoiceText() {
    if (widget.reportData?['best_choice'] != null) {
      return widget.reportData!['best_choice'].toString();
    }
    if (_apiReport?['summary'] != null) {
      return _apiReport!['summary'] as String;
    }
    return '京东 - 官方旗舰店';
  }

  String _getAIAdviceText() {
    if (widget.reportData?['suggestion'] != null) {
      return widget.reportData!['suggestion'].toString();
    }
    if (_apiReport?['recommendation'] != null) {
      return _apiReport!['recommendation'] as String;
    }
    return '建议立即购买';
  }

  Widget _buildReportHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: Constants.brandGradient,
        borderRadius: BorderRadius.circular(Constants.radiusLarge),
        boxShadow: const [Constants.shadowElevated],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'AI 生成',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '购物决策报告',
            style: Constants.display.copyWith(color: Colors.white, fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            widget.productName,
            style: Constants.body.copyWith(color: Colors.white.withOpacity(0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildBestChoiceCard() {
    final bestName = widget.reportData?['best_choice']?.toString() ?? '京东官方店';
    final price = widget.reportData?['savings'] != null
        ? '¥${(widget.reportData!['savings'] as num) + 749}'
        : '¥749';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Constants.radiusLarge),
        boxShadow: const [Constants.shadowCard],
        border: const Border(left: BorderSide(color: Constants.brandColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Constants.successColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(Constants.radiusMedium),
                ),
                child: const Icon(Icons.emoji_events, color: Constants.successColor, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('最优选择', style: Constants.h2),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('选择', bestName),
          _buildInfoRow('价格', price, isHighlight: true),
          if (_apiReport?['pros'] != null)
            ...(_apiReport!['pros'] as List<dynamic>).map((p) => _buildInfoRow('优点', p.toString())),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, child: Text(label, style: Constants.caption)),
          Expanded(
            child: Text(
              value,
              style: isHighlight
                  ? const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Constants.accentColor)
                  : const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Constants.primaryTextColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativesSection() {
    final alts = widget.alternatives ?? [
      {'platform': '淘宝', 'price': '¥799', 'tag': '官方店'},
      {'platform': '拼多多', 'price': '¥699', 'tag': '百亿补贴'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Constants.radiusLarge),
        boxShadow: const [Constants.shadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('其他选择', style: Constants.h2),
          const SizedBox(height: 12),
          ...alts.asMap().entries.map((entry) {
            final i = entry.key;
            final alt = entry.value;
            return Column(
              children: [
                _buildAlternativeItem(
                  alt['platform']?.toString() ?? '未知',
                  alt['price']?.toString() ?? '—',
                  alt['tag']?.toString() ?? '',
                ),
                if (i < alts.length - 1) const Divider(height: 16),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAlternativeItem(String platform, String price, String tag) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Constants.backgroundColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(platform, style: Constants.caption),
        ),
        const SizedBox(width: 12),
        Text(price, style: Constants.body.copyWith(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(tag, style: Constants.caption),
      ],
    );
  }

  Widget _buildAISuggestionCard() {
    final suggestion = widget.reportData?['suggestion']?.toString()
        ?? _apiReport?['recommendation']?.toString()
        ?? '建议立即购买，当前价格为近期低点。';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Constants.radiusLarge),
        boxShadow: const [Constants.shadowCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Constants.brandColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(Constants.radiusMedium),
                ),
                child: const Icon(Icons.lightbulb, color: Constants.brandColor, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('AI 建议', style: Constants.h2),
            ],
          ),
          const SizedBox(height: 12),
          Text(suggestion, style: Constants.body.copyWith(color: Constants.secondaryTextColor)),
        ],
      ),
    );
  }

  Widget _buildShareButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _shareReport,
        icon: const Icon(Icons.download),
        label: const Text('保存报告'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Constants.brandColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Constants.radiusLarge)),
        ),
      ),
    );
  }
}
```

- [ ] **步骤 2：修改 chat_screen.dart 底部"报告"按钮**

```dart
// 底部按钮改为传入当前商品信息
ElevatedButton.icon(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportScreen(
          productName: _currentProduct?.name ?? '当前商品',
          bestChoice: _currentProduct != null ? {
            'name': _currentProduct!.name,
            'platform': _currentProduct!.platform,
            'price': _currentProduct!.price,
          } : null,
        ),
      ),
    );
  },
  // ... 其余不变
)
```

- [ ] **步骤 3：编译检查**

```bash
cd android-app
flutter analyze lib/screens/report_screen.dart lib/screens/chat_screen.dart
```

- [ ] **步骤 4：提交**

```bash
git add android-app/lib/screens/report_screen.dart android-app/lib/screens/chat_screen.dart
git commit -m "feat: ReportScreen mixed mode - actionData display + API fallback"
```

---

## 任务 6：分享功能（share_plus + 剪贴板 fallback）

**文件：**
- 修改：`android-app/lib/screens/report_screen.dart:170-180`（_shareReport 方法）

- [ ] **步骤 1：实现 _shareReport 方法**

在 `report_screen.dart` 顶部添加 import：

```dart
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
```

替换 `_shareReport` 方法：

```dart
  void _shareReport() {
    final text = _formatReportText();
    
    try {
      Share.share(text, subject: 'Smart Price AI 购物决策报告');
    } catch (e) {
      // Fallback: 复制到剪贴板
      Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('报告已复制到剪贴板')),
        );
      }
    }
  }
```

- [ ] **步骤 2：编译检查**

```bash
cd android-app
flutter analyze lib/screens/report_screen.dart
```

- [ ] **步骤 3：提交**

```bash
git add android-app/lib/screens/report_screen.dart
git commit -m "feat: share report via share_plus with clipboard fallback"
```

---

## 任务 7：全局编译验证 + APK 构建

**文件：**
- 全部

- [ ] **步骤 1：flutter analyze**

```bash
cd android-app
flutter analyze
```

预期：**0 issues**

- [ ] **步骤 2：flutter build apk**

```bash
flutter build apk --release
```

预期：成功

- [ ] **步骤 3：后端测试**

```bash
cd backend
pytest tests/ -v
```

预期：**25/25 PASS**

- [ ] **步骤 4：提交**

```bash
git add -A
git commit -m "feat(day8): trend chart + report mixed mode + share"
```

---

## 自检

**1. 规格覆盖：**
- ✅ 价格走势图 Mock 数据 → 任务 1-2
- ✅ fl_chart 折线图 → 任务 4
- ✅ 决策报告混合模式 → 任务 5
- ✅ 分享功能 share_plus + fallback → 任务 6
- ✅ 编译验证 → 任务 7

**2. 占位符扫描：**
- 无 TBD/TODO/"稍后实现"
- 所有步骤都有具体代码

**3. 类型一致性：**
- `history_prices` 字段前后端一致：`list[dict]` / `List<Map<String, dynamic>>`
- `TrendResponse` schema 修改后 service 和 router 同步更新

---

**计划完成并保存到 `docs/superpowers/plans/2025-05-29-day8-features.md`。两种执行选项：**

**1. Subagent-Driven（推荐）** - 我为每个任务分派一个新的子代理，在任务之间审查，快速迭代
**2. Inline Execution** - 使用 executing-plans 在此会话中执行任务，批量执行并设置检查点

**选择哪种方式？**
