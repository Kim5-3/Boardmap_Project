import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/image_picker.dart';
import '../services/api_service.dart';

class ProfilePhotoEditor extends StatefulWidget {
  const ProfilePhotoEditor({super.key});

  @override
  State<ProfilePhotoEditor> createState() => _ProfilePhotoEditorState();
}

class _ProfilePhotoEditorState extends State<ProfilePhotoEditor> {
  Uint8List? _preview;
  String? _filename;
  bool _busy = false;

  Future<void> _choose() async {
    try {
      final picked = await pickBoardMapImages();
      if (!mounted || picked.isEmpty) return;
      final photo = picked.first;
      final supported = RegExp(r'\.(png|jpe?g|webp)$', caseSensitive: false).hasMatch(photo.name);
      if (!supported || photo.bytes.isEmpty || photo.bytes.length > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a PNG, JPG, or WebP photo under 5 MB.')));
        return;
      }
      setState(() { _preview = photo.bytes; _filename = photo.name; });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open that photo: $error')));
    }
  }

  Future<void> _save() async {
    final bytes = _preview;
    final filename = _filename;
    if (bytes == null || filename == null || _busy) return;
    setState(() => _busy = true);
    try {
      await BoardMapApi.instance.uploadProfilePhoto(filename, bytes);
      if (!mounted) return;
      setState(() { _preview = null; _filename = null; _busy = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _remove() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await BoardMapApi.instance.deleteProfilePhoto();
      if (!mounted) return;
      setState(() { _preview = null; _filename = null; _busy = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo removed.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = BoardMapApi.instance.user?['profile_photo_url'] as String?;
    final provider = _preview != null
        ? MemoryImage(_preview!) as ImageProvider
        : url == null
        ? null
        : NetworkImage(BoardMapApi.urlFor(url).toString());
    return Column(children: [
      CircleAvatar(
        radius: 38,
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        backgroundImage: provider,
        child: provider == null ? const Icon(Icons.person_outline, size: 38) : null,
      ),
      const SizedBox(height: 8),
      if (_preview != null)
        Text(_filename ?? 'Selected photo', style: Theme.of(context).textTheme.bodySmall),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 4, children: [
        OutlinedButton.icon(onPressed: _busy ? null : _choose, icon: const Icon(Icons.photo_camera_back_outlined), label: Text(url == null ? 'Choose photo' : 'Replace photo')),
        if (_preview != null) FilledButton.icon(onPressed: _busy ? null : _save, icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('Save photo')),
        if (url != null) TextButton.icon(onPressed: _busy ? null : _remove, icon: const Icon(Icons.delete_outline), label: const Text('Remove')),
      ]),
      const Text('PNG, JPG, or WebP · up to 5 MB', style: TextStyle(fontSize: 12)),
    ]);
  }
}
