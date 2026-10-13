import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/settings_repository.dart';
import '../providers/settings_provider.dart';
import '../widgets/city_picker.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _picker = ImagePicker();
  bool _isUploading = false;
  bool _avatarFailedToLoad = false;

  Future<void> _pickAndUploadImage() async {
    // Downscale before upload: full-size photos exceed PHP's default 2 MB
    // upload limit, which used to make larger pictures fail silently.
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await pickedFile.readAsBytes();
      final newUrl = await ref
          .read(settingsRepositoryProvider)
          .uploadAvatar(bytes, pickedFile.name);
      ref.read(authProvider.notifier).updateAvatarUrl(newUrl);
      _avatarFailedToLoad = false;
      _showMessage('Profile photo updated.');
    } on AvatarUploadException catch (e) {
      _showMessage(e.message, isError: true);
    } catch (_) {
      _showMessage("Couldn't read that image. Try a JPG or PNG.", isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final isDark = ref.watch(themeModeProvider);
    final repo = ref.read(settingsRepositoryProvider);
    final location = ref.watch(weatherLocationProvider);
    final avatarUrl = _avatarFailedToLoad ? null : user?.avatarUrl;
    final initials = _initials(user?.name);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blueGrey,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  onBackgroundImageError: avatarUrl != null
                      ? (_, _) {
                          if (mounted) setState(() => _avatarFailedToLoad = true);
                        }
                      : null,
                  child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : (avatarUrl == null
                        ? (initials.isEmpty
                            ? const Icon(Icons.person, size: 50, color: Colors.white)
                            : Text(initials, style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.w600)))
                        : null),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _isUploading ? null : _pickAndUploadImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(user?.name ?? 'User', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Center(
            child: Text(user?.email ?? '', style: const TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 32),
          const Text('Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          const Divider(),
          SwitchListTile(
            title: const Text('Dark Mode'),
            secondary: const Icon(Icons.dark_mode),
            value: isDark,
            onChanged: (val) {
              ref.read(themeModeProvider.notifier).setMode(val);
              repo.saveSettings(isDarkMode: val);
            },
          ),
          SwitchListTile(
            title: const Text('Push Notifications'),
            secondary: const Icon(Icons.notifications),
            value: repo.pushNotifications,
            onChanged: (val) {
              repo.saveSettings(pushNotifications: val);
              setState(() {}); // Simple rebuild
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_city),
            title: const Text('Weather Location'),
            subtitle: Text(location.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showCityPicker(context),
          ),
          const Divider(),
          const Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About Us'),
            onTap: () {
              showDialog(context: context, builder: (_) => AlertDialog(
                title: const Text('About LifeFlow'),
                content: const SingleChildScrollView(
                  child: Text(
                    'LifeFlow is your ultimate personal life management dashboard. '
                    'It helps you track your daily tasks, maintain healthy habits, and '
                    'manage your monthly expenses all in one place. With live weather, '
                    'productivity scoring, and interactive charts, LifeFlow empowers you to '
                    'take control of your time and money.\n\n'
                    '**Weekly Savings Logic**\n'
                    'Your Weekly Savings are calculated as the total sum of all Income minus the total sum of all Expenses over the last 7 days. This simple zero-based calculation helps you quickly see if you spent more than you earned this week!\n\n'
                    'Creator: Afrin Sultana Akhi'
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
                ],
              ));
            },
          ),
        ],
      ),
    );
  }
}
