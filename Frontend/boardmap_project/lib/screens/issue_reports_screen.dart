import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

const _reportStatuses = [
  'All',
  'Pending',
  'Under Review',
  'Resolved',
  'Rejected',
];
const _reportCategories = [
  'Account and Login Problems',
  'Boarding House Listing Issues',
  'Incorrect Property Information',
  'Map and Location Problems',
  'Inquiries and Messaging',
  'Technical Errors',
  'Security and Privacy Concerns',
  'Other',
];

String _dateLabel(Object? value) {
  if (value is! String) return '';
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
}

Color _statusColor(BuildContext context, String status) {
  final colors = Theme.of(context).colorScheme;
  return switch (status) {
    'Resolved' => colors.primary,
    'Rejected' => colors.error,
    'Under Review' => colors.tertiary,
    _ => colors.secondary,
  };
}

class MyIssueReportsScreen extends StatefulWidget {
  const MyIssueReportsScreen({super.key});

  @override
  State<MyIssueReportsScreen> createState() => _MyIssueReportsScreenState();
}

class _MyIssueReportsScreenState extends State<MyIssueReportsScreen> {
  final _search = TextEditingController();
  String _status = 'All';
  int _page = 1;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await BoardMapApi.instance.getMyIssueReports(
        status: _status,
        search: _search.text,
        page: _page,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = (_result?['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final total = (_result?['total'] as num?)?.toInt() ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const IssueNotificationsScreen(),
              ),
            ),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Track your reports and read support replies.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _search,
                  onSubmitted: (_) {
                    _page = 1;
                    _load();
                  },
                  decoration: InputDecoration(
                    labelText: 'Search by subject',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: () {
                        _search.clear();
                        _page = 1;
                        _load();
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _reportStatuses
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _status = value;
                        _page = 1;
                      });
                    }
                    _load();
                  },
                ),
              ),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context)
                        .pushNamed('/report')
                        .then((_) => _load()),
                icon: const Icon(Icons.add),
                label: const Text('Submit a report'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: const Text('Reports could not be loaded'),
                subtitle: Text(_error!),
                trailing: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            )
          else if (items.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 42, color: colors.primary),
                    const SizedBox(height: 10),
                    const Text("You haven't submitted any reports yet."),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context)
                              .pushNamed('/report')
                              .then((_) => _load()),
                      child: const Text('Submit a Report'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            for (final report in items)
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.support_agent_outlined,
                    color: colors.primary,
                  ),
                  title: Text(
                    report['subject'] as String? ?? 'Issue report',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${report['reference_number']}  |  ${report['category']}\nSubmitted ${_dateLabel(report['created_at'])}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: _StatusPill(
                    status: report['status'] as String? ?? 'Pending',
                  ),
                  onTap: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute<void>(
                          builder: (_) => IssueReportDetailScreen(
                            reportId: (report['id'] as num).toInt(),
                          ),
                        ),
                      )
                      .then((_) => _load()),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _page > 1
                      ? () {
                          setState(() => _page--);
                          _load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Page $_page of ${((total + 19) ~/ 20).clamp(1, 9999)}'),
                IconButton(
                  onPressed: _page * 20 < total
                      ? () {
                          setState(() => _page++);
                          _load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class IssueReportDetailScreen extends StatefulWidget {
  const IssueReportDetailScreen({super.key, required this.reportId});
  final int reportId;

  @override
  State<IssueReportDetailScreen> createState() =>
      _IssueReportDetailScreenState();
}

class _IssueReportDetailScreenState extends State<IssueReportDetailScreen> {
  late Future<Map<String, dynamic>> _report = BoardMapApi.instance
      .getIssueReport(widget.reportId);
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    if (_reply.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await BoardMapApi.instance.replyToIssueReport(
        widget.reportId,
        _reply.text.trim(),
      );
      _reply.clear();
      setState(
        () => _report = BoardMapApi.instance.getIssueReport(widget.reportId),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Report details')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _report,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final report = snapshot.data!;
        final messages = (report['messages'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        final history = (report['history'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report['subject'] as String? ?? '',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        _StatusPill(
                          status: report['status'] as String? ?? 'Pending',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${report['reference_number']}  |  ${report['category']}',
                    ),
                    Text(
                      'Submitted ${_dateLabel(report['created_at'])}  |  Updated ${_dateLabel(report['updated_at'])}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Divider(height: 24),
                    Text(report['description'] as String? ?? ''),
                    if (report['attachment_url'] != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Attachment: ${report['attachment_filename'] ?? 'Image'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      _PrivateReportImage(reportId: widget.reportId),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Status history',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            for (final event in history)
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.history,
                    color: _statusColor(
                      context,
                      event['new_status'] as String? ?? 'Pending',
                    ),
                  ),
                  title: Text(
                    '${event['new_status']} by ${event['changed_by_name'] ?? 'BoardMap'}',
                  ),
                  subtitle: Text(
                    '${_dateLabel(event['created_at'])}${event['remarks'] == null ? '' : '\n${event['remarks']}'}',
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Text(
              'Conversation',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (messages.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('No replies yet.'),
                  subtitle: Text('Our support team will respond here.'),
                ),
              ),
            for (final message in messages)
              Card(
                child: ListTile(
                  leading: Icon(
                    message['sender_role'] == 'admin'
                        ? Icons.support_agent
                        : Icons.person_outline,
                  ),
                  title: Text(
                    message['sender_name'] as String? ?? 'BoardMap user',
                  ),
                  subtitle: Text(
                    '${message['message']}\n${_dateLabel(message['created_at'])}',
                  ),
                ),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _reply,
              minLines: 2,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Send a follow-up',
                hintText: 'Add information or reply to support',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _sending ? null : _sendReply,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('Send message'),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _PrivateReportImage extends StatefulWidget {
  const _PrivateReportImage({required this.reportId});
  final int reportId;
  @override
  State<_PrivateReportImage> createState() => _PrivateReportImageState();
}

class _PrivateReportImageState extends State<_PrivateReportImage> {
  late final Future<Uint8List> _bytes = BoardMapApi.instance
      .getIssueReportAttachment(widget.reportId);
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Text('Attachment could not be loaded: ${snapshot.error}');
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          snapshot.data!,
          height: 260,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Text('Preview unavailable.'),
        ),
      );
    },
  );
}

class AdminIssueReportsScreen extends StatefulWidget {
  const AdminIssueReportsScreen({super.key, this.initialStatus = 'All'});

  final String initialStatus;
  @override
  State<AdminIssueReportsScreen> createState() =>
      _AdminIssueReportsScreenState();
}

class _AdminIssueReportsScreenState extends State<AdminIssueReportsScreen> {
  final _search = TextEditingController();
  late String _status = widget.initialStatus;
  String _category = 'All';
  DateTime? _startDate, _endDate;
  int _page = 1;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _statistics = {};
  Map<String, dynamic> _result = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        BoardMapApi.instance.getAdminIssueReportStatistics(),
        BoardMapApi.instance.getAdminIssueReports(
          status: _status,
          category: _category,
          search: _search.text,
          startDate: _startDate?.toIso8601String().split('T').first,
          endDate: _endDate?.toIso8601String().split('T').first,
          page: _page,
        ),
      ]);
      if (mounted) {
        setState(() {
          _statistics = values[0];
          _result = values[1];
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = (start ? _startDate : _endDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
      _page = 1;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = (_result['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final total = (_result['total'] as num?)?.toInt() ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Issues'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const IssueNotificationsScreen(),
              ),
            ),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AdminReportMetric(
                  label: 'Total Reports',
                  value: _statistics['total'],
                ),
                _AdminReportMetric(
                  label: 'Pending',
                  value: _statistics['pending'],
                ),
                _AdminReportMetric(
                  label: 'Under Review',
                  value: _statistics['under_review'],
                ),
                _AdminReportMetric(
                  label: 'Resolved',
                  value: _statistics['resolved'],
                ),
                _AdminReportMetric(
                  label: 'Rejected',
                  value: _statistics['rejected'],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) {
                      _page = 1;
                      _load();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search reports',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: _reportStatuses
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _status = value;
                          _page = 1;
                        });
                      }
                      _load();
                    },
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: ['All', ..._reportCategories]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _category = value;
                          _page = 1;
                        });
                      }
                      _load();
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(start: true),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    _startDate == null
                        ? 'From date'
                        : _startDate!.toIso8601String().split('T').first,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(start: false),
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _endDate == null
                        ? 'To date'
                        : _endDate!.toIso8601String().split('T').first,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                      _page = 1;
                    });
                    _load();
                  },
                  child: const Text('Clear dates'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: ListTile(
                  title: const Text('Reports could not be loaded'),
                  subtitle: Text(_error!),
                  trailing: IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              )
            else if (items.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.inbox_outlined),
                  title: Text('No issue reports match these filters.'),
                ),
              )
            else ...[
              for (final report in items)
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.flag_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      '#${report['id']}  •  ${report['subject']}  •  ${report['reference_number']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${report['reporter_name'] ?? 'User'} (@${report['reporter_username'] ?? ''})  |  ${report['reporter_role'] ?? ''}\n${report['category']}  |  ${_dateLabel(report['created_at'])}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    trailing: _StatusPill(
                      status: report['status'] as String? ?? 'Pending',
                    ),
                    onTap: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute<void>(
                            builder: (_) => AdminIssueReportDetailScreen(
                              reportId: (report['id'] as num).toInt(),
                            ),
                          ),
                        )
                        .then((_) => _load()),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _page > 1
                        ? () {
                            setState(() => _page--);
                            _load();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Page $_page of ${((total + 19) ~/ 20).clamp(1, 9999)}'),
                  IconButton(
                    onPressed: _page * 20 < total
                        ? () {
                            setState(() => _page++);
                            _load();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AdminIssueReportDetailScreen extends StatefulWidget {
  const AdminIssueReportDetailScreen({super.key, required this.reportId});
  final int reportId;
  @override
  State<AdminIssueReportDetailScreen> createState() =>
      _AdminIssueReportDetailScreenState();
}

class _AdminIssueReportDetailScreenState
    extends State<AdminIssueReportDetailScreen> {
  late Future<Map<String, dynamic>> _report = BoardMapApi.instance
      .getAdminIssueReport(widget.reportId);
  final _response = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _response.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(
      () => _report = BoardMapApi.instance.getAdminIssueReport(widget.reportId),
    );
    await _report;
  }

  Future<void> _respond() async {
    if (_response.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await BoardMapApi.instance.respondToAdminIssueReport(
        widget.reportId,
        _response.text.trim(),
      );
      _response.clear();
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> report) async {
    final current = report['status'] as String? ?? 'Pending';
    final available = switch (current) {
      'Pending' => ['Under Review', 'Rejected'],
      'Under Review' => ['Resolved', 'Rejected'],
      _ => <String>[],
    };
    if (available.isEmpty) return;
    var selection = available.first;
    final reason = TextEditingController();
    var missingReason = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update report status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selection,
                items: available
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() {
                      selection = value;
                      missingReason = false;
                    });
                  }
                },
              ),
              if (selection == 'Rejected') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (_) {
                    if (missingReason) {
                      setDialogState(() => missingReason = false);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Reason for rejection',
                    hintText: 'Explain why this report is rejected.',
                    errorText: missingReason
                        ? 'A rejection reason is required.'
                        : null,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (selection == 'Rejected' && reason.text.trim().isEmpty) {
                  setDialogState(() => missingReason = true);
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      reason.dispose();
      return;
    }
    setState(() => _busy = true);
    try {
      await BoardMapApi.instance.updateAdminIssueReportStatus(
        widget.reportId,
        selection,
        remarks: reason.text.trim().isEmpty ? null : reason.text.trim(),
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      reason.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Issue report details')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _report,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final report = snapshot.data!;
        final messages = (report['messages'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        final history = (report['history'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report['subject'] as String? ?? '',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        _StatusPill(
                          status: report['status'] as String? ?? 'Pending',
                        ),
                      ],
                    ),
                    Text(
                      '${report['reference_number']}  |  ${report['category']}',
                    ),
                    Text(
                      '${report['reporter_name']} (@${report['reporter_username']})  |  ${report['reporter_role']}  |  ${report['reporter_email']}',
                    ),
                    Text(
                      'Submitted ${_dateLabel(report['created_at'])}  |  Updated ${_dateLabel(report['updated_at'])}',
                    ),
                    const Divider(height: 24),
                    Text(report['description'] as String? ?? ''),
                    if (report['attachment_url'] != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Attachment: ${report['attachment_filename'] ?? 'Image'}',
                      ),
                      _PrivateReportImage(reportId: widget.reportId),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      children: [
                        if ([
                          'Pending',
                          'Under Review',
                        ].contains(report['status']))
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _updateStatus(report),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Update status'),
                          ),
                        if (report['status'] == 'Pending')
                          FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () async {
                                    setState(() => _busy = true);
                                    try {
                                      await BoardMapApi.instance
                                          .updateAdminIssueReportStatus(
                                            widget.reportId,
                                            'Under Review',
                                          );
                                      await _refresh();
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _busy = false);
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.manage_search),
                            label: const Text('Start review'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Status history',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            for (final event in history)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(
                    '${event['new_status']} by ${event['changed_by_name']}',
                  ),
                  subtitle: Text(
                    '${_dateLabel(event['created_at'])}${event['remarks'] == null ? '' : '\n${event['remarks']}'}',
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Text(
              'Conversation',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            for (final message in messages)
              Card(
                child: ListTile(
                  leading: Icon(
                    message['sender_role'] == 'admin'
                        ? Icons.support_agent
                        : Icons.person_outline,
                  ),
                  title: Text(
                    '${message['sender_name']} (${message['sender_role']})',
                  ),
                  subtitle: Text(
                    '${message['message']}\n${_dateLabel(message['created_at'])}',
                  ),
                ),
              ),
            TextField(
              controller: _response,
              minLines: 2,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Administrator response',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _busy ? null : _respond,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Send response'),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class AdminActivityScreen extends StatefulWidget {
  const AdminActivityScreen({super.key});

  @override
  State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends State<AdminActivityScreen> {
  int _page = 1;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _result = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await BoardMapApi.instance.getAdminActivity(page: _page);
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = (_result['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final total = (_result['total'] as num?)?.toInt() ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin activity log'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'A record of administrator listing decisions, report status changes, and support replies.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: ListTile(
                  title: const Text('Activity could not be loaded'),
                  subtitle: Text(_error!),
                  trailing: IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              )
            else if (items.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('No admin activity has been recorded yet.'),
                ),
              )
            else ...[
              for (final event in items)
                Card(
                  child: ListTile(
                    leading: Icon(
                      event['target_type'] == 'report'
                          ? Icons.flag_outlined
                          : Icons.home_work_outlined,
                    ),
                    title: Text(
                      '${event['action']} - ${event['target_label']}',
                    ),
                    subtitle: Text(
                      '${event['actor_name']} (${event['actor_role']}) | ${_dateLabel(event['created_at'])}'
                      '${event['previous_value'] == null ? '' : '\n${event['previous_value']} -> ${event['new_value']}'}'
                      '${event['description'] == null || (event['description'] as String).isEmpty ? '' : '\n${event['description']}'}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _page > 1
                        ? () {
                            setState(() => _page--);
                            _load();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Page $_page of ${((total + 19) ~/ 20).clamp(1, 9999)}'),
                  IconButton(
                    onPressed: _page * 20 < total
                        ? () {
                            setState(() => _page++);
                            _load();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminReportMetric extends StatelessWidget {
  const _AdminReportMetric({required this.label, required this.value});
  final String label;
  final Object? value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${value ?? 0}',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class IssueNotificationsScreen extends StatefulWidget {
  const IssueNotificationsScreen({super.key});

  @override
  State<IssueNotificationsScreen> createState() =>
      _IssueNotificationsScreenState();
}

class _IssueNotificationsScreenState extends State<IssueNotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _notifications = BoardMapApi.instance
      .getMyNotifications();

  Future<void> _open(Map<String, dynamic> notification) async {
    final id = (notification['id'] as num).toInt();
    final reportId = (notification['report_id'] as num?)?.toInt();
    try {
      if (notification['read_at'] == null) {
        await BoardMapApi.instance.markNotificationRead(id);
        if (mounted) {
          setState(
            () => _notifications = BoardMapApi.instance.getMyNotifications(),
          );
        }
      }
      if (!mounted || reportId == null) return;
      final isAdmin = BoardMapApi.instance.user?['role'] == 'admin';
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => isAdmin
              ? AdminIssueReportDetailScreen(reportId: reportId)
              : IssueReportDetailScreen(reportId: reportId),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => setState(
            () => _notifications = BoardMapApi.instance.getMyNotifications(),
          ),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _notifications,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Notifications could not be loaded: ${snapshot.error}'),
                TextButton(
                  onPressed: () => setState(
                    () => _notifications = BoardMapApi.instance
                        .getMyNotifications(),
                  ),
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const Center(child: Text('You’re all caught up.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final unread = item['read_at'] == null;
            return Card(
              child: ListTile(
                leading: Icon(
                  unread
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none_outlined,
                  color: unread
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(item['title'] as String? ?? 'BoardMap update'),
                subtitle: Text(
                  '${item['message'] ?? ''}\n${_dateLabel(item['created_at'])}',
                ),
                isThreeLine: true,
                onTap: () => _open(item),
              ),
            );
          },
        );
      },
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
