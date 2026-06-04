import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_price_ai/widgets/scan_line_overlay.dart';

void main() {
  testWidgets('ScanLineOverlay displays progress stage text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScanLineOverlay(
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    // 验证存在进度文字 Text widget
    expect(find.byType(Text), findsAtLeastNWidgets(1));

    // 验证初始阶段文字存在
    expect(find.textContaining('正在'), findsOneWidget);
  });

  testWidgets('ScanLineOverlay progress text changes over time', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScanLineOverlay(
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    // 初始阶段
    expect(find.textContaining('上传'), findsOneWidget);

    // 推进 3 秒，应进入下一阶段
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('分析'), findsOneWidget);

    // 推进 6 秒，应进入再下一阶段
    await tester.pump(const Duration(seconds: 6));
    expect(find.textContaining('识别'), findsOneWidget);
  });
}
