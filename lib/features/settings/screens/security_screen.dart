import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/core/detail_scaffold.dart';
import 'package:r16a_chat_client/features/settings/widgets/recovery_key_card.dart';
import 'package:r16a_chat_client/features/settings/widgets/recovery_status_card.dart';
import 'package:r16a_chat_client/src/rust/api/recovery.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  /// The cards stay readable on wide (desktop) panes instead of stretching.
  static const _maxContentWidth = 560.0;

  RecoveryStatus? _status;
  bool _isWorking = false;
  String? _errorMessage;

  /// A key just created, shown until the user confirms they saved it. Only
  /// kept in memory here; never logged or persisted.
  String? _newKey;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final newKey = _newKey;

    return DetailScaffold(
      title: 'Security',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'MESSAGE BACKUP',
            style: textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: newKey != null
                  ? RecoveryKeyCard(
                      recoveryKey: newKey,
                      onCopy: () => _copyKey(newKey),
                      onDone: _handleKeySaved,
                    )
                  : RecoveryStatusCard(
                      status: _status,
                      isWorking: _isWorking,
                      errorMessage: _errorMessage,
                      onSetUp: _setUp,
                      onEnterKey: _enterKey,
                      onResetKey: _confirmResetKey,
                      onRetry: _loadStatus,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadStatus() async {
    setState(() {
      _status = null;
      _errorMessage = null;
    });
    RecoveryStatus status;
    try {
      status = await getRecoveryStatus(
        homeserverUrl: AppConstants.defaultHomeserverUrl,
      );
    } catch (_) {
      status = RecoveryStatus.unknown;
    }
    if (mounted) setState(() => _status = status);
  }

  /// Set up recovery, or replace the key (`reset`); both return a new key.
  Future<void> _createKey({required bool reset}) async {
    setState(() {
      _isWorking = true;
      _errorMessage = null;
    });
    try {
      final key = reset
          ? await resetRecoveryKey(
              homeserverUrl: AppConstants.defaultHomeserverUrl,
            )
          : await enableRecovery(
              homeserverUrl: AppConstants.defaultHomeserverUrl,
              deleteOldBackup: _status == RecoveryStatus.unusableBackup,
            );
      if (mounted) setState(() => _newKey = key);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  /// An unusable backup gets deleted by setting up, so ask first.
  Future<void> _setUp() async {
    if (_status != RecoveryStatus.unusableBackup) {
      return _createKey(reset: false);
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace the old backup?'),
        content: const Text(
          'The old backup will be deleted. Messages only in it can\'t be read '
          'anymore, unless another device you\'re still signed in on can '
          'open it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _createKey(reset: false);
  }

  Future<void> _confirmResetKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Get a new recovery key?'),
        content: const Text(
          'Your current recovery key will stop working. Your messages stay '
          'backed up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Get new key'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _createKey(reset: true);
  }

  Future<void> _enterKey() async {
    await context.push<bool>(Routes.recover);
    if (mounted) _loadStatus();
  }

  Future<void> _copyKey(String key) async {
    await Clipboard.setData(ClipboardData(text: key));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Recovery key copied')));
  }

  void _handleKeySaved() {
    setState(() => _newKey = null);
    _loadStatus();
  }
}
