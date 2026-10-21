import 'package:flutter/material.dart';

import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

enum ReportUiState { idle, loading, success, empty, error }

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<_ReportRecord> _reports = [];

  ReportUiState _state = ReportUiState.empty;
  bool _simulateFailure = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> submitReport({bool validate = true}) async {
    if (_state == ReportUiState.loading) return;
    if (validate && !(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _state = ReportUiState.loading;
      _errorMessage = null;
    });

    try {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (_simulateFailure) {
        throw StateError('The demo network request was interrupted.');
      }

      _reports.add(_ReportRecord(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        submittedAt: DateTime.now(),
      ));
      if (!mounted) return;
      setState(() => _state = ReportUiState.success);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error is StateError
            ? error.message.toString()
            : 'We could not submit your report. Please try again.';
        _state = ReportUiState.error;
      });
    }
  }

  void _startReport() {
    _titleController.clear();
    _descriptionController.clear();
    _formKey.currentState?.reset();
    setState(() {
      _errorMessage = null;
      _state = ReportUiState.idle;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an issue'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _buildStateView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateView() {
    switch (_state) {
      case ReportUiState.empty:
        if (_reports.isNotEmpty) return _reportsView();
        return _messageView(
          key: const ValueKey(ReportUiState.empty),
          icon: Icons.inbox_outlined,
          title: 'No reports found',
          message: 'You have not submitted any reports yet.',
          action: AppButton(
            label: 'Create a report',
            icon: Icons.add_rounded,
            onPressed: _startReport,
          ),
        );
      case ReportUiState.loading:
        return _messageView(
          key: const ValueKey(ReportUiState.loading),
          icon: Icons.cloud_upload_outlined,
          title: 'Submitting your report',
          message: 'Please wait while we send your information.',
          action: const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          ),
        );
      case ReportUiState.success:
        return _messageView(
          key: const ValueKey(ReportUiState.success),
          icon: Icons.check_circle_outline_rounded,
          title: 'Report submitted',
          message: 'Your report was added to your reports list.',
          action: Column(
            children: [
              AppButton(
                label: 'Submit another report',
                icon: Icons.add_rounded,
                onPressed: _startReport,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Return to BoardMap'),
              ),
              TextButton(
                onPressed: () => setState(() => _state = ReportUiState.empty),
                child: const Text('View my reports'),
              ),
            ],
          ),
        );
      case ReportUiState.error:
        return _messageView(
          key: const ValueKey(ReportUiState.error),
          icon: Icons.error_outline_rounded,
          title: 'Could not submit report',
          message: _errorMessage ?? 'Please check your connection and retry.',
          action: Column(
            children: [
              AppButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: () => submitReport(validate: false),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => setState(() => _state = ReportUiState.idle),
                child: const Text('Edit report'),
              ),
            ],
          ),
        );
      case ReportUiState.idle:
        return _formView();
    }
  }

  Widget _formView() {
    return SingleChildScrollView(
      key: const ValueKey(ReportUiState.idle),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE0E9E2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tell us what happened',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share a problem with a listing or your BoardMap experience.',
                  style: TextStyle(color: Colors.blueGrey),
                ),
                const SizedBox(height: 22),
                AppTextField(
                  controller: _titleController,
                  label: 'Report title',
                  hint: 'Briefly describe the issue',
                  prefixIcon: Icons.title_rounded,
                  enabled: _state != ReportUiState.loading,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a report title.'
                      : value.trim().length < 4
                          ? 'Use at least 4 characters.'
                          : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Include details that can help us investigate',
                  prefixIcon: Icons.description_outlined,
                  maxLines: 5,
                  enabled: _state != ReportUiState.loading,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a description.'
                      : value.trim().length < 10
                          ? 'Add a little more detail (at least 10 characters).'
                          : null,
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Simulate a network error'),
                  subtitle: const Text('Demo control for the Error and Retry states.'),
                  value: _simulateFailure,
                  onChanged: (value) => setState(() => _simulateFailure = value),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Submit report',
                  icon: Icons.send_rounded,
                  isLoading: _state == ReportUiState.loading,
                  onPressed: _state == ReportUiState.loading ? null : submitReport,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reportsView() {
    return Column(
      key: const ValueKey('reports-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your reports',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: _reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final report = _reports[index];
              return Card(
                elevation: 0,
                child: ListTile(
                  leading: const Icon(Icons.assignment_outlined),
                  title: Text(report.title),
                  subtitle: Text(report.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Text(
                    '${report.submittedAt.month}/${report.submittedAt.day}',
                    style: const TextStyle(color: Colors.blueGrey),
                  ),
                ),
              );
            },
          ),
        ),
        AppButton(
          label: 'Create another report',
          icon: Icons.add_rounded,
          onPressed: _startReport,
        ),
      ],
    );
  }

  Widget _messageView({
    required Key key,
    required IconData icon,
    required String title,
    required String message,
    required Widget action,
  }) {
    return Center(
      key: key,
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE0E9E2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54, color: const Color(0xFF218653)),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 22),
              SizedBox(width: double.infinity, child: action),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportRecord {
  const _ReportRecord({
    required this.title,
    required this.description,
    required this.submittedAt,
  });

  final String title;
  final String description;
  final DateTime submittedAt;
}
