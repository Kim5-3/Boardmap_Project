import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme_controller.dart';
import '../widgets/change_password_card.dart';
import '../widgets/profile_photo_editor.dart';

class OwnerAnalyticsPage extends StatelessWidget {
  const OwnerAnalyticsPage({
    super.key,
    required this.listingCount,
    required this.roomCount,
    required this.inquiryCount,
  });
  final int listingCount, roomCount, inquiryCount;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const Text(
        'Analytics',
        style: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w900,
        ),
      ),
      const Text(
        'Verified totals from your account.',
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricCard(
            label: 'Total listings',
            value: '$listingCount',
            icon: Icons.home_work_outlined,
          ),
          _MetricCard(
            label: 'Rooms listed available',
            value: '$roomCount',
            icon: Icons.bed_outlined,
          ),
          _MetricCard(
            label: 'Open inquiries',
            value: '$inquiryCount',
            icon: Icons.mail_outline,
          ),
        ],
      ),
      const SizedBox(height: 16),
      Card(
        elevation: 0,
        child: ListTile(
          leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
          title: Text('Property view analytics are not available yet.'),
          subtitle: Text(
            'BoardMap does not currently record listing views, so no view chart is shown.',
          ),
        ),
      ),
      const SizedBox(height: 16),
      const ChangePasswordCard(),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(label),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class OwnerProfilePage extends StatefulWidget {
  const OwnerProfilePage({super.key});
  @override
  State<OwnerProfilePage> createState() => _OwnerProfilePageState();
}

class _OwnerProfilePageState extends State<OwnerProfilePage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  @override
  void initState() {
    super.initState();
    _name.text = BoardMapApi.instance.user?['full_name'] as String? ?? '';
    _email.text = BoardMapApi.instance.user?['email'] as String? ?? '';
    _contact.text =
        BoardMapApi.instance.user?['contact_number'] as String? ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Owner Profile',
        style: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(
            BoardMapApi.instance.user?['full_name'] as String? ??
                'BoardMap account',
          ),
          subtitle: Text(
            '${BoardMapApi.instance.user?['role'] ?? 'Account'} · ${BoardMapApi.instance.user?['email'] ?? ''}',
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: ProfilePhotoEditor()),
              const SizedBox(height: 12),
              Text(
                'Account type: ${BoardMapApi.instance.user?['role'] ?? 'Owner'}',
              ),
              Text(
                'Member since: ${(BoardMapApi.instance.user?['created_at'] as String? ?? '').split('T').first}',
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Owner account',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (final item in <(String, TextEditingController)>[
                ('Full name', _name),
                ('Email address', _email),
                ('Contact number', _contact),
              ]) ...[
                TextField(
                  controller: item.$2,
                  decoration: InputDecoration(
                    labelText: item.$1,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () async {
                    try {
                      await BoardMapApi.instance.updateMe(
                        fullName: _name.text.trim(),
                        email: _email.text.trim(),
                        contactNumber: _contact.text.trim(),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile updated.')),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class BoardMapSettingsPage extends StatelessWidget {
  const BoardMapSettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = BoardMapThemeController.instance;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  'Appearance',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('This choice is saved on this device.'),
              ),
              AnimatedBuilder(
                animation: theme,
                builder: (context, _) => RadioGroup<ThemeMode>(
                  groupValue: theme.mode,
                  onChanged: (value) {
                    if (value != null) theme.setMode(value);
                  },
                  child: Column(
                    children: [
                      for (final option in const <(ThemeMode, String, String)>[
                        (
                          ThemeMode.system,
                          'Use device setting',
                          'Follow your device appearance.',
                        ),
                        (
                          ThemeMode.light,
                          'Light mode',
                          'Use a light background.',
                        ),
                        (ThemeMode.dark, 'Dark mode', 'Use a dark background.'),
                      ])
                        RadioListTile<ThemeMode>(
                          value: option.$1,
                          title: Text(option.$2),
                          subtitle: Text(option.$3),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account photo',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 10),
                Center(child: ProfilePhotoEditor()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.notifications_off_outlined),
            title: Text('Notifications are unavailable'),
            subtitle: Text(
              'BoardMap does not send email or push notifications yet. Listing messages are shown in your dashboard.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Privacy and security'),
            subtitle: Text(
              'Your account uses a protected sign-in session. Sign out when using a shared device.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.help_outline),
            title: Text('Help and support'),
            subtitle: Text(
              'For assistance, contact the BoardMap project team through your course adviser.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        const ChangePasswordCard(),
      ],
    );
  }
}

class OwnerInquiriesPage extends StatefulWidget {
  const OwnerInquiriesPage({super.key});
  @override
  State<OwnerInquiriesPage> createState() => _OwnerInquiriesPageState();
}

class _OwnerInquiriesPageState extends State<OwnerInquiriesPage> {
  final _reply = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  int? _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await BoardMapApi.instance.getOwnerInquiries();
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
          _selected = items.isEmpty
              ? null
              : (_selected ?? 0).clamp(0, items.length - 1);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _send() async {
    final id = _items[_selected ?? 0]['id'] as int?;
    final response = _reply.text.trim();
    if (id == null || response.isEmpty) return;
    try {
      await BoardMapApi.instance.respondToInquiry(id, response);
      _reply.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No inquiries received yet.'));
    }
    final item = _items[_selected ?? 0];
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Owner inquiries',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) {
                final row = _items[i];
                return ListTile(
                  selected: _selected == i,
                  title: Text(
                    '${row['house_name'] ?? 'Listing'} · ${row['renter_name'] ?? 'Renter'}',
                  ),
                  subtitle: Text(row['message']?.toString() ?? ''),
                  onTap: () => setState(() => _selected = i),
                );
              },
            ),
          ),
          if (item['response'] != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Your response: ${item['response']}'),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _reply,
                  decoration: const InputDecoration(
                    labelText: 'Reply to renter',
                  ),
                ),
              ),
              IconButton(onPressed: _send, icon: const Icon(Icons.send)),
            ],
          ),
        ],
      ),
    );
  }
}
