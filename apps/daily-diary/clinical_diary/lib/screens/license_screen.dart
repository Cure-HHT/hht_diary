import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LicensesPage extends StatelessWidget {
  const LicensesPage({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication, // forces browser
    )) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.licenses)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text(l10n.gnuAgplTitle),
            subtitle: Text(l10n.gnuAgplDescription),
            onTap: () =>
                _openUrl('https://www.gnu.org/licenses/agpl-3.0.en.html'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text(l10n.atkinsonTitle),
            subtitle: Text(l10n.atkinsonDescription),
            onTap: () => _openUrl(
              'https://openfontlicense.org/open-font-license-official-text/',
            ),
          ),
        ],
      ),
    );
  }
}
