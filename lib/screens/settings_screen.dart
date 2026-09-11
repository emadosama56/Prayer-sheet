import 'package:flutter/material.dart';

import '../main.dart';
import '../services/reminder_service.dart';

/// Everything the user can turn on and off.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reminders = ReminderScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Text(
            'التذكير',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _Card(
            children: <Widget>[
              SwitchListTile(
                value: reminders.isEnabled,
                title: const Text('تشغيل التذكير'),
                subtitle: Text(
                  reminders.isSupported
                      ? 'تذكير كل ساعتين تسجّل صلاتك'
                      : 'التذكير مش مدعوم على الجهاز ده',
                ),
                secondary: const Icon(Icons.notifications_outlined),
                onChanged: reminders.isSupported
                    ? (bool value) => _toggle(context, reminders, value)
                    : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: reminders.isSoundOn,
                title: const Text('صوت التذكير'),
                subtitle: Text(
                  reminders.isSoundOn ? 'هيرن بصوت خفيف' : 'هيجي من غير صوت',
                ),
                secondary: Icon(
                  reminders.isSoundOn
                      ? Icons.volume_up_outlined
                      : Icons.volume_off_outlined,
                ),
                onChanged: reminders.isSupported
                    ? (bool value) => reminders.setSoundOn(value)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'لو قفلت التذكير مش هيجيلك أي إشعار خالص.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    ReminderService reminders,
    bool wanted,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await reminders.setEnabled(wanted);

    final String message;
    if (result) {
      message = 'هيجيلك تذكير كل ساعتين 🙏';
    } else if (wanted) {
      // Asked for it, but the OS permission was refused.
      message = 'التذكير محتاج إذن الإشعارات من إعدادات الموبايل';
    } else {
      message = 'تم إيقاف التذكير';
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
