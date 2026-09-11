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
                  subtitle: gender.canExcuseDays
                      ? const Text('هيظهرلك خيار «مش قادرة أصلي النهاردة»')
                      : null,
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
                onChanged: isOn
                    ? (bool v) => reminders.setSoundOn(v, store: store)
                    : null,
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
            title: const Text('الحفظ على حسابك مش متاح'),
            subtitle: Text(
              'سجلك محفوظ على الموبايل وبيترجع لو نزّلت التطبيق تاني.',
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
              'سجلك يتحفظ على حسابك ويرجع على أي موبايل تدخل منه',
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
                                Text('مقدرتش أسجّل دخولك: ${account.error}'),
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
              label: Text(account.isBusy ? 'جاري الدخول…' : 'دخول بجوجل'),
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
                ? 'لسه ما زامنش'
                : 'آخر حفظ ${DateFormat.jm('ar').format(account.lastSyncedAt!)}',
          ),
          subtitle: account.error == null
              ? const Text('سجلك بيتحفظ على حسابك تلقائي')
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
                  tooltip: 'زامن دلوقتي',
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
