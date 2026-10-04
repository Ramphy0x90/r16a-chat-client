import 'package:flutter/material.dart';
import 'package:r16a_chat_client/core/zmey_progress.dart';
import 'package:r16a_chat_client/core/zmey_text_field.dart';

class ProfileForm extends StatefulWidget {
  final String? initialDisplayName;
  final String userId;
  final void Function(String displayName) onSave;
  final VoidCallback onCopyUserId;
  final bool isSaving;
  final String? errorMessage;

  const ProfileForm({
    super.key,
    required this.initialDisplayName,
    required this.userId,
    required this.onSave,
    required this.onCopyUserId,
    this.isSaving = false,
    this.errorMessage,
  });

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late final _nameController = TextEditingController(
    text: widget.initialDisplayName ?? '',
  );

  @override
  void initState() {
    super.initState();
    // Rebuild so the Save button tracks whether the name changed.
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // After a successful save the screen passes the new name back in.
    if (widget.initialDisplayName != oldWidget.initialDisplayName) {
      _nameController.text = widget.initialDisplayName ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _nameController.text.trim() != (widget.initialDisplayName ?? '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 40,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 25,
          children: [
            ZmeyTextField(
              label: 'Display name',
              controller: _nameController,
              disabled: widget.isSaving,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 5,
              children: [
                Text('User ID', style: theme.textTheme.labelMedium),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        widget.userId,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy user ID',
                      icon: Icon(
                        Icons.copy,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      onPressed: widget.onCopyUserId,
                    ),
                  ],
                ),
              ],
            ),
            if (widget.errorMessage != null && widget.errorMessage!.isNotEmpty)
              Text(widget.errorMessage!, style: TextStyle(color: colors.error)),
          ],
        ),
        ElevatedButton(
          // Via styleFrom so the disabled state (unchanged name) keeps a readable label.
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.surface,
          ),
          onPressed: widget.isSaving || !_hasChanges ? null : _handleSave,
          child: widget.isSaving
              ? ZmeyProgress(color: colors.secondary)
              : const Text('Save'),
        ),
      ],
    );
  }

  void _handleSave() {
    widget.onSave(_nameController.text.trim());
  }
}
