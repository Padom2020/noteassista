enum DailyNoteType { daily, weekly, monthly }

class DailyNotePreferences {
  final String? customDailyTemplate;
  final String? customWeeklyTemplate;
  final String? customMonthlyTemplate;
  final bool autoCreateDaily;
  final String? autoCreateTime; // Format: "HH:mm"
  final bool useCustomTemplate;

  DailyNotePreferences({
    this.customDailyTemplate,
    this.customWeeklyTemplate,
    this.customMonthlyTemplate,
    this.autoCreateDaily = false,
    this.autoCreateTime,
    this.useCustomTemplate = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'customDailyTemplate': customDailyTemplate,
      'customWeeklyTemplate': customWeeklyTemplate,
      'customMonthlyTemplate': customMonthlyTemplate,
      'autoCreateDaily': autoCreateDaily,
      'autoCreateTime': autoCreateTime,
      'useCustomTemplate': useCustomTemplate,
    };
  }

  factory DailyNotePreferences.fromMap(Map<String, dynamic> data) {
    return DailyNotePreferences(
      customDailyTemplate: data['customDailyTemplate'] as String?,
      customWeeklyTemplate: data['customWeeklyTemplate'] as String?,
      customMonthlyTemplate: data['customMonthlyTemplate'] as String?,
      autoCreateDaily: data['autoCreateDaily'] as bool? ?? false,
      autoCreateTime: data['autoCreateTime'] as String?,
      useCustomTemplate: data['useCustomTemplate'] as bool? ?? false,
    );
  }

  DailyNotePreferences copyWith({
    String? customDailyTemplate,
    String? customWeeklyTemplate,
    String? customMonthlyTemplate,
    bool? autoCreateDaily,
    String? autoCreateTime,
    bool? useCustomTemplate,
  }) {
    return DailyNotePreferences(
      customDailyTemplate: customDailyTemplate ?? this.customDailyTemplate,
      customWeeklyTemplate: customWeeklyTemplate ?? this.customWeeklyTemplate,
      customMonthlyTemplate:
          customMonthlyTemplate ?? this.customMonthlyTemplate,
      autoCreateDaily: autoCreateDaily ?? this.autoCreateDaily,
      autoCreateTime: autoCreateTime ?? this.autoCreateTime,
      useCustomTemplate: useCustomTemplate ?? this.useCustomTemplate,
    );
  }

  // Default templates
  static String getDefaultDailyTemplate() {
    return '''# Daily Note - {{date}}

## Morning
**Mood:** 
**Energy Level:** 
**Today's Focus:** 

## Goals for Today
- [ ] 
- [ ] 
- [ ] 

## Gratitude
1. 
2. 
3. 

## Notes


## Evening Reflection
**How did today go?** 

**What could be improved?** 
''';
  }

  static String getDefaultWeeklyTemplate() {
    return '''# Weekly Review - Week {{week_number}}, {{year}}

**Week of:** {{start_date}} to {{end_date}}

## Highlights of the Week
- 
- 
- 

## Goals Completed
- [ ] 
- [ ] 
- [ ] 

## Challenges Faced


## Lessons Learned


## Goals for Next Week
- [ ] 
- [ ] 
- [ ] 

## Areas for Improvement


## Notes

''';
  }

  static String getDefaultMonthlyTemplate() {
    return '''# Monthly Review - {{month}} {{year}}

## Overview


## Key Achievements
- 
- 
- 

## Goals Completed
- [ ] 
- [ ] 
- [ ] 

## Challenges and Solutions


## Personal Growth


## Professional Development


## Health & Wellness


## Relationships


## Financial Summary


## Goals for Next Month
- [ ] 
- [ ] 
- [ ] 

## Focus Areas


## Notes

''';
  }
}
