// Licenses are bundled as stable PDF assets in assets/licenses/ to avoid
// 404 risks and support offline use in regulated environments.
// Load via rootBundle + openData to avoid native asset path issues (e.g. spaces).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';

/// Asset paths for bundled license PDFs (stable, no external URLs).
const String _gnuAgplAsset =
    'assets/licenses/GNU Affero General Public License - GNU Project - Free Software Foundation.pdf';
const String _silOflAsset =
    'assets/licenses/SIL Open Font License Official Text.pdf';

class LicensesDialog extends StatelessWidget {
  const LicensesDialog({super.key});

  void _openPdf(BuildContext context, String assetPath, String title) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            _PdfViewerPage(assetPath: assetPath, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final licenses = [
      {
        'title': 'GNU AGPL v3 License',
        'subtitle': 'gnu.org official license text',
        'asset': _gnuAgplAsset,
      },
      {
        'title': 'SIL Open Font License (Atkinson Hyperlegible)',
        'subtitle': 'SIL OFL official text',
        'asset': _silOflAsset,
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
                    onTap: () =>
                        _openPdf(context, item['asset']!, item['title']!),
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

class _PdfViewerPage extends StatefulWidget {
  const _PdfViewerPage({required this.assetPath, required this.title});

  final String assetPath;
  final String title;

  @override
  State<_PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<_PdfViewerPage> {
  late PdfControllerPinch _controller;

  @override
  void initState() {
    super.initState();
    // Load via rootBundle + openData to avoid native asset path issues
    // (e.g. spaces in filenames causing PdfRendererException on Android).
    _controller = PdfControllerPinch(
      document: rootBundle
          .load(widget.assetPath)
          .then(
            (data) => PdfDocument.openData(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            ),
          ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: PdfViewPinch(controller: _controller),
    );
  }
}
