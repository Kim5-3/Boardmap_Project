import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/boarding_house.dart';
import '../widgets/boarding_house_image.dart';
import 'login_screen.dart';
import 'portal_feature_screens.dart';
import 'issue_reports_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _listings = [];
  List<Map<String, dynamic>> _activity = [];
  String _listingStatusFilter = 'All';
  String _accountFilter = 'renter';
  final _search = TextEditingController();
  final _listingsSectionKey = GlobalKey();
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  int _loadGeneration = 0;

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
    final generation = ++_loadGeneration;
    setState(() {
      _loading = _summary == null;
      _refreshing = _summary != null;
      _error = null;
    });
    try {
      final values = await Future.wait([
        BoardMapApi.instance.getAdminSummary(),
        BoardMapApi.instance.getAdminUsers(),
        BoardMapApi.instance.getAdminListings(),
        BoardMapApi.instance.getAdminActivity(pageSize: 5),
      ]);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _summary = values[0] as Map<String, dynamic>;
        _users = values[1] as List<Map<String, dynamic>>;
        _listings = values[2] as List<Map<String, dynamic>>;
        _activity = ((values[3] as Map<String, dynamic>)['items'] as List)
            .cast<Map<String, dynamic>>();
        _loading = false;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _setListingStatus(
    Map<String, dynamic> listing,
    String status,
  ) async {
    String? reason;
    if (status == 'Rejected') {
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Why is this listing rejected?'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason for the owner',
              hintText:
                  'Example: Please add a complete address and map location.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Send reason'),
            ),
          ],
        ),
      );
      reason = controller.text.trim();
      controller.dispose();
      if (confirmed != true || reason.isEmpty) {
        if (confirmed == true && mounted) {
          _showError('Enter a reason so the owner knows what to correct.');
        }
        return;
      }
    }
    try {
      final updated = await BoardMapApi.instance.updateAdminListingStatus(
        (listing['id'] as num).toInt(),
        status,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        final index = _listings.indexWhere((row) => row['id'] == listing['id']);
        if (index >= 0) _listings[index] = updated;
      });
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _logout() async {
    BoardMapApi.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BoardMap administration'),
        actions: [
          IconButton(
            tooltip: 'Reports and issues',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminIssueReportsScreen(),
              ),
            ),
            icon: const Icon(Icons.flag_outlined),
          ),
          IconButton(
            onPressed: _refreshing ? null : _load,
            tooltip: 'Refresh',
            icon: _refreshing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Settings')),
                  body: const BoardMapSettingsPage(),
                ),
              ),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            onPressed: _logout,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _summary == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: ListTile(
                        leading: Icon(Icons.sync_problem_outlined, color: Theme.of(context).colorScheme.onErrorContainer),
                        title: const Text('Some dashboard data could not be refreshed.'),
                        subtitle: Text(_error!),
                        trailing: TextButton(onPressed: _load, child: const Text('Retry')),
                      ),
                    ),
                  if (_summary case final summary?) ...[
                    _summaryCards(summary),
                    const SizedBox(height: 18),
                    _attentionPanel(summary),
                    const SizedBox(height: 18),
                  ],
                  _activityPanel(),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Search properties and people',
                      hintText: 'Name, email, address, or status',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () => setState(_search.clear),
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    key: _listingsSectionKey,
                    children: [
                      Expanded(
                        child: Text(
                          _listingStatusFilter == 'Pending'
                              ? 'Listings awaiting review'
                              : 'Listings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (_listingStatusFilter != 'All')
                        TextButton(
                          onPressed: () => setState(() => _listingStatusFilter = 'All'),
                          child: const Text('Clear status filter'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 4,
                    children: [
                      for (final status in const ['All', 'Pending', 'Approved', 'Rejected', 'Unavailable', 'Draft'])
                        ChoiceChip(
                          label: Text('$status (${_listingCountFor(status)})'),
                          selected: _listingStatusFilter == status,
                          onSelected: (_) => setState(() => _listingStatusFilter = status),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_visibleListings.isEmpty)
                    const Card(
                      child: ListTile(title: Text('No listings match this search and status filter.')),
                    ),
                  ..._visibleListings.map(_listingTile),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Text('Accounts', style: Theme.of(context).textTheme.titleLarge)),
                      Text('Showing ${_filteredUsers.length} of ${_accountCount(_accountFilter)} ${_accountLabel(_accountFilter).toLowerCase()} accounts',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  if (_summary != null &&
                      (_summary!['owners'] as num? ?? 0).toInt() != _accountCount('owner'))
                    Card(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      child: const ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Owner summary and account directory differ.'),
                        subtitle: Text('Refresh the dashboard. If the difference remains, review the account roles in the database before removing any account.'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    for (final type in const ['renter', 'owner', 'admin', 'unknown'])
                      ChoiceChip(
                        label: Text('${_accountLabel(type)} (${_accountCount(type)})'),
                        selected: _accountFilter == type,
                        onSelected: (_) => setState(() => _accountFilter = type),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  if (_filteredUsers.isEmpty)
                    Card(child: ListTile(title: Text('No ${_accountFilter.toLowerCase()} accounts found.'))),
                  ..._filteredUsers.map(_userTile),
                ],
              ),
            ),
    );
  }

  List<Map<String, dynamic>> get _visibleListings => _listings.where((listing) {
    final rawStatus = listing['status'] as String? ?? 'Pending';
    final status = rawStatus == 'Active' ? 'Approved' : rawStatus;
    final statusMatches = _listingStatusFilter == 'All' || status == _listingStatusFilter;
    return statusMatches && _listingMatchesSearch(listing);
  }).toList();

  int _listingCountFor(String status) => status == 'All'
      ? _listings.length
      : _listings.where((listing) {
          final rawStatus = listing['status'] as String? ?? 'Pending';
          return (rawStatus == 'Active' ? 'Approved' : rawStatus) == status;
        }).length;

  bool _listingMatchesSearch(Map<String, dynamic> listing) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      listing['name'],
      listing['location'],
      listing['owner_name'],
      listing['owner_email'],
      listing['status'],
    ].whereType<Object>().any((value) => value.toString().toLowerCase().contains(query));
  }

  List<Map<String, dynamic>> get _filteredUsers => _users
      .where((account) => _accountRole(account['role'] as String?) == _accountFilter)
      .where((account) {
        final query = _search.text.trim().toLowerCase();
        if (query.isEmpty) return true;
        return [account['full_name'], account['email'], account['username'], account['contact_number'], account['role']]
            .whereType<Object>()
            .any((value) => value.toString().toLowerCase().contains(query));
      })
      .toList();

  Widget _attentionPanel(Map<String, dynamic> summary) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Needs attention',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if ((summary['pending_listings'] as num? ?? 0) == 0 &&
              (summary['pending_reports'] as num? ?? 0) == 0)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.task_alt_outlined),
              title: Text('Everything is up to date.'),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _attentionAction(
                  label: 'Listings awaiting review',
                  count: summary['pending_listings'],
                  icon: Icons.home_work_outlined,
                  onTap: () {
                    setState(() => _listingStatusFilter = 'Pending');
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final target = _listingsSectionKey.currentContext;
                      if (target != null) {
                        Scrollable.ensureVisible(
                          target,
                          duration: const Duration(milliseconds: 250),
                        );
                      }
                    });
                  },
                ),
                _attentionAction(
                  label: 'Issue reports awaiting review',
                  count: summary['pending_reports'],
                  icon: Icons.flag_outlined,
                  onTap: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminIssueReportsScreen(
                            initialStatus: 'Pending',
                          ),
                        ),
                      )
                      .then((_) => _load()),
                ),
              ],
            ),
        ],
      ),
    ),
  );

  Widget _attentionAction({
    required String label,
    required Object? count,
    required IconData icon,
    required VoidCallback onTap,
  }) => SizedBox(
    width: 300,
    child: Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label),
        trailing: CircleAvatar(radius: 16, child: Text('${count ?? 0}')),
      ),
    ),
  );

  Widget _activityPanel() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent admin activity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdminActivityScreen(),
                  ),
                ),
                icon: const Icon(Icons.history),
                label: const Text('View activity log'),
              ),
            ],
          ),
          if (_activity.isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('No administrator actions have been recorded yet.'),
            )
          else
            for (final event in _activity)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text('${event['actor_name']} · ${event['action']}'),
                subtitle: Text(
                  '${event['target_label']}${event['previous_value'] == null ? '' : ' · ${event['previous_value']} → ${event['new_value']}'}\n${_activityDate(event['created_at'])}${event['description'] == null || (event['description'] as String).isEmpty ? '' : ' · ${event['description']}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        ],
      ),
    ),
  );

  String _activityDate(Object? value) {
    final date = value is String ? DateTime.tryParse(value)?.toLocal() : null;
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _summaryCards(Map<String, dynamic> summary) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          'Account totals include registered users. Owners with listings are counted separately.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _metric('Users', summary['users']),
          _metric('Owner accounts', summary['owners']),
          _metric('Owners with listings', summary['owners_with_listings']),
          _metric('Renters', summary['renters']),
          _metric('Listings', summary['listings']),
          _metric('Approved', summary['active_listings']),
          _metric('Inquiries', summary['inquiries']),
        ],
      ),
    ],
  );

  Widget _metric(String label, Object? value) => SizedBox(
    width: 150,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineSmall),
            Text(label),
          ],
        ),
      ),
    ),
  );

  Widget _listingTile(Map<String, dynamic> listing) => Card(
    child: ListTile(
      leading: BoardingHouseImage(
        house: BoardingHouse.fromJson(listing),
        width: 54,
        height: 54,
        borderRadius: BorderRadius.circular(8),
      ),
      title: Text(
        '${listing['name'] as String? ?? 'Boarding house'}${listing['rejection_reason'] == null ? '' : ' — ${listing['rejection_reason']}'}',
      ),
      subtitle: Text(
        "${listing['location'] ?? ''} | PHP ${listing['price'] ?? ''} | ${listing['available_rooms'] ?? 0} rooms | ${listing['latitude'] != null && listing['longitude'] != null ? 'map location set' : 'map location missing'}",
      ),
      trailing: DropdownButton<String>(
        value: listing['status'] == 'Active'
            ? 'Approved'
            : listing['status'] as String? ?? 'Pending',
        items: const ['Pending', 'Approved', 'Rejected', 'Unavailable', 'Draft']
            .map(
              (status) => DropdownMenuItem(value: status, child: Text(status)),
            )
            .toList(),
        onChanged: (status) {
          if (status != null) _setListingStatus(listing, status);
        },
      ),
    ),
  );

  Widget _userTile(Map<String, dynamic> account) => Card(
    child: ListTile(
      title: Text(account['full_name'] as String? ?? 'Account'),
      subtitle: Text([
        account['email'],
        account['contact_number'],
      ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' · ')),
      trailing: Chip(
        avatar: Icon(
          account['role'] == 'owner'
              ? Icons.home_work_outlined
              : account['role'] == 'admin'
              ? Icons.admin_panel_settings_outlined
              : Icons.person_outline,
          size: 18,
        ),
        label: Text(_accountLabel(_accountRole(account['role'] as String?))),
      ),
    ),
  );

  String _accountRole(String? role) => switch (role?.trim().toLowerCase()) {
    'owner' || 'property owner' || 'property_owner' => 'owner',
    'admin' || 'administrator' => 'admin',
    'renter' => 'renter',
    _ => 'unknown',
  };

  String _accountLabel(String role) => switch (role) {
    'owner' => 'Owner',
    'admin' => 'Administrator',
    'renter' => 'Renter',
    _ => 'Other',
  };

  int _accountCount(String role) => _users
      .where((account) => _accountRole(account['role'] as String?) == role)
      .length;
}
