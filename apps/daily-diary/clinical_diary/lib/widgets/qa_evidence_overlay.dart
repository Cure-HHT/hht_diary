import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

const _qaEvidenceOverlayEnabled = bool.fromEnvironment('QA_EVIDENCE_OVERLAY');
const _androidQaEvidenceMarkerPath =
    '/data/data/org.anspar.curehht.app.qa/files/qa_evidence_marker.txt';
const _iosQaEvidenceMarkerFileName = 'qa_evidence_marker.txt';

class QaEvidenceOverlay extends StatefulWidget {
  const QaEvidenceOverlay({required this.child, super.key});

  final Widget child;

  @override
  State<QaEvidenceOverlay> createState() => _QaEvidenceOverlayState();
}

class _QaEvidenceOverlayState extends State<QaEvidenceOverlay> {
  Timer? _timer;
  String _marker = '';

  @override
  void initState() {
    super.initState();
    if (_qaEvidenceOverlayEnabled) {
      _readMarker();
      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _readMarker();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_qaEvidenceOverlayEnabled) return widget.child;

    final marker = _marker.trim();
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (marker.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            bottom: 18,
            child: IgnorePointer(
              child: Semantics(
                label: 'QA evidence marker $marker',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xE6000000),
                    border: Border.all(color: const Color(0xFFFFD54F)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text(
                      marker,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFFFF8E1),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _readMarker() async {
    try {
      final nextMarker = await _markerFile().readAsString();
      if (mounted && nextMarker != _marker) {
        setState(() => _marker = nextMarker);
      }
    } catch (_) {
      if (mounted && _marker.isNotEmpty) {
        setState(() => _marker = '');
      }
    }
  }

  File _markerFile() {
    if (Platform.isIOS) {
      return File('${Directory.systemTemp.path}/$_iosQaEvidenceMarkerFileName');
    }
    return File(_androidQaEvidenceMarkerPath);
  }
}
