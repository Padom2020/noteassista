import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage onboarding and feature discovery state
class OnboardingService {
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyAppVersion = 'app_version';
  static const String _keyFeaturesSeen = 'features_seen';
  static const String _keyTooltipsSeen = 'tooltips_seen';

  /// Check if onboarding has been completed
  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingCompleted) ?? false;
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, true);
  }

  /// Check if a specific feature has been seen
  Future<bool> hasSeenFeature(String featureId) async {
    final prefs = await SharedPreferences.getInstance();
    final featuresSeen = prefs.getStringList(_keyFeaturesSeen) ?? [];
    return featuresSeen.contains(featureId);
  }

  /// Mark a feature as seen
  Future<void> markFeatureAsSeen(String featureId) async {
    final prefs = await SharedPreferences.getInstance();
    final featuresSeen = prefs.getStringList(_keyFeaturesSeen) ?? [];
    if (!featuresSeen.contains(featureId)) {
      featuresSeen.add(featureId);
      await prefs.setStringList(_keyFeaturesSeen, featuresSeen);
    }
  }

  /// Check if a specific tooltip has been seen
  Future<bool> hasSeenTooltip(String tooltipId) async {
    final prefs = await SharedPreferences.getInstance();
    final tooltipsSeen = prefs.getStringList(_keyTooltipsSeen) ?? [];
    return tooltipsSeen.contains(tooltipId);
  }

  /// Mark a tooltip as seen
  Future<void> markTooltipAsSeen(String tooltipId) async {
    final prefs = await SharedPreferences.getInstance();
    final tooltipsSeen = prefs.getStringList(_keyTooltipsSeen) ?? [];
    if (!tooltipsSeen.contains(tooltipId)) {
      tooltipsSeen.add(tooltipId);
      await prefs.setStringList(_keyTooltipsSeen, tooltipsSeen);
    }
  }

  /// Get the last known app version
  Future<String?> getLastAppVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAppVersion);
  }

  /// Update the app version
  Future<void> updateAppVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppVersion, version);
  }

  /// Check if this is a new version (for "What's New" screen)
  Future<bool> isNewVersion(String currentVersion) async {
    final lastVersion = await getLastAppVersion();
    return lastVersion == null || lastVersion != currentVersion;
  }

  /// Reset all onboarding state (for testing)
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOnboardingCompleted);
    await prefs.remove(_keyFeaturesSeen);
    await prefs.remove(_keyTooltipsSeen);
  }
}
