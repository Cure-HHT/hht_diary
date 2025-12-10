import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Banner asking about yesterday's nosebleed status
class YesterdayBanner extends StatelessWidget {
  const YesterdayBanner({
    required this.onNoNosebleeds,
    required this.onHadNosebleeds,
    required this.onDontRemember,
    super.key,
  });
  final VoidCallback onNoNosebleeds;
  final VoidCallback onHadNosebleeds;
  final VoidCallback onDontRemember;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr = DateFormat('MMM d').format(yesterday);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow.shade200),
      ),
      child: Column(
        children: [
          Text(
            l10n.confirmYesterdayDate(dateStr),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.yellow.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.didYouHaveNosebleeds,
            style: TextStyle(color: Colors.yellow.shade900),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onHadNosebleeds,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.yellow.shade900,
                    side: BorderSide(color: Colors.yellow.shade300),
                    backgroundColor: Colors.white,
                  ),
                  child: Text(l10n.yes),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onNoNosebleeds,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.yellow.shade900,
                    side: BorderSide(color: Colors.yellow.shade300),
                    backgroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Text(l10n.no), const SizedBox(width: 4)],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDontRemember,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.yellow.shade900,
                    side: BorderSide(color: Colors.yellow.shade300),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: Text(
                    l10n.dontRemember,
                    style: const TextStyle(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
