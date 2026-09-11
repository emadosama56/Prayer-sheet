import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'services/prayer_store.dart';
import 'services/reminder_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');

  final store = PrayerStore();
  await store.load();

  final reminders = ReminderService();
  await reminders.init();

  runApp(PrayerSheetApp(store: store, reminders: reminders));
}

class PrayerSheetApp extends StatefulWidget {
  const PrayerSheetApp({
    super.key,
    required this.store,
    required this.reminders,
  });

  final PrayerStore store;
  final ReminderService reminders;

  @override
  State<PrayerSheetApp> createState() => _PrayerSheetAppState();
}

class _PrayerSheetAppState extends State<PrayerSheetApp> {
  @override
  void initState() {
    super.initState();
    // A notification handed to the OS cannot change its mind later, so the
    // whole schedule is rebuilt whenever the log does.
    widget.store.addListener(_rescheduleReminders);
    _rescheduleReminders();
  }

  @override
  void dispose() {
    widget.store.removeListener(_rescheduleReminders);
    super.dispose();
  }

  void _rescheduleReminders() {
    if (!widget.reminders.isEnabled) return;
    widget.reminders.reschedule(widget.store);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final reminders = widget.reminders;
    return ReminderScope(
      service: reminders,
      child: PrayerScope(
        store: store,
        child: MaterialApp(
          title: 'سجل الصلاة',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          locale: const Locale('ar'),
          supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomeScreen(),
        ),
      ),
    );
  }
}

/// Makes the single [PrayerStore] reachable from anywhere in the tree and
/// rebuilds dependents whenever a prayer is marked.
class PrayerScope extends InheritedNotifier<PrayerStore> {
  const PrayerScope(
      {super.key, required PrayerStore store, required super.child})
      : super(notifier: store);

  static PrayerStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PrayerScope>();
    assert(scope?.notifier != null, 'No PrayerScope found in the widget tree');
    return scope!.notifier!;
  }
}

/// Same idea as [PrayerScope], for the reminder schedule.
class ReminderScope extends InheritedNotifier<ReminderService> {
  const ReminderScope({
    super.key,
    required ReminderService service,
    required super.child,
  }) : super(notifier: service);

  static ReminderService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ReminderScope>();
    assert(scope?.notifier != null, 'No ReminderScope in the widget tree');
    return scope!.notifier!;
  }
}
