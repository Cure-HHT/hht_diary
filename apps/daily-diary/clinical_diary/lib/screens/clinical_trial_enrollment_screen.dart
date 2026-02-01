// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/widgets/enrollment_success_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Clinical trial enrollment screen with 10-character code input (XXXXX-XXXXX)
/// Accessed from the user profile menu, not at app startup
class ClinicalTrialEnrollmentScreen extends StatefulWidget {
  const ClinicalTrialEnrollmentScreen({
    required this.enrollmentService,
    super.key,
  });
  final EnrollmentService enrollmentService;

  @override
  State<ClinicalTrialEnrollmentScreen> createState() =>
      _ClinicalTrialEnrollmentScreenState();
}

class _ClinicalTrialEnrollmentScreenState
    extends State<ClinicalTrialEnrollmentScreen> {
  final _code1Controller = TextEditingController();
  final _code2Controller = TextEditingController();
  final _code1FocusNode = FocusNode();
  final _code2FocusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;
  bool _hasAgreedToSharing = false;
  bool _shareDataPriorToEnrollment = false;
  bool _showSuccessDialog = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the first text field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _code1FocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _code1Controller.dispose();
    _code2Controller.dispose();
    _code1FocusNode.dispose();
    _code2FocusNode.dispose();
    super.dispose();
  }

  bool get _isComplete =>
      _code1Controller.text.length == 5 &&
      _code2Controller.text.length == 5 &&
      _hasAgreedToSharing;

  String get _fullCode => _code1Controller.text + _code2Controller.text;

  Future<void> _enroll() async {
    if (!_isComplete) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.enrollmentService.enroll(_fullCode);

      // Show success dialog
      setState(() {
        _showSuccessDialog = true;
      });

      // Wait 2 seconds then close
      await Future<void>.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on EnrollmentException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      if (mounted && !_showSuccessDialog) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onCode1Changed(String value) {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }

    // Auto-focus next field when this one is complete
    if (value.length == 5) {
      _code2FocusNode.requestFocus();
    }
    setState(() {});
  }

  void _onCode2Changed(String value) {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Header with back button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Clinical Trial Enrollment',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),

                        // Title
                        Text(
                          'Enter Enrollment Code',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 12),

                        // Description
                        Text(
                          'Please enter the 10-digit enrollment code provided by your research coordinator.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 32),

                        // Code input fields (XXXXX - XXXXX)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // First 5 characters
                            Expanded(
                              child: TextField(
                                controller: _code1Controller,
                                focusNode: _code1FocusNode,
                                enabled: !_isLoading,
                                textAlign: TextAlign.center,
                                textCapitalization:
                                    TextCapitalization.characters,
                                maxLength: 5,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      letterSpacing: 4,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                decoration: InputDecoration(
                                  hintText: 'XXXXX',
                                  hintStyle: TextStyle(
                                    letterSpacing: 4,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.3),
                                  ),
                                  counterText: '',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp('[a-zA-Z0-9]'),
                                  ),
                                  UpperCaseTextFormatter(),
                                ],
                                onChanged: _onCode1Changed,
                              ),
                            ),

                            // Dash separator
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                '-',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                              ),
                            ),

                            // Second 5 characters
                            Expanded(
                              child: TextField(
                                controller: _code2Controller,
                                focusNode: _code2FocusNode,
                                enabled: !_isLoading,
                                textAlign: TextAlign.center,
                                textCapitalization:
                                    TextCapitalization.characters,
                                maxLength: 5,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      letterSpacing: 4,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                decoration: InputDecoration(
                                  hintText: 'XXXXX',
                                  hintStyle: TextStyle(
                                    letterSpacing: 4,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.3),
                                  ),
                                  counterText: '',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp('[a-zA-Z0-9]'),
                                  ),
                                  UpperCaseTextFormatter(),
                                ],
                                onChanged: _onCode2Changed,
                                onSubmitted: (_) => _enroll(),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Code format hint
                        Text(
                          'Code format: XXXXX-XXXXX (letters and numbers)',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 24),

                        // Sharing agreement checkboxes
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            border: Border.all(color: Colors.blue.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // Optional: Share data prior to enrollment
                              InkWell(
                                onTap: _isLoading
                                    ? null
                                    : () => setState(
                                        () => _shareDataPriorToEnrollment =
                                            !_shareDataPriorToEnrollment,
                                      ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: _shareDataPriorToEnrollment,
                                      onChanged: _isLoading
                                          ? null
                                          : (value) => setState(
                                              () =>
                                                  _shareDataPriorToEnrollment =
                                                      value ?? false,
                                            ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(
                                          'Share data prior to enrollment (optional)',
                                          style: TextStyle(
                                            color: Colors.blue.shade800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Required: Consent to sharing agreement
                              InkWell(
                                onTap: _isLoading
                                    ? null
                                    : () => setState(
                                        () => _hasAgreedToSharing =
                                            !_hasAgreedToSharing,
                                      ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: _hasAgreedToSharing,
                                      onChanged: _isLoading
                                          ? null
                                          : (value) => setState(
                                              () => _hasAgreedToSharing =
                                                  value ?? false,
                                            ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(
                                          'I have read, understand, and consent to the sharing agreement for this clinical trial',
                                          style: TextStyle(
                                            color: Colors.blue.shade800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Error message
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Enroll button
                        FilledButton(
                          onPressed: _isLoading || !_isComplete
                              ? null
                              : _enroll,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Enroll in Clinical Trial',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Success dialog overlay
        if (_showSuccessDialog)
          const ColoredBox(
            color: Colors.black54,
            child: Center(child: EnrollmentSuccessDialog()),
          ),
      ],
    );
  }
}

/// Text input formatter that converts to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
