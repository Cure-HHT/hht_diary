import 'dart:io';

import 'package:flutter/material.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Wrap a widget in MaterialApp for testing
Widget wrapWithMaterialApp(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

/// Load questionnaire definitions from the JSON asset
List<QuestionnaireDefinition> loadTestDefinitions() {
  // Navigate up from eq/test to common-dart/trial_data_types
  final jsonString = File(
    '../../common-dart/trial_data_types/assets/data/questionnaires.json',
  ).readAsStringSync();
  return QuestionnaireDefinition.loadAll(jsonString);
}

/// Get the NOSE HHT definition for testing
QuestionnaireDefinition noseHhtDefinition() {
  return loadTestDefinitions().firstWhere((d) => d.id == 'nose_hht');
}

/// Get the QoL definition for testing
QuestionnaireDefinition qolDefinition() {
  return loadTestDefinitions().firstWhere((d) => d.id == 'hht_qol');
}
