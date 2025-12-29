import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/wink_theme.dart';

/// User profile page with settings
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  UserProfile? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _error = 'Not signed in';
        });
        return;
      }

      final response = await _supabase
          .from('users')
          .select('*')
          .eq('id', userId)
          .single();

      setState(() {
        _profile = UserProfile.fromJson(response);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load profile';
      });
    }
  }

  Future<void> _updateAvatar() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image == null) return;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final bytes = await image.readAsBytes();
      final ext = image.path.split('.').last;
      final path = 'avatars/$userId.$ext';

      await _supabase.storage.from('wink-storage').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: 'image/$ext',
          upsert: true,
        ),
      );

      final url = _supabase.storage.from('wink-storage').getPublicUrl(path);

      await _supabase
          .from('users')
          .update({'avatar_url': url})
          .eq('id', userId);

      setState(() {
        _profile = _profile?.copyWith(avatarUrl: url);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update avatar: $e')),
        );
      }
    }
  }

  void _editProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProfileSheet(
        profile: _profile!,
        onSave: (name, bio) async {
          await _updateProfile(name, bio);
        },
      ),
    );
  }

  Future<void> _updateProfile(String name, String bio) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('users').update({
        'display_name': name,
        'bio': bio,
      }).eq('id', userId);

      setState(() {
        _profile = _profile?.copyWith(displayName: name, bio: bio);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    }
  }

  void _showSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: WinkTheme.surface,
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _supabase.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WinkTheme.background,
      appBar: AppBar(
        backgroundColor: WinkTheme.surface,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: WinkTheme.primary),
            )
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  color: WinkTheme.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildProfileHeader(),
                        const SizedBox(height: 24),
                        _buildStats(),
                        const SizedBox(height: 24),
                        _buildMenuSection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          GestureDetector(
            onTap: _updateAvatar,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(_profile?.avatarUrl ?? ''),
                  onBackgroundImageError: (_, __) {},
                  backgroundColor: WinkTheme.surfaceLight,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: WinkTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: WinkTheme.background, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            _profile?.displayName ?? 'User',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: WinkTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Email
          Text(
            _profile?.email ?? '',
            style: TextStyle(
              fontSize: 14,
              color: WinkTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Bio
          if (_profile?.bio != null && _profile!.bio!.isNotEmpty)
            Text(
              _profile!.bio!,
              style: TextStyle(
                fontSize: 14,
                color: WinkTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 16),

          // Edit button
          OutlinedButton.icon(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit Profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: WinkTheme.primary,
              side: const BorderSide(color: WinkTheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WinkTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'AI Friends', value: '5'),
          _StatItem(label: 'Connections', value: '23'),
          _StatItem(label: 'Posts', value: '12'),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Column(
      children: [
        _MenuItem(
          icon: Icons.favorite_border,
          label: 'My AI Friends',
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.grid_view,
          label: 'My Posts',
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.bookmark_border,
          label: 'Saved',
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.help_outline,
          label: 'Help & Support',
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.info_outline,
          label: 'About Wink',
          onTap: () {},
        ),
        const SizedBox(height: 16),
        _MenuItem(
          icon: Icons.logout,
          label: 'Sign Out',
          color: Colors.red,
          onTap: _signOut,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Something went wrong',
            style: TextStyle(
              color: WinkTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: WinkTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: WinkTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: WinkTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? WinkTheme.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? WinkTheme.textPrimary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: WinkTheme.textSecondary,
      ),
      onTap: onTap,
    );
  }
}

/// User profile model
class UserProfile {
  final String id;
  final String displayName;
  final String email;
  final String avatarUrl;
  final String? bio;
  final String locale;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    this.bio,
    required this.locale,
    required this.createdAt,
  });

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      locale: locale,
      createdAt: createdAt,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'User',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      bio: json['bio'] as String?,
      locale: json['locale'] as String? ?? 'en',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Edit profile bottom sheet
class EditProfileSheet extends StatefulWidget {
  final UserProfile profile;
  final Future<void> Function(String name, String bio) onSave;

  const EditProfileSheet({
    super.key,
    required this.profile,
    required this.onSave,
  });

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    await widget.onSave(
      _nameController.text.trim(),
      _bioController.text.trim(),
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: const BoxDecoration(
        color: WinkTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: WinkTheme.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: WinkTheme.textSecondary),
                  ),
                ),
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: WinkTheme.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: WinkTheme.primary,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            color: WinkTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: WinkTheme.surfaceLight),

          // Form
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Display Name',
                  style: TextStyle(
                    color: WinkTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: WinkTheme.textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: WinkTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bio',
                  style: TextStyle(
                    color: WinkTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioController,
                  maxLines: 3,
                  maxLength: 200,
                  style: const TextStyle(color: WinkTheme.textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: WinkTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle: TextStyle(color: WinkTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Settings page
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WinkTheme.background,
      appBar: AppBar(
        backgroundColor: WinkTheme.surface,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        children: [
          _SettingsSection(
            title: 'Account',
            items: [
              _SettingsItem(
                icon: Icons.person_outline,
                label: 'Account Info',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.lock_outline,
                label: 'Privacy',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.security,
                label: 'Security',
                onTap: () {},
              ),
            ],
          ),
          _SettingsSection(
            title: 'Preferences',
            items: [
              _SettingsItem(
                icon: Icons.language,
                label: 'Language',
                value: 'English',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.dark_mode_outlined,
                label: 'Appearance',
                value: 'Dark',
                onTap: () {},
              ),
            ],
          ),
          _SettingsSection(
            title: 'About',
            items: [
              _SettingsItem(
                icon: Icons.info_outline,
                label: 'Version',
                value: '1.0.0',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.description_outlined,
                label: 'Terms of Service',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: WinkTheme.textSecondary,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: WinkTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: WinkTheme.textSecondary, size: 22),
      title: Text(
        label,
        style: const TextStyle(
          color: WinkTheme.textPrimary,
          fontSize: 15,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(
              value!,
              style: TextStyle(
                color: WinkTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            color: WinkTheme.textSecondary,
            size: 20,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
