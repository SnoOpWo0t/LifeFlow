import 'package:flutter/material.dart';
import '../../../../core/files/file_saver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/local/local_providers.dart';
import '../../../../core/sync/sync_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/local_export.dart';
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
      _showMessage(
        "Couldn't read that image. Try a JPG or PNG.",
        isError: true,
      );
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
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final location = ref.watch(weatherLocationProvider);
    final avatarUrl = _avatarFailedToLoad ? null : user?.avatarUrl;
    final initials = _initials(user == null || user.isLocal ? null : user.name);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: LayoutBuilder(
        builder: (context, constraints) => ListView(
          // Centre a readable 720px column on wide screens; full width on phones.
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth > 752
                ? (constraints.maxWidth - 720) / 2
                : 16,
            vertical: 16,
          ),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blueGrey,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    onBackgroundImageError: avatarUrl != null
                        ? (_, _) {
                            if (mounted)
                              setState(() => _avatarFailedToLoad = true);
                          }
                        : null,
                    child: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : (avatarUrl == null
                              ? (initials.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.white,
                                      )
                                    : Text(
                                        initials,
                                        style: const TextStyle(
                                          fontSize: 32,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ))
                              : null),
                  ),
                  if (!(user?.isLocal ?? false))
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
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                user == null || user.isLocal ? 'No account' : user.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Center(
              child: Text(
                user == null || user.isLocal
                    ? 'Data saved on this device'
                    : user.email,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            const _SyncCard(),
            const SizedBox(height: 24),
            Text(
              'Preferences',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Appearance'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (selection) => ref
                      .read(themeModeProvider.notifier)
                      .setMode(selection.first),
                ),
              ),
            ),
            // Reminders aren't implemented yet; a working-looking switch that
            // did nothing was misleading, so it's shown as disabled for now.
            const SwitchListTile(
              title: Text('Reminders'),
              subtitle: Text('Coming soon'),
              secondary: Icon(Icons.notifications_none),
              value: false,
              onChanged: null,
            ),
            ListTile(
              leading: const Icon(Icons.location_city),
              title: const Text('Weather Location'),
              subtitle: Text(location.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showCityPicker(context),
            ),
            const Divider(),
            Text(
              'About',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About Us'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
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
                        'Creator: Afrin Sultana Akhi',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Export my data'),
              subtitle: const Text(
                'Download everything (JSON) or your transactions (CSV)',
              ),
              onTap: _exportData,
            ),
            const Divider(),
            if (user?.isLocal ?? false)
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_outlined,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Erase data on this device',
                  style: TextStyle(color: Colors.redAccent),
                ),
                subtitle: const Text('Removes everything and starts over'),
                onTap: _confirmErase,
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  'Log out',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: _confirmLogout,
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_outlined,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Delete account',
                  style: TextStyle(color: Colors.redAccent),
                ),
                subtitle: const Text(
                  'Permanently removes your account and all its data',
                ),
                onTap: _confirmDeleteAccount,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Export my data'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'json'),
            child: const ListTile(
              leading: Icon(Icons.data_object),
              title: Text('Everything (JSON)'),
              subtitle: Text(
                'Profile, settings, tasks, habits, categories, transactions',
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'csv'),
            child: const ListTile(
              leading: Icon(Icons.table_chart_outlined),
              title: Text('Transactions (CSV)'),
              subtitle: Text('Opens in Excel or Google Sheets'),
            ),
          ),
        ],
      ),
    );
    if (format == null) return;

    try {
      final export = LocalExporter(ref.read(localDbProvider)).export(
        format,
        user: ref.read(authProvider).value!,
        preferences: ref.read(settingsRepositoryProvider).preferences,
      );
      final savedTo = await saveBytes(
        export.bytes,
        export.filename,
        export.mimeType,
      );
      _showMessage(
        savedTo == null
            ? 'Download started: ${export.filename}'
            : 'Saved to $savedTo',
      );
    } catch (_) {
      _showMessage("Couldn't export your data. Try again.", isError: true);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordCtrl = TextEditingController();
    String? error;
    var busy = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            if (passwordCtrl.text.isEmpty) {
              setDialogState(() => error = 'Enter your password');
              return;
            }
            setDialogState(() {
              busy = true;
              error = null;
            });
            final message = await ref
                .read(authProvider.notifier)
                .deleteAccount(passwordCtrl.text);
            if (!ctx.mounted) return;
            if (message == null) {
              Navigator.pop(ctx);
            } else {
              setDialogState(() {
                busy = false;
                error = message;
              });
            }
          }

          return AlertDialog(
            title: const Text('Delete your account?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This permanently deletes your tasks, habits, transactions, '
                  'categories and settings. It cannot be undone.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  autofocus: true,
                  onSubmitted: (_) => busy ? null : submit(),
                  decoration: InputDecoration(
                    labelText: 'Confirm with your password',
                    errorText: error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: busy ? null : submit,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Delete forever'),
              ),
            ],
          );
        },
      ),
    );
    passwordCtrl.dispose();
  }

  Future<void> _confirmErase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erase everything?'),
        content: const Text(
          "Your tasks, money, habits and wishlist on this device are deleted. "
          "There's no account backup, so this can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Erase'),
          ),
        ],
      ),
    );
    if (confirmed == true) ref.read(authProvider.notifier).eraseLocalData();
  }

  Future<void> _confirmLogout() async {
    // Try to upload unsynced changes first; warn if some are still waiting.
    await ref.read(syncProvider.notifier).syncNow();
    if (!mounted) return;
    final pending = ref.read(localDbProvider).pendingCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: Text(
          pending == 0
              ? "Your data is saved to your account. It's removed from this "
                    'device until you sign in again.'
              : '$pending ${pending == 1 ? 'change hasn\'t' : 'changes haven\'t'} '
                    "been uploaded yet (you're offline). Logging out now "
                    'loses ${pending == 1 ? 'it' : 'them'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true) ref.read(authProvider.notifier).logout();
  }
}

/// Where the data lives and whether it's synced. Without an account: a
/// prompt to sign in and back it up.
class _SyncCard extends ConsumerWidget {
  const _SyncCard();

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).value;
    ref.watch(dataVersionProvider);
    final pending = ref.watch(localDbProvider).pendingCount;

    if (user == null || user.isLocal) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: const Text('Not backed up'),
          subtitle: const Text(
            'Everything works offline and is saved on this device. Sign in or '
            'create an account to back it up and use it on other devices.',
          ),
          isThreeLine: true,
          trailing: FilledButton(
            onPressed: ref.read(authProvider.notifier).showSignIn,
            child: const Text('Sign in'),
          ),
        ),
      );
    }

    final status = ref.watch(syncProvider);
    final waiting = pending == 0
        ? ''
        : ' · $pending ${pending == 1 ? 'change' : 'changes'} waiting';
    final (icon, title, subtitle) = status.syncing
        ? (Icons.sync, 'Syncing…', 'Works offline; changes upload when online.')
        : status.offline
        ? (
            Icons.cloud_off_outlined,
            'Offline$waiting',
            'Everything still works. Changes upload when you are back online.',
          )
        : status.error != null
        ? (Icons.error_outline, status.error!, 'Tap the arrows to try again.')
        : (
            pending == 0
                ? Icons.cloud_done_outlined
                : Icons.cloud_upload_outlined,
            status.lastSynced == null
                ? 'Not synced yet$waiting'
                : 'Synced ${_ago(status.lastSynced!)}$waiting',
            'Saved on this device and backed up to your account.',
          );

    return Card(
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: IconButton(
          tooltip: 'Sync now',
          icon: const Icon(Icons.sync),
          onPressed: status.syncing
              ? null
              : () => ref.read(syncProvider.notifier).syncNow(),
        ),
      ),
    );
  }
}
