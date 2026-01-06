import 'package:flutter/foundation.dart';
import 'lib/utils/performance_monitor.dart';
import 'lib/config/debug_config.dart';

void main() {
  PerformanceMonitor.instance;
  DebugConfig.instance;
  debugPrint('Imports work: true');
}
