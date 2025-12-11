import 'dart:async';
import 'package:flutter/widgets.dart';

/// Utility class for performance optimizations
class PerformanceUtils {
  /// Debounce a function call
  /// Delays execution until [duration] has passed since the last call
  static Timer? _debounceTimer;

  static void debounce(Duration duration, VoidCallback action) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, action);
  }

  /// Throttle a function call
  /// Ensures function is called at most once per [duration]
  static DateTime? _lastThrottleTime;

  static void throttle(Duration duration, VoidCallback action) {
    final now = DateTime.now();
    if (_lastThrottleTime == null ||
        now.difference(_lastThrottleTime!) >= duration) {
      _lastThrottleTime = now;
      action();
    }
  }

  /// Cancel any pending debounce timers
  static void cancelDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Reset throttle timer
  static void resetThrottle() {
    _lastThrottleTime = null;
  }
}

/// Mixin for widgets that need debouncing
mixin DebounceMixin {
  Timer? _debounceTimer;

  void debounce(Duration duration, VoidCallback action) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, action);
  }

  void cancelDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  void dispose() {
    cancelDebounce();
  }
}

/// Mixin for widgets that need throttling
mixin ThrottleMixin {
  DateTime? _lastThrottleTime;

  void throttle(Duration duration, VoidCallback action) {
    final now = DateTime.now();
    if (_lastThrottleTime == null ||
        now.difference(_lastThrottleTime!) >= duration) {
      _lastThrottleTime = now;
      action();
    }
  }

  void resetThrottle() {
    _lastThrottleTime = null;
  }
}

/// Cache manager for images and data
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  /// Get cached value
  T? get<T>(String key) {
    if (_cache.containsKey(key)) {
      final timestamp = _cacheTimestamps[key];
      if (timestamp != null) {
        // Check if cache is still valid (5 minutes)
        if (DateTime.now().difference(timestamp).inMinutes < 5) {
          return _cache[key] as T?;
        } else {
          // Cache expired, remove it
          _cache.remove(key);
          _cacheTimestamps.remove(key);
        }
      }
    }
    return null;
  }

  /// Set cached value
  void set<T>(String key, T value) {
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Clear specific cache entry
  void clear(String key) {
    _cache.remove(key);
    _cacheTimestamps.remove(key);
  }

  /// Clear all cache
  void clearAll() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  /// Get cache size
  int get size => _cache.length;
}

/// Pagination helper
class PaginationHelper<T> {
  final int pageSize;
  final List<T> _allItems = [];
  int _currentPage = 0;
  bool _hasMore = true;

  PaginationHelper({this.pageSize = 20});

  /// Add items to the list
  void addItems(List<T> items) {
    _allItems.addAll(items);
    _hasMore = items.length >= pageSize;
  }

  /// Get current page items
  List<T> getCurrentPageItems() {
    final startIndex = _currentPage * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, _allItems.length);
    return _allItems.sublist(startIndex, endIndex);
  }

  /// Get all loaded items
  List<T> getAllItems() => List.unmodifiable(_allItems);

  /// Load next page
  void nextPage() {
    if (_hasMore) {
      _currentPage++;
    }
  }

  /// Reset pagination
  void reset() {
    _allItems.clear();
    _currentPage = 0;
    _hasMore = true;
  }

  /// Check if there are more items to load
  bool get hasMore => _hasMore;

  /// Get current page number
  int get currentPage => _currentPage;

  /// Get total items loaded
  int get totalItems => _allItems.length;
}

/// Lazy loading helper for lists
class LazyLoadController {
  final ScrollController scrollController;
  final VoidCallback onLoadMore;
  final double threshold;

  bool _isLoading = false;

  LazyLoadController({
    required this.scrollController,
    required this.onLoadMore,
    this.threshold = 0.8,
  }) {
    scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_isLoading) return;

    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;
    final triggerPoint = maxScroll * threshold;

    if (currentScroll >= triggerPoint) {
      _isLoading = true;
      onLoadMore();
    }
  }

  void setLoading(bool loading) {
    _isLoading = loading;
  }

  void dispose() {
    scrollController.removeListener(_scrollListener);
  }
}
