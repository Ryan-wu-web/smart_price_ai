import 'package:flutter/material.dart';

/// Smart Price AI — 完整 Design Token 体系
/// Day 4 UI 精细打磨 | 2025-05-23
///
/// 设计参考：frontend-design skill — 现代极简科技风
/// - 1-2 accent 原则：仅 accentColor 用于价格/折扣
/// - 噪点纹理避免 sterile flatness
/// - prefers-reduced-motion 适配
class Constants {
  // ═══════════════════════════════════════════
  //  API
  // ═══════════════════════════════════════════
  static const String apiBaseUrl = 'http://10.236.123.80:8000';

  // ═══════════════════════════════════════════
  //  主色调 (Primary Palette)
  // ═══════════════════════════════════════════
  static const Color brandColor = Color(0xFF00B4D8); // 品牌青
  static const Color primaryDark = Color(0xFF0077B6); // 深海蓝（渐变终点）
  static const Color accentColor = Color(0xFFFF6B6B); // 促销红（仅价格/折扣）

  // ═══════════════════════════════════════════
  //  中性色 (Neutral Palette)
  // ═══════════════════════════════════════════
  static const Color backgroundColor = Color(0xFFF8F9FA); // 页面背景
  static const Color surfaceColor = Colors.white; // 卡片背景
  static const Color primaryTextColor = Color(0xFF1A1A2E); // 主文字
  static const Color secondaryTextColor = Color(0xFF6C757D); // 次要文字
  static const Color tertiaryTextColor = Color(0xFFADB5BD); // 辅助文字
  static const Color borderColor = Color(0xFFE9ECEF); // 边框/分割线

  // ═══════════════════════════════════════════
  //  功能色 (Functional Colors)
  // ═══════════════════════════════════════════
  static const Color successColor = Color(0xFF28A745);
  static const Color warningColor = Color(0xFFFFA500);
  static const Color errorColor = Color(0xFFDC3545);

  // ═══════════════════════════════════════════
  //  旧兼容别名（逐步废弃）
  // ═══════════════════════════════════════════
  static const Color cardColor = surfaceColor;
  static const Color bottomBarColor = Color(0xFF1A1A2E); // 深色底部栏备用

  // ═══════════════════════════════════════════
  //  圆角体系 (Radius Scale)
  // ═══════════════════════════════════════════
  static const double radiusSmall = 8.0; // 标签 chip
  static const double radiusMedium = 12.0; // 输入框、图标容器
  static const double radiusLarge = 16.0; // 标准卡片
  static const double radiusXLarge = 20.0; // 大卡片、弹窗

  // 兼容旧名
  static const double smallRadius = radiusSmall;
  static const double mediumRadius = radiusMedium;
  static const double largeRadius = radiusLarge;
  static const double xLargeRadius = radiusXLarge;

  // ═══════════════════════════════════════════
  //  阴影体系 (Shadow Scale)
  // ═══════════════════════════════════════════
  static const BoxShadow shadowCard = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 16,
    offset: Offset(0, 4),
  );
  static const BoxShadow shadowElevated = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  );
  static const BoxShadow shadowButton = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
  static const BoxShadow shadowLight = BoxShadow(
    color: Color(0x08000000),
    blurRadius: 10,
    offset: Offset(0, 2),
  );

  // ═══════════════════════════════════════════
  //  间距体系 (Spacing Scale) — 8px 基准
  // ═══════════════════════════════════════════
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;

  // 兼容旧名
  static const double paddingSmall = space8;
  static const double paddingMedium = space16;
  static const double paddingLarge = space24;

  // ═══════════════════════════════════════════
  //  字体层级 (Typography Scale)
  // ═══════════════════════════════════════════
  static const TextStyle display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: primaryTextColor,
    height: 1.2,
  );
  static const TextStyle h1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: primaryTextColor,
    height: 1.3,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: primaryTextColor,
    height: 1.4,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: primaryTextColor,
    height: 1.5,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: secondaryTextColor,
    height: 1.4,
  );
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: secondaryTextColor,
    height: 1.4,
  );

  // ═══════════════════════════════════════════
  //  渐变定义 (Gradients)
  // ═══════════════════════════════════════════
  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandColor, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient auroraGradient = LinearGradient(
    colors: [
      Color(0xFF00F5A0), // 亮绿
      Color(0xFF00D9F5), // 青
      Color(0xFF0077FF), // 蓝
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient placeholderGradient = LinearGradient(
    colors: [Color(0xFFE9ECEF), Color(0xFFF1F3F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ═══════════════════════════════════════════
  //  动画 (Animation)
  // ═══════════════════════════════════════════
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration staggerDelay = Duration(milliseconds: 100);
  static const Curve defaultCurve = Curves.easeOutCubic;

  // ═══════════════════════════════════════════
  //  动画 Token (Motion Tokens) — Day 5 新增
  // ═══════════════════════════════════════════
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);

  static const Curve easeSpring = Curves.elasticOut;
  static const Curve easeEntrance = Curves.easeOutCubic;
  static const Curve easeExit = Curves.easeInCubic;
  static const Curve easeBounce = Curves.bounceOut;

  static const Duration staggerDelayFast = Duration(milliseconds: 80);
}
