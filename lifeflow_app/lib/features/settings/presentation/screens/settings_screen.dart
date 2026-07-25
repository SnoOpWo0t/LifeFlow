import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _picker = ImagePicker();
  bool _isUploading = false;
  late TextEditingController _cityController;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(settingsRepositoryProvider);
    _cityController = TextEditingController(text: repo.defaultCity);
  }

  Future<void> _pickAndUploadImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _isUploading = true);
      
      final repo = ref.read(settingsRepositoryProvider);
      final bytes = await pickedFile.readAsBytes();
      final newUrl = await repo.uploadAvatar(bytes, pickedFile.name);
      
      if (newUrl != null) {
        ref.read(authProvider.notifier).updateAvatarUrl(newUrl);
      }
      
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final isDark = ref.watch(themeModeProvider);
    final repo = ref.read(settingsRepositoryProvider);

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
                  backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                  child: _isUploading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : (user?.avatarUrl == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _pickAndUploadImage,
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
            title: const Text('Default Weather City'),
            subtitle: Text(repo.defaultCity),
            onTap: () {
              showDialog(context: context, builder: (_) => AlertDialog(
                title: const Text('Change City'),
                content: TextField(controller: _cityController),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  TextButton(
                    onPressed: () {
                      repo.saveSettings(defaultCity: _cityController.text);
                      setState(() {});
                      Navigator.pop(context);
                    }, 
                    child: const Text('Save')
                  )
                ],
              ));
            },
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
