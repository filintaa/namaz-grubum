import 'package:flutter/foundation.dart';

abstract final class PlatformInfo {
  static bool get isCupertino =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}
