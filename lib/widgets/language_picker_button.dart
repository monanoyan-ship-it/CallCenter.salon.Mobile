import 'package:callcenter_salon_mobil/state/app_localization_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LanguagePickerButton extends StatelessWidget {
  const LanguagePickerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppLocalizationState>(
      builder: (context, i18n, _) {
        final currentCode = i18n.locale.languageCode;
        var currentLabel = currentCode.toUpperCase();
        for (final lang in i18n.languages) {
          if (lang.code == currentCode) {
            currentLabel = lang.label;
            break;
          }
        }

        return PopupMenuButton<String>(
          tooltip: i18n.t('salon.mobile.language.tooltip', 'Dil seç'),
          onSelected: i18n.setLanguage,
          itemBuilder: (context) => i18n.languages
              .map(
                (lang) => PopupMenuItem<String>(
                  value: lang.code,
                  child: Row(
                    children: [
                      SizedBox(width: 32, child: Text(lang.label)),
                      Expanded(child: Text(lang.name)),
                      if (lang.code == currentCode)
                        Icon(
                          Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              )
              .toList(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.translate, size: 20),
                const SizedBox(width: 4),
                Text(currentLabel.toUpperCase()),
              ],
            ),
          ),
        );
      },
    );
  }
}
