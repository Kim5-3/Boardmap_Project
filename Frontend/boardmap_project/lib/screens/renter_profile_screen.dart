import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/change_password_card.dart';
import '../widgets/profile_photo_editor.dart';

class RenterProfileScreen extends StatefulWidget {
  const RenterProfileScreen({super.key});

  @override
  State<RenterProfileScreen> createState() => _RenterProfileScreenState();
}

class _RenterProfileScreenState extends State<RenterProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = BoardMapApi.instance.user;
    _name.text = user?['full_name'] as String? ?? '';
    _email.text = user?['email'] as String? ?? '';
    _contact.text = user?['contact_number'] as String? ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await BoardMapApi.instance.updateMe(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        contactNumber: _contact.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Renter Profile',
        style: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 16),
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const ProfilePhotoEditor(),
              const SizedBox(height: 8),
              Text('Account type: ${BoardMapApi.instance.user?['role'] ?? 'Renter'}'),
              Text('Member since: ${(BoardMapApi.instance.user?['created_at'] as String? ?? '').split('T').first}'),
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contact,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save profile'),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      const ChangePasswordCard(),
    ],
  );
}
