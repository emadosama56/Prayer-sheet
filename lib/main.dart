import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'services/account_service.dart';
import 'services/prayer_store.dart';
import 'services/prayer_widget.dart';
import 'services/reminder_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');

  final store = PrayerStore();
  await store.load();

  final reminders = ReminderService();
  await reminders.init();

  // Tapping a prayer on the home screen runs this with the app closed.
  await HomeWidget.registerInteractivityCallback(onWidgetTapped);
  await PrayerWidget.update(store);

  final account = AccountService();
  runApp(
    PrayerSheetApp(store: store, reminders: reminders, account: account),
  );

  // Behind the first frame, never in front of it. Signing in is an extra; a
  // slow or unreachable Firebase must not hold the app on a blank screen, and
  // the log works perfectly well without an account.
  unawaited(account.init(store: store));
}

class PrayerSheetApp extends StatefulWidget {
  const PrayerSheetApp({
    super.key,
    required this.store,
    required this.reminders,
    required this.account,
  });

  final PrayerStore store;
  final ReminderService reminders;
  final AccountService account;

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
    widget.store.addListener(_syncAccount);
    widget.store.addListener(_refreshWidget);
    _rescheduleReminders();
  }

  @override
  void dispose() {
    widget.store.removeListener(_rescheduleReminders);
    widget.store.removeListener(_syncAccount);
    widget.store.removeListener(_refreshWidget);
    super.dispose();
  }

  /// Redraws the home screen widget whenever the log changes, so it never
  /// shows a prayer as unlogged after it has been marked in the app.
  void _refreshWidget() {
    PrayerWidget.update(
      widget.store,
      latitude: widget.reminders.place?.latitude,
      longitude: widget.reminders.place?.longitude,
    );
  }

  /// Pushes a changed log up, when there is an account to push it to.
  void _syncAccount() {
    if (!widget.account.isSignedIn) return;
    widget.account.sync(widget.store);
  }

  void _rescheduleReminders() {
    if (!widget.reminders.isEnabled) return;
    widget.reminders.reschedule(widget.store);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final reminders = widget.reminders;
    return AccountScope(
      service: widget.account,
      child: ReminderScope(
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

/// Same idea as [PrayerScope], for the signed-in account.
class AccountScope extends InheritedNotifier<AccountService> {
  const AccountScope({
    super.key,
    required AccountService service,
    required super.child,
  }) : super(notifier: service);

  static AccountService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AccountScope>();
    assert(scope?.notifier != null, 'No AccountScope in the widget tree');
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
