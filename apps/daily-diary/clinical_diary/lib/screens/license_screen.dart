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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Licenses'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('GNU AGPL v3 License'),
            subtitle: const Text('gnu.org official license text'),
            onTap: () => _openUrl(
              'https://www.gnu.org/licenses/agpl-3.0.en.html',
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('Atkinson Hyperlegible Font License'),
            subtitle: const Text('SIL Open Font License 1.1'),
            onTap: () => _openUrl(
              'https://braileinstitute.app.box.com/s/rin3vzegmcy7sil28yfqslz2r5etv5nl',
            ),
          ),
        ],
      ),
    );
  }
}