import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LicensesDialog extends StatelessWidget {
  const LicensesDialog({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final licenses = [
      {
        'title': 'GNU AGPL v3 License',
        'subtitle': 'gnu.org official license text',
        'url': 'https://www.gnu.org/licenses/agpl-3.0.en.html',
      },
    ];

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Licenses',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: licenses.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = licenses[index];

                  return ListTile(
                    leading: const Icon(Icons.open_in_new),
                    title: Text(item['title']!),
                    subtitle: Text(item['subtitle']!),
                    onTap: () {
                      _openUrl(item['url']!);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
