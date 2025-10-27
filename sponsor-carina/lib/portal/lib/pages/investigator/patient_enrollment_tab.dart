// IMPLEMENTS REQUIREMENTS:
//   REQ-p00025: Patient Enrollment Workflow

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../config/supabase_config.dart';
import '../../services/auth_service.dart';

class PatientEnrollmentTab extends StatefulWidget {
  const PatientEnrollmentTab({super.key});

  @override
  State<PatientEnrollmentTab> createState() => _PatientEnrollmentTabState();
}

class _PatientEnrollmentTabState extends State<PatientEnrollmentTab> {
  final _formKey = GlobalKey<FormState>();
  final _patientIdController = TextEditingController();
  String? _selectedSiteId;
  List<Map<String, dynamic>> _sites = [];
  bool _isLoading = true;
  String? _generatedCode;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    super.dispose();
  }

  Future<void> _loadSites() async {
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final assignedSites = authService.currentUser?.assignedSites ?? [];

      var query = SupabaseConfig.client.from('sites').select();

      // Filter to assigned sites if not admin
      if (assignedSites.isNotEmpty) {
        query = query.in_('site_id', assignedSites);
      }

      final response = await query;

      setState(() {
        _sites = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading sites: $e');
      setState(() => _isLoading = false);
    }
  }

  String _generateLinkingCode() {
    // Generate 10-character code: XXXXX-XXXXX
    // Use non-ambiguous characters (no 0, O, 1, I, l)
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    final uuid = const Uuid().v4();
    final combined = random + uuid;

    String code = '';
    for (int i = 0; i < 10; i++) {
      final index = combined.codeUnitAt(i % combined.length) % chars.length;
      code += chars[index];
      if (i == 4) code += '-';
    }
    return code;
  }

  Future<void> _enrollPatient() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSiteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a site')),
      );
      return;
    }

    try {
      final linkingCode = _generateLinkingCode();
      final patientId = _patientIdController.text.trim();

      await SupabaseConfig.client.from('patients').insert({
        'patient_id': patientId,
        'site_id': _selectedSiteId,
        'linking_code': linkingCode,
        'is_active': true,
      });

      setState(() {
        _generatedCode = linkingCode;
        _patientIdController.clear();
        _selectedSiteId = null;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Patient Enrolled'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Patient $patientId enrolled successfully!'),
                const SizedBox(height: 16),
                const Text(
                  'Linking Code:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  linkingCode,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Share this code with the patient to link their mobile app.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: linkingCode));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied to clipboard')),
                    );
                  }
                },
                child: const Text('Copy Code'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error enrolling patient: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Enroll New Patient',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter the patient ID from the IRT system and select their clinical site.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _patientIdController,
                      decoration: const InputDecoration(
                        labelText: 'Patient ID (from IRT)',
                        hintText: 'SSS-PPPPPPP',
                        helperText: 'Format: SSS-PPPPPPP',
                        prefixIcon: Icon(Icons.badge),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter patient ID';
                        }
                        // Basic format validation (can be customized)
                        if (!RegExp(r'^\d{3}-\d{7}$').hasMatch(value)) {
                          return 'Invalid format. Use: SSS-PPPPPPP';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      value: _selectedSiteId,
                      decoration: const InputDecoration(
                        labelText: 'Clinical Site',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      items: _sites.map((site) {
                        return DropdownMenuItem(
                          value: site['site_id'] as String,
                          child: Text(
                            '${site['site_name']} (${site['site_number']})',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedSiteId = value);
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a site';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _enrollPatient,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Enroll Patient'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'The system will generate a unique linking code. '
                            'Share this code with the patient to link their mobile app.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
