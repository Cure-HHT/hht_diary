import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

import '../models/site_option_view.dart';
import 'panel_tint.dart';
import 'user_lifecycle_dialogs.dart' show UserFlowBackLink;

/// Email-format gate for the user form (mirrors the login screen's
/// rule): one non-whitespace local part, an @, and a dotted domain.
/// The server stays authoritative; this only blocks obvious typos
/// before an account is created against them.
final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidUserEmail(String email) => _emailRe.hasMatch(email.trim());

/// Splits a stored display name into the form's (first, last) fields:
/// first token vs. remainder. The inverse of how the form composes the
/// display name (`'$first $last'`), so round-trips are stable; names
/// stored before the split-field form simply put everything after the
/// first word into Last Name.
(String, String) splitDisplayName(String name) {
  final trimmed = name.trim();
  final space = trimmed.indexOf(' ');
  if (space < 0) return (trimmed, '');
  return (trimmed.substring(0, space), trimmed.substring(space + 1).trim());
}

/// What the user typed/selected in the Create / Edit User form.
@immutable
class UserFormData {
  const UserFormData({
    required this.name,
    required this.email,
    required this.roles,
    required this.sites,
  });

  /// Composed display name — `'$firstName $lastName'`. The backend
  /// models a single name string; the First/Last split exists only in
  /// the form (per the Figma) until localization needs more.
  final String name;
  final String email;

  /// Selected backend-canonical role names.
  final Set<String> roles;

  /// Selected site ids (relevant only while a site-scoped role is
  /// selected; cleared of meaning otherwise — the submit handler decides).
  final Set<String> sites;
}

/// Create User / Edit User dialog (Figma: User Managment / Create New
/// User, User Details / Edit User Modal).
///
/// Shared form: Name*, Email*, Roles* checkbox list, and — while any
/// selected role is site-scoped — an Assigned Sites* boxed checklist.
/// The edit variant shows a warning banner about session termination.
///
/// Pure presentation. [onSubmit] is the only side-effect seam: it
/// resolves to `null` on success (dialog closes) or an error message
/// (rendered in an [AppBanner], form stays open). The dialog owns
/// in-flight state and disables inputs while submitting.
class UserFormDialog extends StatefulWidget {
  const UserFormDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.submitLabel,
    required this.roleOptions,
    required this.siteScopedRoles,
    required this.siteOptions,
    required this.onSubmit,
    this.roleDisplayName,
    this.initialFirstName = '',
    this.initialLastName = '',
    this.initialEmail = '',
    this.initialRoles = const <String>{},
    this.initialSites = const <String>{},
    this.warning,
    this.warningTitle,
    this.onBack,
    this.sitesLoading = false,
  });

  final String title;
  final String subtitle;
  final String submitLabel;

  /// Backend-canonical role names to offer, in display order.
  final List<String> roleOptions;

  /// The subset of [roleOptions] whose assignment binds to sites — while
  /// any is selected the Assigned Sites checklist renders and requires
  /// at least one selection.
  final Set<String> siteScopedRoles;

  /// Sites available for assignment, already sorted for display.
  final List<SiteOptionView> siteOptions;

  /// Maps a backend role name to its display label. Defaults to the raw
  /// name when null.
  final String Function(String role)? roleDisplayName;

  final String initialFirstName;
  final String initialLastName;
  final String initialEmail;
  final Set<String> initialRoles;
  final Set<String> initialSites;

  /// Warning banner under the form (edit variant: "Active sessions will
  /// be terminated…"). Hidden when null.
  final String? warning;

  /// Bold first line inside the warning banner (Figma: the edit
  /// variant's titled amber panel). Ignored when [warning] is null.
  final String? warningTitle;

  /// Invoked after the dialog pops itself via the "← User Details"
  /// back-link; null hides the link (create flow / kebab-launched edit).
  final VoidCallback? onBack;

  /// True while the wiring layer's sites subscription hasn't delivered
  /// yet — renders a placeholder in the checklist box.
  final bool sitesLoading;

  /// Resolves to null on success, or a user-facing error message.
  final Future<String?> Function(UserFormData data) onSubmit;

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  late final TextEditingController _firstName = TextEditingController(
    text: widget.initialFirstName,
  );
  late final TextEditingController _lastName = TextEditingController(
    text: widget.initialLastName,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  late final Set<String> _roles = {...widget.initialRoles};
  late final Set<String> _sites = {...widget.initialSites};
  bool _submitting = false;
  String? _error;

  bool get _needsSites => _roles.any(widget.siteScopedRoles.contains);

  String get _composedName =>
      '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();

  /// Inline error under the email field once the user has typed
  /// something that isn't a plausible address.
  String? get _emailError =>
      _email.text.trim().isEmpty || isValidUserEmail(_email.text)
      ? null
      : 'Enter a valid email address.';

  /// Inline error under the Assigned Sites checklist while a site-scoped role
  /// (Study Coordinator / CRA) is selected but no Site is chosen — covers both
  /// creating a site-scoped user and editing one down to zero Sites.
  // Implements: DIARY-PRD-user-account-create/A — a site-scoped role must carry
  //   at least one Site before the account is created.
  // Implements: DIARY-PRD-user-account-edit/C — blocks an edit that would leave
  //   a site-scoped user with zero Sites. The server stays authoritative; this
  //   only surfaces the failure inline before submit.
  String? get _sitesError =>
      _needsSites && _sites.isEmpty && !widget.sitesLoading
      ? 'Select at least one site for the selected role.'
      : null;

  bool get _canSubmit {
    if (_submitting) return false;
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      return false;
    }
    if (!isValidUserEmail(_email.text)) return false;
    if (_roles.isEmpty) return false;
    if (_needsSites && _sites.isEmpty) return false;
    return true;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await widget.onSubmit(
      UserFormData(
        name: _composedName,
        email: _email.text.trim(),
        roles: {..._roles},
        // Only meaningful while a site-scoped role is selected; pass the
        // selection through regardless and let the handler diff.
        sites: {..._sites},
      ),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppDialog(
      size: AppDialogSize.small,
      title: widget.title,
      subtitle: widget.subtitle,
      breadcrumb: widget.onBack == null
          ? null
          : UserFlowBackLink(onBack: widget.onBack!, enabled: !_submitting),
      dismissible: !_submitting,
      semanticId: 'user-form-dialog',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: 'First Name',
            required: true,
            controller: _firstName,
            enabled: !_submitting,
            semanticId: 'user-form-first-name',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Last Name',
            required: true,
            controller: _lastName,
            enabled: !_submitting,
            semanticId: 'user-form-last-name',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Email',
            required: true,
            controller: _email,
            enabled: !_submitting,
            keyboardType: TextInputType.emailAddress,
            errorText: _emailError,
            semanticId: 'user-form-email',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _FieldLabel(label: 'Roles', required: true),
          const SizedBox(height: 4),
          for (final role in widget.roleOptions)
            AppCheckbox(
              value: _roles.contains(role),
              enabled: !_submitting,
              label: widget.roleDisplayName?.call(role) ?? role,
              semanticId: 'user-form-role-$role',
              onChanged: (v) => setState(() {
                if (v ?? false) {
                  _roles.add(role);
                } else {
                  _roles.remove(role);
                }
              }),
            ),
          if (_needsSites) ...[
            const SizedBox(height: 16),
            _FieldLabel(label: 'Assigned Sites', required: true),
            const SizedBox(height: 4),
            Text(
              'Select the sites this user will have access to.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _SitesChecklist(
              options: widget.siteOptions,
              selected: _sites,
              loading: widget.sitesLoading,
              enabled: !_submitting,
              onToggle: (id, v) => setState(() {
                if (v) {
                  _sites.add(id);
                } else {
                  _sites.remove(id);
                }
              }),
            ),
            if (_sitesError != null) ...[
              const SizedBox(height: 4),
              Text(
                _sitesError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                key: const Key('user-form-sites-error'),
              ),
            ],
          ],
          if (widget.warning != null) ...[
            const SizedBox(height: 16),
            AppBanner(
              severity: AppBannerSeverity.warning,
              title: widget.warningTitle,
              message: widget.warning!,
              semanticId: 'user-form-warning',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppBanner(
              severity: AppBannerSeverity.error,
              message: _error!,
              semanticId: 'user-form-error',
            ),
          ],
          const SizedBox(height: 16),
          // Hairline above the footer actions (Figma: Create New User).
          const Divider(height: 1),
        ],
      ),
      actions: [
        AppButton(
          variant: AppButtonVariant.secondary,
          label: 'Cancel',
          semanticId: 'user-form-cancel',
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: widget.submitLabel,
          loading: _submitting,
          semanticId: 'user-form-submit',
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.required});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        text: label,
        style: theme.textTheme.labelLarge,
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: theme.colorScheme.error),
            ),
        ],
      ),
    );
  }
}

/// The boxed, scrollable site checklist (Figma: Create New User / Sites).
class _SitesChecklist extends StatelessWidget {
  const _SitesChecklist({
    required this.options,
    required this.selected,
    required this.loading,
    required this.enabled,
    required this.onToggle,
  });

  final List<SiteOptionView> options;
  final Set<String> selected;
  final bool loading;
  final bool enabled;
  final void Function(String id, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget content;
    if (loading) {
      content = Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Loading sites…',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else if (options.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'No sites available.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else {
      content = ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        children: [
          for (final site in options)
            AppCheckbox(
              value: selected.contains(site.id),
              enabled: enabled,
              label: site.label,
              semanticId: 'user-form-site-${site.id}',
              onChanged: (v) => onToggle(site.id, v ?? false),
            ),
        ],
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      width: double.infinity,
      decoration: BoxDecoration(
        color: kAdminPanelTint,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: content,
    );
  }
}
