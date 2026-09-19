import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../app_theme.dart';
import '../core/services/firebase_usage_analytics.dart';
import '../core/services/firebase_remote_config_service.dart';
import '../core/utils/external_launcher.dart';
import '../vault.dart';
import '../widgets/components.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _openLink(BuildContext context, String url) async {
    final ok = await ExternalLauncher.openUrl(url);
    if (!ok && context.mounted) {
      LvSnackbar.show(
        context,
        'Could not open: ',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _checkForUpdates() async {
    final info = await FirebaseRemoteConfigService.instance.refresh();
    if (!mounted) return;
    if (!info.hasNewVersion) {
      LvSnackbar.show(context, 'You’re up to date.');
      return;
    }
    await _showUpdateDialog(info);
  }

  Future<void> _showUpdateDialog(UpdateInfo info) async {
    final shouldOpen = await LvDialog.show(
      context,
      icon: Icons.system_update_rounded,
      title: info.required
          ? 'Update required'
          : 'New SkillNest update available',
      message: info.hasValidUrl
          ? info.message
          : '${info.message}\n\nAn update link is not available yet.',
      confirmLabel: info.hasValidUrl ? 'Update now' : 'OK',
      cancelLabel: info.required && info.hasValidUrl ? 'Later' : 'Close',
    );
    if (shouldOpen == true && info.hasValidUrl) {
      await ExternalLauncher.openUrl(info.url);
    }
  }

  Future<void> _enableNotifications() async {
    FirebaseUsageAnalytics.instance.notificationFeatureUsed();
    final enabled = await Vault.I.enableNotifications();
    if (!mounted) return;
    LvSnackbar.show(
      context,
      enabled
          ? 'Notifications enabled — reminders are scheduled.'
          : 'Notifications are blocked. Allow them in Android Settings.',
      icon: enabled
          ? Icons.notifications_active_rounded
          : Icons.notifications_off_outlined,
    );
  }

  String _formatMinutes(int minutes) => MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));

  Future<void> _pickReminderTime({required bool morning}) async {
    final vault = Vault.I;
    final minutes = morning
        ? vault.morningReminderMinutes
        : vault.eveningReminderMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    final selectedMinutes = picked.hour * 60 + picked.minute;
    await vault.setReminderTime(
      morningMinutes: morning ? selectedMinutes : null,
      eveningMinutes: morning ? null : selectedMinutes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vault = Vault.I;

    return ListenableBuilder(
      listenable: vault,
      builder: (context, _) => Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          backgroundColor: scheme.surface,
          leading: const BackButton(),
          title: const Text('Settings'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(Insets.m, 8, Insets.m, 120),
          children: [
            // Profile
            Container(
              decoration: NotedBox.card(
                color: scheme.surfaceContainerLowest,
                borderColor: scheme.outline,
                shadowColor: scheme.shadow,
                radius: Radii.card,
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      vault.userName.isNotEmpty
                          ? vault.userName[0].toUpperCase()
                          : 'A',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(
                    vault.userName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  subtitle: Text(
                    vault.userEmail.isEmpty
                        ? 'Add your email address'
                        : vault.userEmail,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: _editProfile,
                    child: const Text('Edit'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Insets.l),

            _section(context, 'Notifications', Icons.notifications_outlined, [
              SwitchListTile(
                title: const Text('Morning learning reminder'),
                subtitle: const Text(
                  'A different learning prompt every morning',
                  style: TextStyle(fontSize: 12),
                ),
                value: vault.dailyDigest,
                onChanged: (v) => vault.setNotificationPrefs(daily: v),
              ),
              ListTile(
                enabled: vault.dailyDigest,
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text('Morning time'),
                trailing: Text(_formatMinutes(vault.morningReminderMinutes)),
                onTap: vault.dailyDigest
                    ? () => _pickReminderTime(morning: true)
                    : null,
              ),
              SwitchListTile(
                title: const Text('Weekly report'),
                subtitle: const Text(
                  'A weekly reset to review progress and plan ahead',
                  style: TextStyle(fontSize: 12),
                ),
                value: vault.weeklyReport,
                onChanged: (v) => vault.setNotificationPrefs(weekly: v),
              ),
              SwitchListTile(
                title: const Text('Evening check-in'),
                subtitle: const Text(
                  'Different evening prompts to organise tomorrow and rest well',
                  style: TextStyle(fontSize: 12),
                ),
                value: vault.unreadReminders,
                onChanged: (v) => vault.setNotificationPrefs(reminders: v),
              ),
              ListTile(
                enabled: vault.unreadReminders,
                leading: const Icon(Icons.nightlight_outlined),
                title: const Text('Evening time'),
                trailing: Text(_formatMinutes(vault.eveningReminderMinutes)),
                onTap: vault.unreadReminders
                    ? () => _pickReminderTime(morning: false)
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Enable notifications'),
                subtitle: const Text(
                  'Requests permission for SkillNest reminders and updates',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: _enableNotifications,
              ),
            ]),
            const SizedBox(height: 12),

            _section(context, 'Backup & Restore', Icons.backup_outlined, [
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('Export data'),
                subtitle: const Text(
                  'Save all your learning data in a ZIP file',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () => _exportBackup(vault),
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('Import data'),
                subtitle: const Text(
                  'Replace this library with a saved backup',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () => _importBackup(vault),
              ),
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Last backup'),
                subtitle: Text(
                  vault.lastBackupAt == null
                      ? 'Never'
                      : vault.lastBackupAt!
                            .toLocal()
                            .toString()
                            .split(' ')
                            .take(2)
                            .join(' '),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            _section(context, 'Manage Library', Icons.delete_outline_rounded, [
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Trash'),
                subtitle: Text(
                  vault.trash.isEmpty
                      ? 'Deleted items stay for 30 days'
                      : '${vault.trash.length} item${vault.trash.length == 1 ? '' : 's'} · auto-deleted after 30 days',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pushNamed(context, '/trash'),
              ),
            ]),
            const SizedBox(height: 12),

            _section(context, 'About', Icons.info_outline_rounded, [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: NotedColors.border, width: 2),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/developer_avatar.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const CircleAvatar(
                                backgroundColor: NotedColors.yellow,
                                child: Text(
                                  'MK',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: NotedColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mohamed Khaled </>',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                  color: NotedColors.ink,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Developer & Creator',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: NotedColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: NotedColors.yellowLight,
                              foregroundColor: NotedColors.ink,
                              side: const BorderSide(color: NotedColors.border, width: 1.8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(Radii.control),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.code_rounded, size: 18),
                            label: const Text(
                              'GitHub',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            onPressed: () => _openLink(context, 'https://github.com/Bnkhlid'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: NotedColors.mintLight,
                              foregroundColor: NotedColors.ink,
                              side: const BorderSide(color: NotedColors.border, width: 1.8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(Radii.control),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.mail_outline_rounded, size: 18),
                            label: const Text(
                              'Email',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            onPressed: () => _openLink(context, 'mailto:bnkhlidd@gmail.com'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.system_update_rounded),
                title: const Text('Check for updates'),
                subtitle: const Text(
                  'Checks safely without interrupting your library',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: _checkForUpdates,
              ),
              const ListTile(
                title: Text('Version'),
                trailing: Text('1.0.0 (100)'),
              ),
            ]),
            const SizedBox(height: Insets.l),
            Text(
              'Your knowledge, beautifully kept.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        ...children.map(
          (c) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: NotedBox.card(
              color: scheme.surfaceContainerLowest,
              borderColor: scheme.outline,
              shadowColor: scheme.shadow,
              radius: Radii.card,
              shadowOffset: const Offset(2.5, 3.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(color: Colors.transparent, child: c),
          ),
        ),
      ],
    );
  }

  Future<void> _editProfile() async {
    final vault = Vault.I;
    final nameController = TextEditingController(text: vault.userName);
    final emailController = TextEditingController(text: vault.userEmail);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email address'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    if (name.isEmpty) {
      if (mounted) LvSnackbar.show(context, 'Please enter your name');
      return;
    }
    await vault.setProfile(name, email);
    if (mounted) LvSnackbar.show(context, 'Profile updated');
  }

  Future<void> _exportBackup(Vault vault) async {
    final go = await LvDialog.showAsBool(
      context,
      icon: Icons.file_upload_outlined,
      title: 'Export backup?',
      message:
          'Creates a portable .zip backup containing all your resources, collections, tags, notes, sticky tasks, and attached local files.',
      confirmLabel: 'Export',
    );
    if (!go || !mounted) return;

    final statusNotifier = ValueNotifier<String>('Preparing backup...');
    final progressNotifier = ValueNotifier<double>(0.05);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card),
            side: const BorderSide(color: NotedColors.ink, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<String>(
                  valueListenable: statusNotifier,
                  builder: (context, status, child) => Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (context, progress, child) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: NotedColors.canvasLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await vault.exportBackupZip(
        onProgress: (status, progress) {
          statusNotifier.value = status;
          progressNotifier.value = progress;
        },
      );

      if (mounted) {
        Navigator.pop(context);
        LvSnackbar.show(
          context,
          'Backup exported · ${p.basename(result.filePath)}',
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        await LvDialog.show(
          context,
          icon: Icons.error_outline_rounded,
          iconColor: Theme.of(context).colorScheme.error,
          title: 'Export failed',
          message: 'Could not export backup: $e',
          confirmLabel: 'OK',
        );
      }
    }
  }

  Future<void> _importBackup(Vault vault) async {
    List<PlatformFile> pickedFiles = const [];
    try {
      pickedFiles = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
    } catch (e) {
      if (mounted) {
        LvSnackbar.show(
          context,
          'Failed to pick file: $e',
          icon: Icons.error_outline,
        );
      }
      return;
    }

    if (pickedFiles.isEmpty || pickedFiles.first.path == null) {
      return;
    }

    final filePath = pickedFiles.first.path!;

    // 1. Validate first
    final validation = await vault.validateBackupZip(filePath);
    if (!mounted) return;

    if (!validation.isValid) {
      await LvDialog.show(
        context,
        icon: Icons.error_outline_rounded,
        iconColor: Theme.of(context).colorScheme.error,
        title: 'Invalid backup',
        message:
            validation.errorMessage ??
            'The selected file is not a valid SkillNest backup.',
        confirmLabel: 'OK',
      );
      return;
    }

    // 2. Ask confirmation
    final confirmMessage =
        'Restoring a backup will replace the current library data.\n\n'
        '• ${validation.resourceCount} Resources\n'
        '• ${validation.collectionCount} Collections\n'
        '• ${validation.tagCount} Tags\n'
        '• ${validation.fileCount} Attached Files\n'
        '• ${validation.stickyNoteCount} Sticky Notes\n'
        '• ${validation.analyticsEventCount} Analytics Events\n\n'
        'Are you sure you want to proceed?';

    final go = await LvDialog.showAsBool(
      context,
      icon: Icons.warning_amber_rounded,
      iconColor: Theme.of(context).colorScheme.tertiary,
      title: 'Restore backup?',
      message: confirmMessage,
      confirmLabel: 'Restore',
    );
    if (!go || !mounted) return;

    // 3. Perform Staged Restore with Progress
    final statusNotifier = ValueNotifier<String>('Validating backup...');
    final progressNotifier = ValueNotifier<double>(0.10);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card),
            side: const BorderSide(color: NotedColors.ink, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<String>(
                  valueListenable: statusNotifier,
                  builder: (context, status, child) => Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (context, progress, child) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: NotedColors.canvasLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await vault.restoreBackupZip(
        filePath,
        onProgress: (status, progress) {
          statusNotifier.value = status;
          progressNotifier.value = progress;
        },
      );

      if (mounted) {
        Navigator.pop(context);
        LvSnackbar.show(
          context,
          'Backup restored · ${result.resourceCount} items loaded',
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        await LvDialog.show(
          context,
          icon: Icons.error_outline_rounded,
          iconColor: Theme.of(context).colorScheme.error,
          title: 'Restore failed',
          message:
              'Could not restore backup. Existing data was preserved safely.\n\nError: $e',
          confirmLabel: 'OK',
        );
      }
    }
  }
}
