import 'package:flutter/foundation.dart';

class TestPerformanceMonitor {
  static TestPerformanceMonitor? _instance;

  TestPerformanceMonitor._internal();

  static TestPerformanceMonitor get instance {
    _instance ??= TestPerformanceMonitor._internal();
    return _instance!;
  }
}

void main() {
  TestPerformanceMonitor.instance;
  debugPrint('Test works: true');
}
