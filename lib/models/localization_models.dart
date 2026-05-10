import 'package:flutter/widgets.dart';

class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.name,
    required this.label,
    this.isDefault = false,
    this.isActive = true,
  });

  factory AppLanguage.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] ?? '').toString().trim().toLowerCase();
    return AppLanguage(
      code: code,
      name: (json['name'] ?? code.toUpperCase()).toString(),
      label: (json['label'] ?? code.toUpperCase()).toString(),
      isDefault: json['isDefault'] == true,
      isActive: json['isActive'] != false,
    );
  }

  final String code;
  final String name;
  final String label;
  final bool isDefault;
  final bool isActive;

  Locale get locale {
    switch (code) {
      case 'tr':
        return const Locale('tr', 'TR');
      case 'en':
        return const Locale('en', 'US');
      case 'de':
        return const Locale('de', 'DE');
      case 'ar':
        return const Locale('ar', 'SA');
      case 'ru':
        return const Locale('ru', 'RU');
      default:
        return Locale(code);
    }
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'label': label,
        'isDefault': isDefault,
        'isActive': isActive,
      };
}

class TranslationResponse {
  const TranslationResponse({
    required this.notModified,
    required this.etag,
    required this.translations,
  });

  final bool notModified;
  final String? etag;
  final Map<String, String> translations;
}

class LanguageResponse {
  const LanguageResponse({
    required this.notModified,
    required this.etag,
    required this.languages,
  });

  final bool notModified;
  final String? etag;
  final List<AppLanguage> languages;
}
