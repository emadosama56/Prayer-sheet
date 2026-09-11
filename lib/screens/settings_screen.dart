import 'package:flutter/material.dart';

import '../main.dart';
import '../services/reminder_service.dart';

/// Everything the user can turn on and off.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLocating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reminders = ReminderScope.of(context);
    final store = PrayerScope.of(context);
    final isOn = reminders.isEnabled && reminders.isSupported;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          const _Heading('التذكير'),
          _Card(
            children: <Widget>[
              SwitchListTile(
                value: reminders.isEnabled,
                title: const Text('تشغيل التذكير'),
                subtitle: Text(
                  reminders.isSupported
                      ? 'إشعارات تفكرك تسجّل صلاتك'
                      : 'مقدرتش أشغّل الإشعارات: '
                          '${reminders.setupError ?? "مش مدعومة هنا"}',
                ),
                secondary: const Icon(Icons.notifications_outlined),
                onChanged: reminders.isSupported
                    ? (bool value) => _toggle(context, value)
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
                onChanged:
                    isOn ? (bool v) => reminders.setSoundOn(v, store: store) : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: reminders.quietHoursEnabled,
                title: const Text('السكوت بالليل'),
                subtitle: const Text('مفيش إشعارات من ١١ بالليل لـ ٦ الصبح'),
                secondary: const Icon(Icons.bedtime_outlined),
                onChanged: isOn
                    ? (bool v) =>
                        reminders.setQuietHoursEnabled(v, store: store)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _Heading('طريقة التذكير'),
          _Card(
            children: <Widget>[
              RadioListTile<ReminderMode>(
                value: ReminderMode.smart,
                groupValue: reminders.mode,
                title: const Text('ذكي (حسب مواعيد الصلاة)'),
                subtitle: const Text(
                  'قبل كل صلاة بنص ساعة لو الى قبلها مش مسجلة، وبعد كل صلاة '
                  'بنص ساعة لو لسه ما سجلتهاش. ولو سجّلت اليوم كله يسكت لبكرة.',
                ),
                onChanged:
                    isOn ? (ReminderMode? m) => _setMode(reminders, m) : null,
              ),
              const Divider(height: 1),
              RadioListTile<ReminderMode>(
                value: ReminderMode.everyTwoHours,
                groupValue: reminders.mode,
                title: const Text('كل ساعتين'),
                subtitle: const Text('تذكير ثابت من غير مواعيد ولا موقع'),
                onChanged:
                    isOn ? (ReminderMode? m) => _setMode(reminders, m) : null,
              ),
            ],
          ),
          if (reminders.mode == ReminderMode.smart) ...<Widget>[
            const SizedBox(height: 20),
            const _Heading('الموقع'),
            _Card(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(reminders.place?.label ?? 'لسه ما اتحددش'),
                  subtitle: const Text(
                    'مواعيد الصلاة بتتحسب على الجهاز حسب المكان ده',
                  ),
                  trailing: _isLocating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          tooltip: 'تحديث الموقع',
                          icon: const Icon(Icons.my_location),
                          onPressed: () => _refreshLocation(reminders),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'بيجرب الـ GPS الأول، ولو مرفوض بيحدد المدينة من الإنترنت.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setMode(ReminderService reminders, ReminderMode? mode) async {
    if (mode == null) return;
    await reminders.setMode(mode, store: PrayerScope.of(context));
  }

  Future<void> _refreshLocation(ReminderService reminders) async {
    setState(() => _isLocating = true);
    final messenger = ScaffoldMessenger.of(context);
    final store = PrayerScope.of(context);
    final place = await reminders.refreshLocation(store: store);
    if (!mounted) return;
    setState(() => _isLocating = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          place.isDefault
              ? 'مقدرتش أحدد الموقع — بستخدم القاهرة مؤقتاً'
              : 'الموقع اتحدث: ${place.label}',
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, bool wanted) async {
    final messenger = ScaffoldMessenger.of(context);
    final reminders = ReminderScope.of(context);
    final result = await reminders.setEnabled(
      wanted,
      store: PrayerScope.of(context),
    );

    final String message;
    if (result) {
      message = 'التذكير اشتغل 🙏';
    } else if (wanted) {
      // Asked for it, but the OS permission was refused.
      message = 'التذكير محتاج إذن الإشعارات من إعدادات الموبايل';
    } else {
      message = 'تم إيقاف التذكير';
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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
