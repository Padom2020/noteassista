import 'package:flutter/material.dart';
import '../services/database_diagnostic_service.dart';

/// Widget for displaying database diagnostic information and recovery options
class DatabaseDiagnosticWidget extends StatefulWidget {
  final VoidCallback? onDiagnosticsComplete;

  const DatabaseDiagnosticWidget({super.key, this.onDiagnosticsComplete});

  @override
  State<DatabaseDiagnosticWidget> createState() =>
      _DatabaseDiagnosticWidgetState();
}

class _DatabaseDiagnosticWidgetState extends State<DatabaseDiagnosticWidget> {
  late Future<DiagnosticReport> _diagnosticFuture;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  void _runDiagnostics() {
    setState(() {
      _isRunning = true;
      _diagnosticFuture =
          DatabaseDiagnosticService.instance.generateDiagnosticReport();
    });

    _diagnosticFuture.then((_) {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
        widget.onDiagnosticsComplete?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DiagnosticReport>(
      future: _diagnosticFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData) {
          return _buildErrorState('No diagnostic data available');
        }

        final report = snapshot.data!;
        return _buildDiagnosticReport(report);
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Running diagnostics...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            'Diagnostic Error',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _runDiagnostics,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticReport(DiagnosticReport report) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header
            _buildStatusHeader(report),
            const SizedBox(height: 24),

            // Passed checks
            if (report.passedChecks.isNotEmpty) ...[
              _buildCheckSection(
                'Passed Checks',
                report.passedChecks,
                Colors.green,
              ),
              const SizedBox(height: 16),
            ],

            // Failed checks
            if (report.failedChecks.isNotEmpty) ...[
              _buildCheckSection(
                'Failed Checks',
                report.failedChecks,
                Colors.red,
              ),
              const SizedBox(height: 16),
            ],

            // Overall suggestion
            if (report.overallSuggestion != null) ...[
              _buildSuggestionBox(report.overallSuggestion!),
              const SizedBox(height: 16),
            ],

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(DiagnosticReport report) {
    final isHealthy = report.isHealthy;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHealthy ? Colors.green.shade50 : Colors.red.shade50,
        border: Border.all(
          color: isHealthy ? Colors.green : Colors.red,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.error,
            color: isHealthy ? Colors.green : Colors.red,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHealthy ? 'Database Healthy' : 'Database Issues Detected',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isHealthy ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last checked: ${report.timestamp.toString().split('.')[0]}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckSection(
    String title,
    List<DiagnosticCheckResult> checks,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...checks.map((check) => _buildCheckItem(check, color)),
      ],
    );
  }

  Widget _buildCheckItem(DiagnosticCheckResult check, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                check.passed ? Icons.check : Icons.close,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  check.message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (check.suggestion != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                '💡 ${check.suggestion}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionBox(String suggestion) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              suggestion,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: _isRunning ? null : _runDiagnostics,
          icon: const Icon(Icons.refresh),
          label: const Text('Run Again'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            // Copy diagnostic report to clipboard
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Diagnostic report copied')),
              );
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy Report'),
        ),
      ],
    );
  }
}

/// Dialog for showing database diagnostics
class DatabaseDiagnosticDialog extends StatelessWidget {
  const DatabaseDiagnosticDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Database Diagnostics'),
      content: SizedBox(
        width: double.maxFinite,
        child: DatabaseDiagnosticWidget(
          onDiagnosticsComplete: () {
            // Diagnostics complete
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
