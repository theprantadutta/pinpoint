import 'package:flutter/material.dart';
import 'package:pinpoint/services/admin_api_service.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/util/show_a_toast.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';

/// Admin Job History Screen
///
/// Shows job details, statistics, and run history
class AdminJobHistoryScreen extends StatefulWidget {
  static const String kRouteName = '/admin-panel/jobs';

  final String jobId;

  const AdminJobHistoryScreen({
    super.key,
    required this.jobId,
  });

  @override
  State<AdminJobHistoryScreen> createState() => _AdminJobHistoryScreenState();
}

class _AdminJobHistoryScreenState extends State<AdminJobHistoryScreen> {
  final AdminApiService _adminApi = AdminApiService();
  bool _isLoadingDetails = false;
  bool _isLoadingHistory = false;
  Map<String, dynamic>? _jobDetails;
  List<dynamic> _runs = [];
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'AdminJobHistory');
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadJobDetails(),
      _loadHistory(),
    ]);
  }

  Future<void> _loadJobDetails() async {
    setState(() {
      _isLoadingDetails = true;
    });

    try {
      final response = await _adminApi.getJobDetails(widget.jobId);
      setState(() {
        _jobDetails = response;
        _isLoadingDetails = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDetails = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load job details: $e')),
        );
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final response = await _adminApi.getJobHistory(
        widget.jobId,
        page: _currentPage,
      );

      setState(() {
        _runs = response['runs'] ?? [];
        _totalPages = response['total_pages'] ?? 1;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingHistory = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load history: $e')),
        );
      }
    }
  }

  Future<void> _triggerJob() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trigger Job'),
        content: Text(
          'Are you sure you want to run "${_jobDetails?['name'] ?? widget.jobId}" now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Run Now'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await _adminApi.triggerJob(widget.jobId);
      if (mounted) {
        showSketchToast(
          context: context,
          message: response['message'] ?? 'Job triggered',
          tone:
              response['success'] == true ? ToastTone.success : ToastTone.error,
        );
        _loadData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        showSketchToast(
          context: context,
          message: 'Failed to trigger job: $e',
          tone: ToastTone.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sk = context.sketch;

    return SketchScaffold(
      title: _jobDetails?['name'] ?? widget.jobId,
      actions: [
        CircleIconButton(
          icon: Icons.refresh_rounded,
          onPressed: _loadData,
          semanticLabel: 'Refresh',
        ),
        const SizedBox(width: 6),
        CircleIconButton(
          icon: Icons.play_arrow_rounded,
          fill: context.sketch.inverse,
          onPressed: _triggerJob,
          semanticLabel: 'Run Now',
        ),
      ],
      body: _isLoadingDetails
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Job Info Card
                  _JobInfoCard(job: _jobDetails!),

                  const SizedBox(height: 16),

                  // Statistics Card
                  _StatisticsCard(
                    statistics: _jobDetails!['statistics'],
                  ),

                  const SizedBox(height: 24),

                  // History section
                  Text(
                    'Run History',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (_isLoadingHistory)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_runs.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.history, size: 48, color: sk.muted),
                            const SizedBox(height: 16),
                            Text(
                              'No runs yet',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: sk.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._runs.map((run) => _RunCard(run: run)),

                  // Pagination
                  if (_totalPages > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 1
                                ? () {
                                    setState(() {
                                      _currentPage--;
                                    });
                                    _loadHistory();
                                  }
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Text('Page $_currentPage of $_totalPages'),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _currentPage < _totalPages
                                ? () {
                                    setState(() {
                                      _currentPage++;
                                    });
                                    _loadHistory();
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _JobInfoCard extends StatelessWidget {
  final Map<String, dynamic> job;

  const _JobInfoCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sk = context.sketch;
    final isPaused = job['is_paused'] ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['name'] ?? job['job_id'],
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job['job_id'],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: sk.muted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isPaused ? SketchPastels.yellow : SketchPastels.mint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPaused ? Icons.pause : Icons.play_arrow,
                        size: 16,
                        color: SketchPastels.onPastel,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPaused ? 'Paused' : 'Active',
                        style: const TextStyle(
                          color: SketchPastels.onPastel,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              job['description'] ?? 'No description',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: sk.muted,
              ),
            ),
            if (job['next_run_time'] != null && !isPaused) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: sk.ink),
                  const SizedBox(width: 8),
                  Text(
                    'Next run: ',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    _formatDateTime(job['next_run_time']),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: sk.ink,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Unknown';
    try {
      final date = DateTime.parse(isoString).toLocal();
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }
}

class _StatisticsCard extends StatelessWidget {
  final Map<String, dynamic>? statistics;

  const _StatisticsCard({this.statistics});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sk = context.sketch;

    if (statistics == null) {
      return const SizedBox.shrink();
    }

    final totalRuns = statistics!['total_runs'] ?? 0;
    final successRuns = statistics!['success_runs'] ?? 0;
    final failedRuns = statistics!['failed_runs'] ?? 0;
    final successRate = statistics!['success_rate'] ?? 0.0;
    final avgDuration = statistics!['avg_duration_seconds'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.numbers,
                    label: 'Total Runs',
                    value: totalRuns.toString(),
                    color: sk.ink,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.check_circle,
                    label: 'Success',
                    value: successRuns.toString(),
                    color: SketchFunctional.success,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.error,
                    label: 'Failed',
                    value: failedRuns.toString(),
                    color: SketchFunctional.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.percent,
                    label: 'Success Rate',
                    value: '${successRate.toStringAsFixed(1)}%',
                    color: successRate >= 90
                        ? SketchFunctional.success
                        : successRate >= 70
                            ? sk.muted
                            : SketchFunctional.error,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.timer,
                    label: 'Avg Duration',
                    value: avgDuration != null
                        ? '${avgDuration.toStringAsFixed(2)}s'
                        : '--',
                    color: sk.ink,
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sk = context.sketch;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: sk.muted,
          ),
        ),
      ],
    );
  }
}

class _RunCard extends StatelessWidget {
  final Map<String, dynamic> run;

  const _RunCard({required this.run});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sk = context.sketch;
    final status = run['status'];
    final triggerType = run['trigger_type'];
    final triggeredBy = run['triggered_by'];

    Color statusColor;
    IconData statusIcon;

    if (status == 'success') {
      statusColor = SketchFunctional.success;
      statusIcon = Icons.check_circle;
    } else if (status == 'failed') {
      statusColor = SketchFunctional.error;
      statusIcon = Icons.error;
    } else {
      statusColor = sk.pen;
      statusIcon = Icons.hourglass_empty;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Row(
          children: [
            Text(
              _formatDateTime(run['started_at']),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (run['duration_seconds'] != null)
              Text(
                _formatDuration(run['duration_seconds']),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: sk.muted,
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Icon(
              triggerType == 'manual' ? Icons.person : Icons.schedule,
              size: 14,
              color: sk.muted,
            ),
            const SizedBox(width: 4),
            Text(
              triggerType == 'manual'
                  ? 'Manual${triggeredBy != null ? ' by $triggeredBy' : ''}'
                  : 'Scheduled',
              style: theme.textTheme.bodySmall?.copyWith(
                color: sk.muted,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (run['result_data'] != null) ...[
                  Text(
                    'Result',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: sk.soft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      _formatJson(run['result_data']),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (run['error_message'] != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Error',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: SketchFunctional.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SketchFunctional.errorFill,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: SketchFunctional.error,
                      ),
                    ),
                    child: SelectableText(
                      run['error_message'],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: SketchFunctional.error,
                      ),
                    ),
                  ),
                ],
                if (run['result_data'] == null &&
                    run['error_message'] == null) ...[
                  Center(
                    child: Text(
                      'No additional details',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: sk.muted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Unknown';
    try {
      final date = DateTime.parse(isoString).toLocal();
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }

  String _formatDuration(dynamic seconds) {
    if (seconds == null) return '--';
    final s = (seconds as num).toDouble();
    if (s < 1) return '${(s * 1000).toInt()}ms';
    if (s < 60) return '${s.toStringAsFixed(2)}s';
    return '${(s / 60).toStringAsFixed(1)}m';
  }

  String _formatJson(dynamic data) {
    if (data == null) return 'null';
    if (data is Map) {
      return data.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    }
    return data.toString();
  }
}
