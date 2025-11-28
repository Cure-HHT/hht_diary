// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:flutter/material.dart';

/// Supported locales for the app
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  static const Map<String, String> _languageNames = {
    'en': 'English',
    'es': 'Espanol',
    'fr': 'Francais',
  };

  static String getLanguageName(String code) {
    return _languageNames[code] ?? code;
  }

  // Translations map
  static final Map<String, Map<String, String>> _localizedStrings = {
    'en': {
      // General
      'appTitle': 'Nosebleed Diary',
      'back': 'Back',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'close': 'Close',
      'today': 'Today',
      'yesterday': 'Yesterday',
      'calendar': 'Calendar',

      // Home Screen
      'recordNosebleed': 'Record Nosebleed',
      'noEventsToday': 'no events today',
      'noEventsYesterday': 'no events yesterday',
      'incompleteRecords': 'Incomplete Records',

      // Settings
      'settings': 'Settings',
      'colorScheme': 'Color Scheme',
      'chooseAppearance': 'Choose your preferred appearance',
      'lightMode': 'Light Mode',
      'lightModeDescription': 'Bright appearance with light backgrounds',
      'darkMode': 'Dark Mode',
      'darkModeDescription': 'Reduced brightness with dark backgrounds',
      'accessibility': 'Accessibility',
      'accessibilityDescription':
          'Customize the app for better readability and usability',
      'dyslexiaFriendlyFont': 'Dyslexia-friendly font',
      'dyslexiaFontDescription':
          'Use OpenDyslexic font for improved readability.',
      'learnMoreOpenDyslexic': 'Learn more at opendyslexic.org',
      'largerTextAndControls': 'Larger Text and Controls',
      'largerTextDescription':
          'Increase the size of text and interactive elements for easier reading and navigation',
      'language': 'Language',
      'languageDescription': 'Choose your preferred language',
      'accessibilityAndPreferences': 'Accessibility & Preferences',
      'privacy': 'Privacy',
      'enrollInClinicalTrial': 'Enroll in Clinical Trial',

      // Calendar
      'selectDate': 'Select Date',
      'nosebleedEvents': 'Nosebleed events',
      'noNosebleeds': 'No nosebleeds',
      'unknown': 'Unknown',
      'incompleteMissing': 'Incomplete/Missing',
      'notRecorded': 'Not recorded',
      'tapToAddOrEdit': 'Tap a date to add or edit events',

      // Recording
      'whenDidItStart': 'When did the nosebleed start?',
      'whenDidItStop': 'When did the nosebleed stop?',
      'howSevere': 'How severe was it?',
      'anyNotes': 'Any additional notes?',
      'notesPlaceholder': 'Optional notes about this nosebleed...',

      // Severity
      'spotting': 'Spotting',
      'dripping': 'Dripping',
      'drippingQuickly': 'Dripping quickly',
      'steadyStream': 'Steady stream',
      'pouring': 'Pouring',
      'gushing': 'Gushing',

      // Yesterday banner
      'confirmYesterday': 'Confirm Yesterday',
      'didYouHaveNosebleeds': 'Did you have nosebleeds?',
      'noNosebleedsYesterday': 'No nosebleeds',
      'hadNosebleeds': 'Had nosebleeds',
      'dontRemember': "Don't remember",

      // Enrollment
      'enrollmentTitle': 'Enroll in Clinical Trial',
      'enterEnrollmentCode': 'Enter your enrollment code',
      'enrollmentCodeHint': 'XXXXX-XXXXX',
      'enroll': 'Enroll',
      'enrollmentSuccess': 'Successfully enrolled!',
      'enrollmentError': 'Enrollment failed',

      // Delete confirmation
      'deleteRecord': 'Delete Record',
      'selectDeleteReason': 'Please select a reason for deleting this record:',
      'enteredByMistake': 'Entered by mistake',
      'duplicateEntry': 'Duplicate entry',
      'incorrectInformation': 'Incorrect information',
      'other': 'Other',
      'pleaseSpecify': 'Please specify',
    },
    'es': {
      // General
      'appTitle': 'Diario de Hemorragias Nasales',
      'back': 'Atras',
      'cancel': 'Cancelar',
      'save': 'Guardar',
      'delete': 'Eliminar',
      'close': 'Cerrar',
      'today': 'Hoy',
      'yesterday': 'Ayer',
      'calendar': 'Calendario',

      // Home Screen
      'recordNosebleed': 'Registrar Hemorragia Nasal',
      'noEventsToday': 'sin eventos hoy',
      'noEventsYesterday': 'sin eventos ayer',
      'incompleteRecords': 'Registros Incompletos',

      // Settings
      'settings': 'Configuracion',
      'colorScheme': 'Esquema de Colores',
      'chooseAppearance': 'Elige tu apariencia preferida',
      'lightMode': 'Modo Claro',
      'lightModeDescription': 'Apariencia brillante con fondos claros',
      'darkMode': 'Modo Oscuro',
      'darkModeDescription': 'Brillo reducido con fondos oscuros',
      'accessibility': 'Accesibilidad',
      'accessibilityDescription':
          'Personaliza la aplicacion para mejor legibilidad y usabilidad',
      'dyslexiaFriendlyFont': 'Fuente amigable para dislexia',
      'dyslexiaFontDescription':
          'Usa la fuente OpenDyslexic para mejor legibilidad.',
      'learnMoreOpenDyslexic': 'Mas informacion en opendyslexic.org',
      'largerTextAndControls': 'Texto y Controles Mas Grandes',
      'largerTextDescription':
          'Aumenta el tamano del texto y elementos interactivos para facilitar la lectura y navegacion',
      'language': 'Idioma',
      'languageDescription': 'Elige tu idioma preferido',
      'accessibilityAndPreferences': 'Accesibilidad y Preferencias',
      'privacy': 'Privacidad',
      'enrollInClinicalTrial': 'Inscribirse en Ensayo Clinico',

      // Calendar
      'selectDate': 'Seleccionar Fecha',
      'nosebleedEvents': 'Eventos de hemorragia nasal',
      'noNosebleeds': 'Sin hemorragias nasales',
      'unknown': 'Desconocido',
      'incompleteMissing': 'Incompleto/Faltante',
      'notRecorded': 'No registrado',
      'tapToAddOrEdit': 'Toca una fecha para agregar o editar eventos',

      // Recording
      'whenDidItStart': 'Cuando empezo la hemorragia nasal?',
      'whenDidItStop': 'Cuando paro la hemorragia nasal?',
      'howSevere': 'Que tan severa fue?',
      'anyNotes': 'Alguna nota adicional?',
      'notesPlaceholder': 'Notas opcionales sobre esta hemorragia nasal...',

      // Severity
      'spotting': 'Manchado',
      'dripping': 'Goteo',
      'drippingQuickly': 'Goteo rapido',
      'steadyStream': 'Flujo constante',
      'pouring': 'Derramando',
      'gushing': 'Brotando',

      // Yesterday banner
      'confirmYesterday': 'Confirmar Ayer',
      'didYouHaveNosebleeds': 'Tuviste hemorragias nasales?',
      'noNosebleedsYesterday': 'Sin hemorragias nasales',
      'hadNosebleeds': 'Tuve hemorragias nasales',
      'dontRemember': 'No recuerdo',

      // Enrollment
      'enrollmentTitle': 'Inscribirse en Ensayo Clinico',
      'enterEnrollmentCode': 'Ingresa tu codigo de inscripcion',
      'enrollmentCodeHint': 'XXXXX-XXXXX',
      'enroll': 'Inscribirse',
      'enrollmentSuccess': 'Inscripcion exitosa!',
      'enrollmentError': 'Error en la inscripcion',

      // Delete confirmation
      'deleteRecord': 'Eliminar Registro',
      'selectDeleteReason':
          'Por favor selecciona una razon para eliminar este registro:',
      'enteredByMistake': 'Ingresado por error',
      'duplicateEntry': 'Entrada duplicada',
      'incorrectInformation': 'Informacion incorrecta',
      'other': 'Otro',
      'pleaseSpecify': 'Por favor especifica',
    },
    'fr': {
      // General
      'appTitle': 'Journal des Saignements de Nez',
      'back': 'Retour',
      'cancel': 'Annuler',
      'save': 'Enregistrer',
      'delete': 'Supprimer',
      'close': 'Fermer',
      'today': "Aujourd'hui",
      'yesterday': 'Hier',
      'calendar': 'Calendrier',

      // Home Screen
      'recordNosebleed': 'Enregistrer un Saignement',
      'noEventsToday': "pas d'evenements aujourd'hui",
      'noEventsYesterday': "pas d'evenements hier",
      'incompleteRecords': 'Enregistrements Incomplets',

      // Settings
      'settings': 'Parametres',
      'colorScheme': 'Schema de Couleurs',
      'chooseAppearance': 'Choisissez votre apparence preferee',
      'lightMode': 'Mode Clair',
      'lightModeDescription': 'Apparence lumineuse avec des fonds clairs',
      'darkMode': 'Mode Sombre',
      'darkModeDescription': 'Luminosite reduite avec des fonds sombres',
      'accessibility': 'Accessibilite',
      'accessibilityDescription':
          "Personnalisez l'application pour une meilleure lisibilite et utilisabilite",
      'dyslexiaFriendlyFont': 'Police adaptee a la dyslexie',
      'dyslexiaFontDescription':
          'Utilisez la police OpenDyslexic pour une meilleure lisibilite.',
      'learnMoreOpenDyslexic': 'En savoir plus sur opendyslexic.org',
      'largerTextAndControls': 'Texte et Controles Plus Grands',
      'largerTextDescription':
          'Augmentez la taille du texte et des elements interactifs pour faciliter la lecture et la navigation',
      'language': 'Langue',
      'languageDescription': 'Choisissez votre langue preferee',
      'accessibilityAndPreferences': 'Accessibilite et Preferences',
      'privacy': 'Confidentialite',
      'enrollInClinicalTrial': "S'inscrire a un Essai Clinique",

      // Calendar
      'selectDate': 'Selectionner une Date',
      'nosebleedEvents': 'Evenements de saignement de nez',
      'noNosebleeds': 'Pas de saignements de nez',
      'unknown': 'Inconnu',
      'incompleteMissing': 'Incomplet/Manquant',
      'notRecorded': 'Non enregistre',
      'tapToAddOrEdit':
          'Appuyez sur une date pour ajouter ou modifier des evenements',

      // Recording
      'whenDidItStart': 'Quand le saignement de nez a-t-il commence?',
      'whenDidItStop': "Quand le saignement de nez s'est-il arrete?",
      'howSevere': 'Quelle etait la gravite?',
      'anyNotes': 'Des notes supplementaires?',
      'notesPlaceholder':
          'Notes optionnelles sur ce saignement de nez...',

      // Severity
      'spotting': 'Taches',
      'dripping': 'Gouttes',
      'drippingQuickly': 'Gouttes rapides',
      'steadyStream': 'Flux constant',
      'pouring': 'Coulant',
      'gushing': 'Jaillissant',

      // Yesterday banner
      'confirmYesterday': 'Confirmer Hier',
      'didYouHaveNosebleeds': 'Avez-vous eu des saignements de nez?',
      'noNosebleedsYesterday': 'Pas de saignements de nez',
      'hadNosebleeds': "J'ai eu des saignements de nez",
      'dontRemember': 'Je ne me souviens pas',

      // Enrollment
      'enrollmentTitle': "S'inscrire a un Essai Clinique",
      'enterEnrollmentCode': "Entrez votre code d'inscription",
      'enrollmentCodeHint': 'XXXXX-XXXXX',
      'enroll': "S'inscrire",
      'enrollmentSuccess': 'Inscription reussie!',
      'enrollmentError': "Echec de l'inscription",

      // Delete confirmation
      'deleteRecord': "Supprimer l'Enregistrement",
      'selectDeleteReason':
          'Veuillez selectionner une raison pour supprimer cet enregistrement:',
      'enteredByMistake': 'Entre par erreur',
      'duplicateEntry': 'Entree en double',
      'incorrectInformation': 'Information incorrecte',
      'other': 'Autre',
      'pleaseSpecify': 'Veuillez preciser',
    },
  };

  String translate(String key) {
    return _localizedStrings[locale.languageCode]?[key] ??
        _localizedStrings['en']?[key] ??
        key;
  }

  // Convenience getters for common strings
  String get appTitle => translate('appTitle');
  String get back => translate('back');
  String get cancel => translate('cancel');
  String get save => translate('save');
  String get delete => translate('delete');
  String get close => translate('close');
  String get today => translate('today');
  String get yesterday => translate('yesterday');
  String get calendar => translate('calendar');
  String get recordNosebleed => translate('recordNosebleed');
  String get noEventsToday => translate('noEventsToday');
  String get noEventsYesterday => translate('noEventsYesterday');
  String get incompleteRecords => translate('incompleteRecords');
  String get settings => translate('settings');
  String get colorScheme => translate('colorScheme');
  String get chooseAppearance => translate('chooseAppearance');
  String get lightMode => translate('lightMode');
  String get lightModeDescription => translate('lightModeDescription');
  String get darkMode => translate('darkMode');
  String get darkModeDescription => translate('darkModeDescription');
  String get accessibility => translate('accessibility');
  String get accessibilityDescription => translate('accessibilityDescription');
  String get dyslexiaFriendlyFont => translate('dyslexiaFriendlyFont');
  String get dyslexiaFontDescription => translate('dyslexiaFontDescription');
  String get learnMoreOpenDyslexic => translate('learnMoreOpenDyslexic');
  String get largerTextAndControls => translate('largerTextAndControls');
  String get largerTextDescription => translate('largerTextDescription');
  String get language => translate('language');
  String get languageDescription => translate('languageDescription');
  String get accessibilityAndPreferences =>
      translate('accessibilityAndPreferences');
  String get privacy => translate('privacy');
  String get enrollInClinicalTrial => translate('enrollInClinicalTrial');
  String get selectDate => translate('selectDate');
  String get nosebleedEvents => translate('nosebleedEvents');
  String get noNosebleeds => translate('noNosebleeds');
  String get unknown => translate('unknown');
  String get incompleteMissing => translate('incompleteMissing');
  String get notRecorded => translate('notRecorded');
  String get tapToAddOrEdit => translate('tapToAddOrEdit');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'es', 'fr'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
