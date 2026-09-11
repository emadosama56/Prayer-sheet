import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'services/prayer_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');

  final store = PrayerStore();
  await store.load();

  runApp(PrayerSheetApp(store: store));
}

class PrayerSheetApp extends StatelessWidget {
  const PrayerSheetApp({super.key, required this.store});

  final PrayerStore store;

  @override
  Widget build(BuildContext context) {
    return PrayerScope(
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
    );
  }
}

/// Makes the single [PrayerStore] reachable from anywhere in the tree and
/// rebuilds dependents whenever a prayer is marked.
class PrayerScope extends InheritedNotifier<PrayerStore> {
  const PrayerScope({super.key, required PrayerStore store, required super.child})
      : super(notifier: store);

  static PrayerStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PrayerScope>();
    assert(scope?.notifier != null, 'No PrayerScope found in the widget tree');
    return scope!.notifier!;
  }
}
