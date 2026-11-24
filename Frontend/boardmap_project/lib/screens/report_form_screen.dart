import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/image_picker.dart';
import '../services/api_service.dart';

const _issueCategories = [
  'Account and Login Problems',
  'Boarding House Listing Issues',
  'Incorrect Property Information',
  'Map and Location Problems',
  'Inquiries and Messaging',
  'Technical Errors',
  'Security and Privacy Concerns',
  'Other',
];

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String? _category;
  PickedBoardMapImage? _attachment;
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    try {
      final picked = await pickBoardMapImages();
      if (!mounted || picked.isEmpty) return;
      final image = picked.first;
      final allowed = RegExp(
        r'\.(jpe?g|png|webp)$',
        caseSensitive: false,
      ).hasMatch(image.name);
      if (!allowed) {
        _showMessage(
          'Unsupported file format. Please upload JPG, PNG, or WEBP.',
        );
        return;
      }
      if (image.bytes.isEmpty || image.bytes.length > 5 * 1024 * 1024) {
        _showMessage('File size exceeds the 5 MB limit.');
        return;
      }
      setState(() => _attachment = image);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final report = await BoardMapApi.instance.submitIssueReport(
        category: _category!,
        subject: _subject.text.trim(),
        description: _description.text.trim(),
        filename: _attachment?.name,
        attachment: _attachment?.bytes,
      );
      if (!mounted) return;
      _formKey.currentState!.reset();
      _subject.clear();
      _description.clear();
      setState(() {
        _category = null;
        _attachment = null;
      });
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            Icons.check_circle_outline,
            color: Theme.of(dialogContext).colorScheme.primary,
            size: 42,
          ),
          title: const Text('Report submitted'),
          content: Text(
            'Your report has been submitted successfully. Reference: ${report['reference_number']}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pushNamed(context, '/reports/my');
              },
              child: const Text('View My Reports'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Issue'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/reports/my'),
            icon: const Icon(Icons.inbox_outlined),
            label: const Text('My Reports'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Text(
                  'Encountered a problem? Let us know so our team can help.',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Issue category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _issueCategories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  validator: (value) =>
                      value == null ? 'Please select an issue category.' : null,
                  onChanged: (value) => setState(() => _category = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _subject,
                  maxLength: 100,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'Briefly summarize the problem',
                    prefixIcon: Icon(Icons.short_text_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter a subject for your report.'
                      : null,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _description,
                  minLines: 5,
                  maxLines: 9,
                  maxLength: 2000,
                  inputFormatters: [LengthLimitingTextInputFormatter(2000)],
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    hintText: 'Please describe the issue you encountered and explain what happened.',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please describe the issue you encountered.'
                      : null,
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Screenshot or image (optional)',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'JPG, JPEG, PNG, or WEBP. Maximum 5 MB.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        if (_attachment == null)
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _pickAttachment,
                            icon: const Icon(Icons.attach_file),
                            label: const Text('Choose an image'),
                          )
                        else ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _attachment!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove attachment',
                                onPressed: _busy
                                    ? null
                                    : () => setState(() => _attachment = null),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _attachment!.bytes,
                              height: 200,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  const Text('Image preview unavailable.'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(_busy ? 'Submitting...' : 'Submit Report'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
