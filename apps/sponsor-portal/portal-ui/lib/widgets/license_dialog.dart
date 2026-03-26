// IMPLEMENTS REQUIREMENTS:
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Licenses are bundled as stable PDF assets in assets/licenses/ to avoid
// 404 risks and support offline use in regulated environments.
// On web, the browser opens the bundled PDF natively — no CDN or pdfjs required.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Asset paths for bundled license PDFs (stable, no external URLs).
const String _gnuAgplAsset = 'assets/licenses/gnu_license.pdf';

class LicensesDialog extends StatelessWidget {
  const LicensesDialog({super.key});

  Future<void> _openPdf(String assetPath) async {
    // Flutter web serves assets relative to the app base URL.
    // Uri.encodeFull preserves slashes while encoding spaces in the filename.
    final uri = Uri.parse(Uri.encodeFull(assetPath));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final licenses = [
      {
        'title': 'GNU AGPL v3 License',
        'subtitle': 'gnu.org official license text',
        'asset': _gnuAgplAsset,
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
                    leading: const Icon(Icons.description),
                    title: Text(item['title']!),
                    subtitle: Text(item['subtitle']!),
                    onTap: () => _openPdf(item['asset']!),
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
