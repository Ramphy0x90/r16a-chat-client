import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:r16a_chat_client/core/constants.dart';
import 'package:r16a_chat_client/core/detail_scaffold.dart';
import 'package:r16a_chat_client/features/settings/widgets/profile_avatar.dart';
import 'package:r16a_chat_client/features/settings/widgets/profile_form.dart';
import 'package:r16a_chat_client/src/rust/api/profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _maxAvatarBytes = 5 * 1024 * 1024;
  static const _imageTypes = XTypeGroup(
    label: 'Images',
    extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
    mimeTypes: ['image/png', 'image/jpeg', 'image/gif', 'image/webp'],
  );

  ProfileInfo? _profile;
  bool _isLoading = true;
  bool _isSavingName = false;
  bool _isUpdatingAvatar = false;
  String? _loadError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(title: 'Profile', child: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.secondary,
        ),
      );
    }
    final profile = _profile;
    if (profile == null) {
      return Center(child: Text(_loadError ?? 'Failed to load profile'));
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ProfileAvatar(
                bytes: profile.avatar,
                fallbackInitial: _initialOf(profile),
                onTap: _handlePickAvatar,
                isLoading: _isUpdatingAvatar,
              ),
            ),
            if (profile.avatar != null)
              Center(
                child: TextButton(
                  // Via styleFrom so the disabled state still shows while uploading.
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onSurfaceVariant,
                  ),
                  onPressed: _isUpdatingAvatar ? null : _handleRemoveAvatar,
                  child: const Text('Remove photo'),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Your name and photo are visible to others and are not '
              'end-to-end encrypted.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ProfileForm(
              initialDisplayName: profile.displayName,
              userId: profile.userId,
              onSave: _handleSaveName,
              onCopyUserId: () => _copyUserId(profile.userId),
              isSaving: _isSavingName,
              errorMessage: _saveError,
            ),
          ],
        ),
      ),
    );
  }

  /// First letter of the display name, or of the localpart of the user ID.
  String _initialOf(ProfileInfo profile) {
    final name = profile.displayName?.trim();
    final source = (name != null && name.isNotEmpty)
        ? name
        : profile.userId.replaceFirst('@', '');
    return source.isEmpty ? '?' : source.characters.first.toUpperCase();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await getProfile(
        homeserverUrl: AppConstants.defaultHomeserverUrl,
      );
      if (mounted) setState(() => _profile = profile);
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Failed to load profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSaveName(String name) async {
    setState(() {
      _isSavingName = true;
      _saveError = null;
    });

    try {
      await setDisplayName(
        homeserverUrl: AppConstants.defaultHomeserverUrl,
        name: name,
      );
      if (!mounted) return;
      final profile = _profile!;
      setState(() {
        _profile = ProfileInfo(
          userId: profile.userId,
          displayName: name.isEmpty ? null : name,
          avatar: profile.avatar,
        );
      });
    } catch (e) {
      if (mounted) setState(() => _saveError = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Future<void> _handlePickAvatar() async {
    final XFile? file;
    try {
      file = await openFile(acceptedTypeGroups: const [_imageTypes]);
      if (file == null) return;
      // Checked before reading so a huge file isn't loaded into memory.
      // Rust checks again (and validates the actual image contents).
      if (await file.length() > _maxAvatarBytes) {
        _showError('Image is too large (max 5 MB)');
        return;
      }
    } catch (e) {
      _showError('Failed to open image: $e');
      return;
    }

    await _updateAvatar(() async {
      final bytes = await file!.readAsBytes();
      await setAvatar(
        homeserverUrl: AppConstants.defaultHomeserverUrl,
        data: bytes,
      );
      return bytes;
    });
  }

  Future<void> _handleRemoveAvatar() async {
    await _updateAvatar(() async {
      await removeAvatar(homeserverUrl: AppConstants.defaultHomeserverUrl);
      return null;
    });
  }

  /// Runs [update] and shows the avatar bytes it returns (null = no avatar).
  Future<void> _updateAvatar(Future<Uint8List?> Function() update) async {
    setState(() => _isUpdatingAvatar = true);

    try {
      final avatar = await update();
      if (!mounted) return;
      final profile = _profile!;
      setState(() {
        _profile = ProfileInfo(
          userId: profile.userId,
          displayName: profile.displayName,
          avatar: avatar,
        );
      });
    } catch (e) {
      _showError('Failed to update photo: $e');
    } finally {
      if (mounted) setState(() => _isUpdatingAvatar = false);
    }
  }

  void _copyUserId(String userId) {
    Clipboard.setData(ClipboardData(text: userId));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('User ID copied')));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
