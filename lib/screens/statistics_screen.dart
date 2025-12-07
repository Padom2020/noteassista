import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/statistics_service.dart';
import '../models/statistics_model.dart';
import '../models/note_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final StatisticsService _statisticsService = StatisticsService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  StatisticsModel? _statistics;
  List<NoteModel> _recentNotes = [];
  NoteModel? _longestNote;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Calculate statistics
      final stats = await _statisticsService.calculateStatistics(user.uid);

      // Get recent notes
      final notesSnapshot =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('notes')
              .orderBy('updatedAt', descending: true)
              .limit(5)
              .get();

      final recentNotes =
          notesSnapshot.docs
              .map((doc) => NoteModel.fromFirestore(doc))
              .toList();

      // Get longest note
      final allNotesSnapshot =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('notes')
              .get();

      final allNotes =
          allNotesSnapshot.docs
              .map((doc) => NoteModel.fromFirestore(doc))
              .toList();

      NoteModel? longestNote;
      if (allNotes.isNotEmpty) {
        longestNote = allNotes.reduce(
          (a, b) => a.wordCount > b.wordCount ? a : b,
        );
      }

      setState(() {
        _statistics = stats;
        _recentNotes = recentNotes;
        _longestNote = longestNote;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading statistics',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(_error!),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadStatistics,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : _statistics == null
              ? const Center(child: Text('No statistics available'))
              : RefreshIndicator(
                onRefresh: _loadStatistics,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverviewCards(),
                      const SizedBox(height: 24),
                      _buildStreakSection(),
                      const SizedBox(height: 24),
                      _buildCalendarHeatmap(),
                      const SizedBox(height: 24),
                      _buildTagFrequencyChart(),
                      const SizedBox(height: 24),
                      _buildCreationTrendChart(),
                      const SizedBox(height: 24),
                      _buildCompletionRate(),
                      const SizedBox(height: 24),
                      _buildMostUsedTags(),
                      const SizedBox(height: 24),
                      _buildRecentNotes(),
                      const SizedBox(height: 24),
                      _buildLongestNote(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildOverviewCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.note,
                label: 'Total Notes',
                value: _statistics!.totalNotes.toString(),
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.calendar_today,
                label: 'This Week',
                value: _statistics!.notesThisWeek.toString(),
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.calendar_month,
                label: 'This Month',
                value: _statistics!.notesThisMonth.toString(),
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.text_fields,
                label: 'Total Words',
                value: _formatNumber(_statistics!.totalWordCount),
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Streaks',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 32)),
                          const SizedBox(width: 8),
                          Text(
                            _statistics!.currentStreak.toString(),
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current Streak',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        '${_statistics!.currentStreak} ${_statistics!.currentStreak == 1 ? 'day' : 'days'}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 80, color: Colors.grey[300]),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🏆', style: TextStyle(fontSize: 32)),
                          const SizedBox(width: 8),
                          Text(
                            _statistics!.longestStreak.toString(),
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Longest Streak',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        '${_statistics!.longestStreak} ${_statistics!.longestStreak == 1 ? 'day' : 'days'}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarHeatmap() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Note Creation Heatmap',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildHeatmapGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapGrid() {
    if (_statistics!.creationHeatmap.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No data available'),
        ),
      );
    }

    // Get last 12 weeks of data
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 84)); // 12 weeks

    final maxCount =
        _statistics!.creationHeatmap.values.isEmpty
            ? 1
            : _statistics!.creationHeatmap.values.reduce(math.max);

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 84,
        itemBuilder: (context, index) {
          final date = startDate.add(Duration(days: index));
          final dateOnly = DateTime(date.year, date.month, date.day);
          final count = _statistics!.creationHeatmap[dateOnly] ?? 0;
          final intensity = maxCount > 0 ? count / maxCount : 0.0;

          return Padding(
            padding: const EdgeInsets.all(2),
            child: Tooltip(
              message: '${date.month}/${date.day}: $count notes',
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getHeatmapColor(intensity),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getHeatmapColor(double intensity) {
    if (intensity == 0) return Colors.grey[200]!;
    if (intensity < 0.25) return Colors.green[200]!;
    if (intensity < 0.5) return Colors.green[400]!;
    if (intensity < 0.75) return Colors.green[600]!;
    return Colors.green[800]!;
  }

  Widget _buildTagFrequencyChart() {
    if (_statistics!.tagFrequency.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedTags =
        _statistics!.tagFrequency.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final topTags = sortedTags.take(10).toList();
    final maxCount = topTags.first.value;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tag Frequency',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...topTags.map((entry) {
              final percentage = entry.value / maxCount;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          entry.value.toString(),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.deepPurple,
                      ),
                      minHeight: 8,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCreationTrendChart() {
    if (_statistics!.creationHeatmap.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group by week
    final weeklyData = <DateTime, int>{};
    for (final entry in _statistics!.creationHeatmap.entries) {
      final weekStart = _getStartOfWeek(entry.key);
      weeklyData[weekStart] = (weeklyData[weekStart] ?? 0) + entry.value;
    }

    final sortedWeeks =
        weeklyData.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    final last8Weeks =
        sortedWeeks.length > 8
            ? sortedWeeks.sublist(sortedWeeks.length - 8)
            : sortedWeeks;

    if (last8Weeks.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxCount = last8Weeks.map((e) => e.value).reduce(math.max);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Creation Trends (Last 8 Weeks)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children:
                    last8Weeks.map((entry) {
                      final height =
                          maxCount > 0 ? (entry.value / maxCount) * 150 : 0.0;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                entry.value.toString(),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: height,
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${entry.key.month}/${entry.key.day}',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionRate() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Completion Rate',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: CircularProgressIndicator(
                        value: _statistics!.completionRate / 100,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.green,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_statistics!.completionRate.toStringAsFixed(1)}%',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          'Complete',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMostUsedTags() {
    if (_statistics!.tagFrequency.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedTags =
        _statistics!.tagFrequency.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final topTags = sortedTags.take(5).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Most Frequently Used Tags',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  topTags.map((entry) {
                    return Chip(
                      label: Text('${entry.key} (${entry.value})'),
                      backgroundColor: Colors.deepPurple[100],
                      labelStyle: const TextStyle(color: Colors.deepPurple),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentNotes() {
    if (_recentNotes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recently Modified Notes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._recentNotes.map((note) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple[100],
                  child: const Icon(Icons.note, color: Colors.deepPurple),
                ),
                title: Text(
                  note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _formatDate(note.updatedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing:
                    note.isDone
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLongestNote() {
    if (_longestNote == null || _longestNote!.wordCount == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Longest Note',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.amber[100],
                child: const Icon(Icons.article, color: Colors.amber),
              ),
              title: Text(
                _longestNote!.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${_longestNote!.wordCount} words',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _getStartOfWeek(DateTime date) {
    final weekday = date.weekday;
    final daysToSubtract = weekday - 1; // Monday is 1
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: daysToSubtract));
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
