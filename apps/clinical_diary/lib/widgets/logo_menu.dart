// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: Mobile App Diary Entry

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Logo menu widget with data management and clinical trial options
class LogoMenu extends StatefulWidget {
  const LogoMenu({
    required this.onAddExampleData,
    required this.onResetAllData,
    required this.onEndClinicalTrial,
    required this.onInstructionsAndFeedback,
    super.key,
  });

  final VoidCallback onAddExampleData;
  final VoidCallback onResetAllData;
  final VoidCallback? onEndClinicalTrial;
  final VoidCallback onInstructionsAndFeedback;

  @override
  State<LogoMenu> createState() => _LogoMenuState();
}

class _LogoMenuState extends State<LogoMenu> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    // On web, fetch version.json directly (more reliable than package_info_plus)
    if (kIsWeb) {
      await _loadVersionFromJson();
      return;
    }

    // On native platforms, use package_info_plus
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = packageInfo.version;
        });
      }
    } catch (e) {
      debugPrint('PackageInfo error: $e');
    }
  }

  Future<void> _loadVersionFromJson() async {
    try {
      // Use Uri.base to resolve the correct absolute URL on web
      final versionUrl = Uri.base.resolve('version.json');
      final response = await http.get(versionUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _version = data['version'] as String? ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('version.json fetch error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'App menu',
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.grey.withValues(alpha: 0.5),
            BlendMode.srcATop,
          ),
          child: Image.asset(
            'assets/images/cure-hht-grey.png',
            width: 100,
            height: 40,
            fit: BoxFit.contain,
          ),
        ),
      ),
      onSelected: (value) {
        switch (value) {
          case 'add_example_data':
            widget.onAddExampleData();
          case 'reset_all_data':
            widget.onResetAllData();
          case 'end_clinical_trial':
            widget.onEndClinicalTrial?.call();
          case 'instructions_feedback':
            widget.onInstructionsAndFeedback();
        }
      },
      itemBuilder: (context) => [
        // Data Management section header
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            'Data Management',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'add_example_data',
          child: Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              const Flexible(child: Text('Add Example Data')),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'reset_all_data',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Reset All Data',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ),

        // Clinical Trial section (only if enrolled)
        if (widget.onEndClinicalTrial != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              'Clinical Trial',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          PopupMenuItem<String>(
            value: 'end_clinical_trial',
            child: Row(
              children: [
                Icon(
                  Icons.exit_to_app,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                const Flexible(child: Text('End Clinical Trial')),
              ],
            ),
          ),
        ],

        // External links section
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'instructions_feedback',
          child: Row(
            children: [
              Icon(
                Icons.open_in_new,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              const Flexible(child: Text('Instructions & Feedback')),
            ],
          ),
        ),

        // Version info at bottom
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Center(
            child: Text(
              _version.isNotEmpty ? 'v$_version' : '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
