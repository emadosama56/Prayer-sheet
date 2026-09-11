import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../main.dart';
import '../models/profile.dart';
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
          const _Heading('حسابك'),
          const _AccountCard(),
          const SizedBox(height: 20),
          const _Heading('أنت'),
          _Card(
            children: <Widget>[
              for (final gender in Gender.values)
                RadioListTile<Gender>(
                  value: gender,
                  groupValue: store.gender,
                  onChanged: (Gender? value) =>
                      value == null ? null : store.setGender(value),
                  title: Text(gender.arabicName),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const _Heading('التذكير'),
          _Card(
            children: <Widget>[
              SwitchListTile(
                value: reminders.isEnabled,
                title: const Text('تشغيل التذكير'),
                subtitle: Text(
                  reminders.isSupported
                      ? 'إشعارات تذكّرك بتسجيل صلاتك'
                      : 'تعذّر تشغيل الإشعارات: '
                          '${reminders.setupError ?? "غير مدعومة"}',
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
                  reminders.isSoundOn ? 'ينبّه بصوت خفيف' : 'يصل بلا صوت',
                ),
                secondary: Icon(
                  reminders.isSoundOn
                      ? Icons.volume_up_outlined
                      : Icons.volume_off_outlined,
                ),
                onChanged: isOn
                    ? (bool v) => reminders.setSoundOn(v, store: store)
                    : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: reminders.quietHoursEnabled,
                title: const Text('السكوت بالليل'),
                subtitle: const Text('لا إشعارات من ١١ مساءً حتى ٦ صباحًا'),
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
                title: const Text('ذكي — حسب مواعيد الصلاة'),
                subtitle: const Text(
                  'تذكير قبل كل صلاة بنصف ساعة إن لم تُسجَّل التي قبلها، '
                  'وبعدها بنصف ساعة إن لم تُسجَّل. ويتوقف إذا اكتمل اليوم.',
                ),
                onChanged:
                    isOn ? (ReminderMode? m) => _setMode(reminders, m) : null,
              ),
              const Divider(height: 1),
              RadioListTile<ReminderMode>(
                value: ReminderMode.everyTwoHours,
                groupValue: reminders.mode,
                title: const Text('كل ساعتين'),
                subtitle: const Text('تذكير ثابت دون مواعيد أو موقع'),
                onChanged:
                    isOn ? (ReminderMode? m) => _setMode(reminders, m) : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _Heading('فحص الإشعارات'),
          _Card(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('إرسال إشعار تجريبي'),
                subtitle: const Text(
                  'وصوله يعني أن الإعداد سليم',
                ),
                trailing: const Icon(Icons.send_outlined),
                onTap: !reminders.isSupported
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final sent = await reminders.sendTestNotification();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              sent
                                  ? 'أُرسل. إن لم يصل فالجهاز يمنعه'
                                  : 'تعذّر الإرسال: ${reminders.scheduleError ?? ''}',
                            ),
                          ),
                        );
                      },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.pending_actions_outlined),
                title: Text('تذكيرات مجدولة: ${reminders.pendingCount}'),
                subtitle: Text(
                  reminders.scheduleError ??
                      (reminders.pendingCount == 0
                          ? 'لم يُجدول شيء بعد'
                          : 'محفوظة لدى النظام'),
                  style: reminders.scheduleError != null
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
                ),
                trailing: IconButton(
                  tooltip: 'تحديث',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => reminders.reschedule(store),
                ),
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
                  title: Text(reminders.place?.label ?? 'لم يُحدَّد بعد'),
                  subtitle: const Text(
                    'تُحسب مواعيد الصلاة على الجهاز وفق هذا الموقع',
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
              ? 'تعذّر تحديد الموقع، والمستخدم حاليًا القاهرة'
              : 'تم تحديد الموقع: ${place.label}',
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
      message = 'تم تشغيل التذكير';
    } else if (wanted) {
      // Asked for it, but the OS permission was refused.
      message = 'التذكير يحتاج إذن الإشعارات';
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

/// Signing in with Google, and what the sync is doing.
class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final account = AccountScope.of(context);
    final store = PrayerScope.of(context);

    if (!account.isAvailable) {
      return _Card(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.cloud_off_outlined),
            title: const Text('الحفظ في الحساب غير متاح'),
            subtitle: Text(
              'سجلك محفوظ على الجهاز',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    if (!account.isSignedIn) {
      return _Card(
        children: <Widget>[
          const ListTile(
            leading: Icon(Icons.account_circle_outlined),
            title: Text('تسجيل الدخول بحساب جوجل'),
            subtitle: Text(
              'يُحفظ سجلك في حسابك ويعود على أي جهاز',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton.icon(
              onPressed: account.isBusy
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await account.signIn(store);
                      if (!ok && account.error != null) {
                        messenger.showSnackBar(
                          SnackBar(
                            content:
                                Text('تعذّر تسجيل الدخول: ${account.error}'),
                          ),
                        );
                      }
                    },
              icon: account.isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(account.isBusy ? 'جارٍ الدخول…' : 'الدخول بحساب جوجل'),
            ),
          ),
        ],
      );
    }

    return _Card(
      children: <Widget>[
        ListTile(
          leading: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            backgroundImage: account.photoUrl == null
                ? null
                : NetworkImage(account.photoUrl!),
            child: account.photoUrl == null
                ? Icon(Icons.person, color: scheme.onPrimaryContainer)
                : null,
          ),
          title: Text(account.displayName ?? 'حسابك'),
          subtitle: Text(account.email ?? ''),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.cloud_done_outlined),
          title: Text(
            account.lastSyncedAt == null
                ? 'لم تتم المزامنة بعد'
                : 'آخر حفظ ${DateFormat.jm('ar').format(account.lastSyncedAt!)}',
          ),
          subtitle: account.error == null
              ? const Text('يُحفظ سجلك تلقائيًا')
              : Text(
                  account.error!,
                  style: TextStyle(color: scheme.error),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: account.isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  tooltip: 'مزامنة الآن',
                  icon: const Icon(Icons.sync),
                  onPressed: () => account.sync(store),
                ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.logout, color: scheme.error),
          title: Text('تسجيل الخروج', style: TextStyle(color: scheme.error)),
          onTap: account.isBusy ? null : () => account.signOut(),
        ),
      ],
    );
  }
}
