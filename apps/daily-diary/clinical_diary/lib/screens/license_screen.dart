// Licenses are bundled as stable PDF assets in assets/licenses/ to avoid
// 404 risks and support offline use in regulated environments.
// Load via rootBundle + openData to avoid native asset path issues (e.g. spaces).

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';

/// Asset paths for bundled license PDFs (stable, no external URLs).
const String _gnuAgplAsset =
    'assets/licenses/GNU Affero General Public License - GNU Project - Free Software Foundation.pdf';
const String _silOflAsset =
    'assets/licenses/SIL Open Font License Official Text.pdf';

class LicensesPage extends StatelessWidget {
  const LicensesPage({super.key});

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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.licenses)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.description),
            title: Text(l10n.gnuAgplTitle),
            subtitle: Text(l10n.gnuAgplDescription),
            onTap: () => _openPdf(context, _gnuAgplAsset, l10n.gnuAgplTitle),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.description),
            title: Text(l10n.atkinsonTitle),
            subtitle: Text(l10n.atkinsonDescription),
            onTap: () => _openPdf(context, _silOflAsset, l10n.atkinsonTitle),
          ),
        ],
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
