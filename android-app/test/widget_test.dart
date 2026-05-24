// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_price_ai/main.dart';

void main() {
  testWidgets('App launches and shows home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmartPriceAIApp());

    // Verify that the home screen is displayed with expected content.
    expect(find.text('Hi, User'), findsOneWidget);
    expect(find.text('今天想买点什么？'), findsOneWidget);
    expect(find.text('拍照识物'), findsOneWidget);
  });
}

