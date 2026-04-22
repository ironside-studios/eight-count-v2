import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide locale holder. ChangeNotifier-backed so MaterialApp rebuilds
/// when [setLocale] is called. Persists the language code under
/// [_prefsKey] via shared_preferences.
///
/// Use the [localeService] singleton below; initialize once at app start
/// via [loadFromPrefs] before runApp.
class LocaleService extends ChangeNotifier {
  static const String _prefsKey = 'app_locale';
  static const Locale _fallback = Locale('en');
  static const List<Locale> supportedLocales = [Locale('en'), Locale('es')];

  Locale _current = _fallback;
  Locale get current => _current;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null && supportedLocales.any((l) => l.languageCode == code)) {
      _current = Locale(code);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_current == locale) return;
    if (!supportedLocales.any((l) => l.languageCode == locale.languageCode)) {
      return;
    }
    _current = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }
}

final LocaleService localeService = LocaleService();
