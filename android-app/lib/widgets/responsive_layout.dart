import 'package:flutter/material.dart';

enum ScreenType { small, medium, large }

class ResponsiveLayout {
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return ScreenType.small;
    if (width < 420) return ScreenType.medium;
    return ScreenType.large;
  }

  static T value<T>(BuildContext context, {
    required T small,
    required T medium,
    required T large,
  }) {
    switch (getScreenType(context)) {
      case ScreenType.small:
        return small;
      case ScreenType.medium:
        return medium;
      case ScreenType.large:
        return large;
    }
  }
}
