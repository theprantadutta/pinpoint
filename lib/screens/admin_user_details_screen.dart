import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinpoint/services/admin_api_service.dart';
import 'package:pinpoint/design_system/design_system.dart';

/// Admin User Details Screen
///
/// Shows comprehensive information about a specific user
class AdminUserDetailsScreen extends StatefulWidget {
  static const String kRouteName = '/admin-panel/user';

  final String userId;

  const AdminUserDetailsScreen({
    super.key,
    required this.userId,
  });

  @override
  State<AdminUserDetailsScreen> createState() => _AdminUserDetailsScreenState();
}

class _AdminUserDetailsScreenState extends State<AdminUserDetailsScreen>
    with SingleTickerProviderStateMixin {
  final AdminApiService _adminApi = AdminApiService();
  bool _isLoading = false;
  Map<String, dynamic>? _userDetails;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadUserDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final details = await _adminApi.getUserDetails(widget.userId);
      setState(() {
        _userDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user details: $e')),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _userDetails == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return GradientScaffold(
      appBar: GlassAppBar(
        title: Text(_userDetails!['email']),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Notes'),
            Tab(text: 'Encryption'),
            Tab(text: 'Sync'),
            Tab(text: 'Subscription'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(userDetails: _userDetails!, onCopy: _copyToClipboard),
          _NotesTab(userId: widget.userId),
          _EncryptionTab(userId: widget.userId, onCopy: _copyToClipboard),
          _SyncTab(userId: widget.userId),
          _SubscriptionTab(userId: widget.userId),
        ],
      ),
    );
  }
}

// Overview Tab
class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> userDetails;
  final Function(String, String) onCopy;

  const _OverviewTab({required this.userDetails, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          title: 'User ID',
          children: [
            Row(
              children: [
                Expanded(child: SelectableText(userDetails['id'])),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => onCopy(userDetails['id'], 'User ID'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: 'Basic Information',
          children: [
            _InfoRow('Email', userDetails['email']),
            _InfoRow('Created At', _formatDate(userDetails['created_at'])),
            _InfoRow('Last Login', _formatDate(userDetails['last_login'])),
            _InfoRow('Is Active', userDetails['is_active'].toString()),
          ],
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: 'Subscription',
          children: [
            _InfoRow('Tier', userDetails['subscription_tier']),
            _InfoRow('Is Premium', userDetails['is_premium'].toString()),
            _InfoRow('Status', userDetails['subscription_status']),
          ],
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: 'Statistics',
          children: [
            _InfoRow('Total Notes', userDetails['total_notes'].toString()),
            _InfoRow('Synced Notes', userDetails['synced_notes'].toString()),
            _InfoRow('Deleted Notes', userDetails['deleted_notes'].toString()),
            _InfoRow('Last Sync', _formatDate(userDetails['last_sync'])),
          ],
        ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Never';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date.toString();
    }
  }
}

// Notes Tab
class _NotesTab extends StatefulWidget {
  final String userId;

  const _NotesTab({required this.userId});

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  final AdminApiService _adminApi = AdminApiService();
  List<dynamic> _notes = [];
  bool _isLoading = false;
  bool _includeDeleted = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _adminApi.getUserNotes(
        widget.userId,
        includeDeleted: _includeDeleted,
      );

      setState(() {
        _notes = response['notes'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Include Deleted'),
          value: _includeDeleted,
          onChanged: (value) {
            setState(() {
              _includeDeleted = value;
            });
            _loadNotes();
          },
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _notes.isEmpty
                  ? const Center(child: Text('No notes found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notes.length,
                      itemBuilder: (context, index) {
                        final note = _notes[index];
                        return Card(
                          child: ExpansionTile(
                            title: Text('Note ID: ${note['client_note_id']}'),
                            subtitle: Text(
                              'Version: ${note['version']} | ${note['is_deleted'] ? 'DELETED' : 'Active'}',
                            ),
                            children: [
                              ListTile(
                                title: const Text('Metadata'),
                                subtitle: Text(note['metadata'].toString()),
                              ),
                              ListTile(
                                title: const Text('Updated'),
                                subtitle: Text(note['updated_at']),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// Encryption Tab
class _EncryptionTab extends StatefulWidget {
  final String userId;
  final Function(String, String) onCopy;

  const _EncryptionTab({required this.userId, required this.onCopy});

  @override
  State<_EncryptionTab> createState() => _EncryptionTabState();
}

class _EncryptionTabState extends State<_EncryptionTab> {
  final AdminApiService _adminApi = AdminApiService();
  Map<String, dynamic>? _encryptionKey;
  bool _isLoading = false;
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    _loadEncryptionKey();
  }

  Future<void> _loadEncryptionKey() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final key = await _adminApi.getUserEncryptionKey(widget.userId);
      setState(() {
        _encryptionKey = key;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_encryptionKey == null) {
      return const Center(child: Text('No encryption key found'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'CRITICAL: Encryption Key',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'This is EXTREMELY SENSITIVE data. With this key, all user notes can be decrypted.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Encryption Key (Base64)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(_showKey
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () {
                            setState(() {
                              _showKey = !_showKey;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            widget.onCopy(_encryptionKey!['encryption_key'],
                                'Encryption Key');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _showKey
                      ? _encryptionKey!['encryption_key']
                      : '••••••••••••••••',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Sync Tab
class _SyncTab extends StatefulWidget {
  final String userId;

  const _SyncTab({required this.userId});

  @override
  State<_SyncTab> createState() => _SyncTabState();
}

class _SyncTabState extends State<_SyncTab> {
  final AdminApiService _adminApi = AdminApiService();
  List<dynamic> _syncEvents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSyncEvents();
  }

  Future<void> _loadSyncEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _adminApi.getUserSyncEvents(widget.userId);
      setState(() {
        _syncEvents = response['sync_events'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_syncEvents.isEmpty) {
      return const Center(child: Text('No sync events found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _syncEvents.length,
      itemBuilder: (context, index) {
        final event = _syncEvents[index];
        return Card(
          child: ListTile(
            leading: Icon(
              event['status'] == 'success' ? Icons.check_circle : Icons.error,
              color: event['status'] == 'success' ? Colors.green : Colors.red,
            ),
            title: Text('Device: ${event['device_id']}'),
            subtitle: Text(
              'Notes: ${event['notes_synced']} | Status: ${event['status']}\n${event['sync_timestamp']}',
            ),
          ),
        );
      },
    );
  }
}

// Subscription Tab
class _SubscriptionTab extends StatefulWidget {
  final String userId;

  const _SubscriptionTab({required this.userId});

  @override
  State<_SubscriptionTab> createState() => _SubscriptionTabState();
}

class _SubscriptionTabState extends State<_SubscriptionTab> {
  final AdminApiService _adminApi = AdminApiService();
  List<dynamic> _subEvents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionEvents();
  }

  Future<void> _loadSubscriptionEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _adminApi.getUserSubscriptionEvents(widget.userId);
      setState(() {
        _subEvents = response['subscription_events'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_subEvents.isEmpty) {
      return const Center(child: Text('No subscription events found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subEvents.length,
      itemBuilder: (context, index) {
        final event = _subEvents[index];
        return Card(
          child: ListTile(
            title: Text('Event: ${event['event_type']}'),
            subtitle: Text(
              'Product: ${event['product_id']}\nPlatform: ${event['platform']}\nVerified: ${event['verified_at']}',
            ),
          ),
        );
      },
    );
  }
}

// Helper Widgets
class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
