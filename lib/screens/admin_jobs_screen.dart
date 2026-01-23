import 'package:flutter/material.dart';
import 'package:pinpoint/services/admin_api_service.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:go_router/go_router.dart';

/// Admin Jobs Screen
///
/// Shows list of all scheduled background jobs with status and actions
class AdminJobsScreen extends StatefulWidget {
  static const String kRouteName = '/admin-panel/jobs';

  const AdminJobsScreen({super.key});

  @override
  State<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends State<AdminJobsScreen> {
  final AdminApiService _adminApi = AdminApiService();
  bool _isLoading = false;
  List<dynamic> _jobs = [];

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _adminApi.getJobs();

      setState(() {
        _jobs = response['jobs'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load jobs: $e')),
        );
      }
    }
  }

  Future<void> _triggerJob(String jobId, String jobName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trigger Job'),
        content: Text('Are you sure you want to run "$jobName" now?'),
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
      final response = await _adminApi.triggerJob(jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Job triggered'),
            backgroundColor:
                response['success'] == true ? Colors.green : Colors.red,
          ),
        );
        _loadJobs(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to trigger job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePause(String jobId, bool isPaused) async {
    try {
      final response = isPaused
          ? await _adminApi.resumeJob(jobId)
          : await _adminApi.pauseJob(jobId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Action completed'),
            backgroundColor:
                response['success'] == true ? Colors.green : Colors.red,
          ),
        );
        _loadJobs(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${isPaused ? 'resume' : 'pause'} job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GradientScaffold(
      appBar: GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.schedule, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            const Text('Scheduled Jobs'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJobs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.work_off, size: 64, color: cs.outline),
                      const SizedBox(height: 16),
                      Text(
                        'No jobs registered',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadJobs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _jobs.length,
                    itemBuilder: (context, index) {
                      final job = _jobs[index];
                      return _JobCard(
                        job: job,
                        onTap: () {
                          context.push(
                            '/admin-panel/jobs/${job['job_id']}',
                          );
                        },
                        onTrigger: () =>
                            _triggerJob(job['job_id'], job['name']),
                        onTogglePause: () =>
                            _togglePause(job['job_id'], job['is_paused']),
                      );
                    },
                  ),
                ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onTap;
  final VoidCallback onTrigger;
  final VoidCallback onTogglePause;

  const _JobCard({
    required this.job,
    required this.onTap,
    required this.onTrigger,
    required this.onTogglePause,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isPaused = job['is_paused'] ?? false;
    final lastRun = job['last_run'];
    final lastStatus = lastRun?['status'];

    Color statusColor;
    IconData statusIcon;

    if (isPaused) {
      statusColor = Colors.orange;
      statusIcon = Icons.pause_circle;
    } else if (lastStatus == 'success') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (lastStatus == 'failed') {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else if (lastStatus == 'running') {
      statusColor = Colors.blue;
      statusIcon = Icons.play_circle;
    } else {
      statusColor = cs.outline;
      statusIcon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job['name'] ?? job['job_id'],
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          job['job_id'],
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.outline,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPaused)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PAUSED',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                job['description'] ?? 'No description',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Info row
              Row(
                children: [
                  // Next run
                  if (job['next_run_time'] != null && !isPaused)
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.schedule,
                        label: 'Next: ${_formatDateTime(job['next_run_time'])}',
                      ),
                    )
                  else
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.schedule_outlined,
                        label: isPaused ? 'Paused' : 'Not scheduled',
                      ),
                    ),

                  // Last run status
                  if (lastRun != null)
                    _InfoChip(
                      icon: lastStatus == 'success'
                          ? Icons.check
                          : lastStatus == 'failed'
                              ? Icons.close
                              : Icons.hourglass_empty,
                      label:
                          '${_formatDuration(lastRun['duration_seconds'])} ago',
                      color: lastStatus == 'success'
                          ? Colors.green
                          : lastStatus == 'failed'
                              ? Colors.red
                              : null,
                    ),
                ],
              ),

              const Divider(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onTogglePause,
                    icon:
                        Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 18),
                    label: Text(isPaused ? 'Resume' : 'Pause'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onTrigger,
                    icon: const Icon(Icons.play_circle, size: 18),
                    label: const Text('Run Now'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Unknown';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = date.difference(now);

      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return isoString;
    }
  }

  String _formatDuration(dynamic seconds) {
    if (seconds == null) return '--';
    final s = (seconds as num).toDouble();
    if (s < 1) return '${(s * 1000).toInt()}ms';
    if (s < 60) return '${s.toStringAsFixed(1)}s';
    return '${(s / 60).toStringAsFixed(1)}m';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final effectiveColor = color ?? cs.outline;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: effectiveColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: effectiveColor,
          ),
        ),
      ],
    );
  }
}
