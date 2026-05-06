import 'package:flutter/material.dart';

/// Small dot rendered in the lower-right of a calendar cell to indicate
/// the day has at least one completed questionnaire submission.
///
/// The fill and outline match the questionnaire task/event cards on the
/// home screen (blue-50 fill, blue-200 outline) so the calendar cell
/// reads as a tiny version of the same artifact. Used in both
/// `CalendarOverlay` and `CalendarScreen` so the visual is owned in one
/// place.
class QuestionnaireDot extends StatelessWidget {
  const QuestionnaireDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
    );
  }
}
