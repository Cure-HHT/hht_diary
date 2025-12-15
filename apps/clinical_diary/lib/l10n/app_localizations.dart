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
    Locale('de'),
  ];

  static const Map<String, String> _languageNames = {
    'en': 'English',
    'es': 'Espanol',
    'fr': 'Francais',
    'de': 'Deutsch',
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
      'yes': 'Yes',
      'no': 'No',
      'ok': 'OK',
      'error': 'Error',
      'reset': 'Reset',

      // Home Screen
      'recordNosebleed': 'Record Nosebleed',
      'noEventsToday': 'no events today',
      'noEventsYesterday': 'no events yesterday',
      'incompleteRecords': 'Incomplete Records',
      'incompleteRecordSingular': '{0} incomplete record',
      'incompleteRecordPlural': '{0} incomplete records',
      'tapToComplete': 'Tap to complete',
      'exampleDataAdded': 'Example data added',
      'resetAllData': 'Reset All Data?',
      'resetAllDataMessage':
          'This will permanently delete all your recorded data. This action cannot be undone.',
      'allDataReset': 'All data has been reset',
      'endClinicalTrial': 'End Clinical Trial?',
      'endClinicalTrialMessage':
          'Are you sure you want to end your participation in the clinical trial? Your data will be retained but no longer synced.',
      'endTrial': 'End Trial',
      'leftClinicalTrial': 'You have left the clinical trial',
      'userMenu': 'User menu',
      'privacyComingSoon': 'Privacy settings coming soon',
      'switchedToSimpleUI': 'Switched to simple recording UI',
      'switchedToClassicUI': 'Switched to classic recording UI',
      'usingSimpleUI': 'Using simple UI (tap to switch)',
      'usingClassicUI': 'Using classic UI (tap for simple)',
      'noEvents': 'no events',

      // Login/Account
      'login': 'Login',
      'logout': 'Logout',
      'account': 'Account',
      'createAccount': 'Create Account',
      'savedCredentialsQuestion': 'Have you saved your username and password?',
      'credentialsAvailableInAccount':
          "If you didn't save your credentials, they are available in the Account page.",
      'yesLogout': 'Yes, Logout',
      'syncingData': 'Syncing your data...',
      'syncFailed': 'Sync Failed',
      'syncFailedMessage':
          'Could not sync your data to the server. Please check your internet connection and try again.',
      'loggedOut': 'You have been logged out',
      'privacyNotice': 'Privacy Notice',
      'privacyNoticeDescription':
          'For your privacy we do not use email addresses for accounts.',
      'noAtSymbol': '@ signs are not allowed for username.',
      'important': 'Important',
      'storeCredentialsSecurely': 'Store your username and password securely.',
      'lostCredentialsWarning':
          'If you lose your username and password then the app cannot send you a link to reset it.',
      'usernameRequired': 'Username is required',
      'usernameTooShort': 'Username must be at least {0} characters',
      'usernameNoAt': 'Username cannot contain @ symbol',
      'usernameLettersOnly': 'Only letters, numbers, and underscores allowed',
      'passwordRequired': 'Password is required',
      'passwordTooShort': 'Password must be at least {0} characters',
      'passwordsDoNotMatch': 'Passwords do not match',
      'username': 'Username',
      'enterUsername': 'Enter username (no @ symbol)',
      'password': 'Password',
      'enterPassword': 'Enter password',
      'confirmPassword': 'Confirm Password',
      'reenterPassword': 'Re-enter password',
      'noAccountCreate': "Don't have an account? Create one",
      'hasAccountLogin': 'Already have an account? Login',
      'minimumCharacters': 'Minimum {0} characters',

      // Account Profile
      'changePassword': 'Change Password',
      'currentPassword': 'Current Password',
      'currentPasswordRequired': 'Current password is required',
      'newPassword': 'New Password',
      'newPasswordRequired': 'New password is required',
      'confirmNewPassword': 'Confirm New Password',
      'passwordChangedSuccess': 'Password changed successfully',
      'yourCredentials': 'Your Credentials',
      'keepCredentialsSafe': 'Keep these safe - there is no password recovery.',
      'hidePassword': 'Hide password',
      'showPassword': 'Show password',
      'securityReminder': 'Security Reminder',
      'securityReminderText':
          'Write down your username and password and store them in a safe place. If you lose these credentials, you will not be able to recover your account.',

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
      'useAnimation': 'Use Animations',
      'useAnimationDescription':
          'Enable visual animations and transitions throughout the app',
      'compactView': 'Compact View',
      'compactViewDescription':
          'Reduce spacing between entries in the event list for a denser display',
      'language': 'Language',
      'languageDescription': 'Choose your preferred language',
      'accessibilityAndPreferences': 'Accessibility & Preferences',
      'privacy': 'Privacy',
      'enrollInClinicalTrial': 'Enroll in Clinical Trial',
      'comingSoon': 'Coming soon',
      'comingSoonEnglishOnly': 'Coming soon - English only for now',

      // Calendar
      'selectDate': 'Select Date',
      'nosebleedEvents': 'Nosebleed events',
      'noNosebleeds': 'No nosebleeds',
      'confirmedNoEvents': 'Confirmed no events for this day',
      'unknown': 'Unknown',
      'unableToRecallEvents': 'Unable to recall events for this day',
      'plusOneDay': '(+1 day)',
      'incomplete': 'Incomplete',
      'incompleteMissing': 'Incomplete/Missing',
      'notRecorded': 'Not recorded',
      'tapToAddOrEdit': 'Tap a date to add or edit events',

      // Recording
      'whenDidItStart': 'When did the nosebleed start?',
      'whenDidItStop': 'When did the nosebleed stop?',
      'howSevere': 'How intense is the nosebleed?',
      'selectBestOption': 'Select the option that best describes the bleeding',
      'anyNotes': 'Any additional notes?',
      'notesPlaceholder': 'Optional notes about this nosebleed...',
      'start': 'Start',
      'end': 'End',
      'selectIntensity': 'Tap to set',
      'notSet': 'Not set',
      'intensity': 'Intensity',
      'maxIntensity': 'Max Intensity',
      'nosebleedStart': 'Nosebleed Start',
      'setStartTime': 'Set Start Time',
      'nosebleedEnd': 'Nosebleed End',
      'nosebleedEndTime': 'Nosebleed End Time',
      'setEndTime': 'Set End Time',
      'completeRecord': 'Complete Record',
      'editRecord': 'Edit Record',
      'recordComplete': 'Record Complete',
      'reviewAndSave': 'Review the information and save when ready',
      'tapFieldToEdit': 'Tap any field above to edit it',
      'durationMinutes': 'Duration: {0} minutes',
      'cannotSaveOverlap':
          'Cannot save: This event overlaps with existing events. Please adjust the time.',
      'cannotSaveOverlapCount':
          'Cannot save: This event overlaps with {0} existing {1}',
      'event': 'event',
      'events': 'events',
      'failedToSave': 'Failed to save',
      'endTimeAfterStart': 'End time must be after start time',
      'updateNosebleed': 'Update Nosebleed',
      'addNosebleed': 'Add Nosebleed',
      'saveChanges': 'Save Changes',
      'finished': 'Finished',
      'deleteRecordTooltip': 'Delete record',
      'setFields': 'Set {0}',
      'saveAsIncomplete': 'Save as Incomplete?',
      'saveAsIncompleteDescription':
          'You have entered some information. Would you like to save it as an incomplete record?',
      'discard': 'Discard',
      'keepEditing': 'Keep Editing',

      // Intensity
      'spotting': 'Spotting',
      'dripping': 'Dripping',
      'drippingQuickly': 'Dripping quickly',
      'steadyStream': 'Steady stream',
      'pouring': 'Pouring',
      'gushing': 'Gushing',

      // Yesterday banner
      'confirmYesterday': 'Confirm Yesterday',
      'confirmYesterdayDate': 'Confirm Yesterday - {0}',
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

      // Time picker
      'cannotSelectFutureTime': 'Cannot select a time in the future',

      // Notes input
      'notes': 'Notes',
      'notesRequired': 'Required for clinical trial participants',
      'notesHint': 'Add any additional details about this nosebleed...',
      'next': 'Next',

      // Logo menu
      'appMenu': 'App menu',
      'dataManagement': 'Data Management',
      'exportData': 'Export Data',
      'importData': 'Import Data',
      'exportSuccess': 'Data exported successfully',
      'exportFailed': 'Failed to export data',
      'importSuccess': 'Imported {0} records',
      'importFailed': 'Failed to import data: {0}',
      'importConfirmTitle': 'Import Data',
      'importConfirmMessage':
          'This will import data from the selected file. '
          'Existing records will be preserved. Continue?',
      'clinicalTrialLabel': 'Clinical Trial',
      'instructionsAndFeedback': 'Instructions & Feedback',

      // Overlap warning
      'overlappingEventsDetected': 'Overlapping Events Detected',
      'overlappingEventsCount': 'This event overlaps with {0} existing {1}',
      'overlappingEventTimeRange':
          'This time overlaps with an existing nosebleed record from {0} to {1}',
      'viewConflictingRecord': 'View',

      // Enrollment screen
      'welcomeToNosebleedDiary': 'Welcome to\nNosebleed Diary',
      'enterCodeToGetStarted': 'Enter your enrollment code to get started.',
      'enrollmentCodePlaceholder': 'CUREHHT#',
      'getStarted': 'Get Started',
      'codeMustBe8Chars': 'Code must be 8 characters',
      'pleaseEnterEnrollmentCode': 'Please enter your enrollment code',

      // Date records screen
      'addNewEvent': 'Add new event',
      'noEventsRecordedForDay': 'No events recorded for this day',
      'eventCountSingular': '1 event',
      'eventCountPlural': '{0} events',

      // Profile screen
      'userProfile': 'User Profile',
      'enterYourName': 'Enter your name',
      'editName': 'Edit name',
      'shareWithCureHHT': 'Share with CureHHT',
      'stopSharingWithCureHHT': 'Stop Sharing with CureHHT',
      'privacyDataProtection': 'Privacy & Data Protection',
      'healthDataStoredLocally':
          'Your health data is stored locally on your device.',
      'dataSharedAnonymized':
          ' Anonymized data is shared with CureHHT for research purposes.',
      'clinicalTrialSharingActive':
          ' Clinical trial participation involves sharing anonymized data with researchers according to the study protocol.',
      'clinicalTrialEndedMessage':
          ' Clinical trial participation ended on {0}. Previously shared data remains with researchers indefinitely for scientific analysis.',
      'noDataSharedMessage':
          ' No data is shared with external parties unless you choose to participate in research or clinical trials.',
      'enrolledInClinicalTrialStatus': 'Enrolled in Clinical Trial',
      'clinicalTrialEnrollmentEnded': 'Clinical Trial Enrollment: Ended',
      'enrollmentCodeLabel': 'Enrollment Code: {0}',
      'enrolledLabel': 'Enrolled: {0}',
      'endedLabel': 'Ended: {0}',
      'sharingWithCureHHT': 'Sharing with CureHHT',
      'sharingNoteActive':
          'Note: The logo displayed on the homescreen of the app is a reminder that you are sharing your data with a 3rd party.',
      'sharingNoteEnded':
          'Note: Data shared during clinical trial participation remains with researchers indefinitely for scientific analysis.',

      // REQ-CAL-p00001: Old Entry Justification
      'oldEntryJustificationTitle': 'Old Entry Modification',
      'oldEntryJustificationPrompt':
          'This is an event more than one day old. Please explain why you are adding/changing it now:',
      'justificationPaperRecords': 'Entered from paper records',
      'justificationRemembered': 'Remembered specific event',
      'justificationEstimated': 'Estimated event',
      'confirm': 'Confirm',

      // REQ-CAL-p00002: Short Duration Confirmation
      'shortDurationTitle': 'Short Duration',
      'shortDurationMessage': 'Duration is under 1 minute, is that correct?',

      // REQ-CAL-p00003: Long Duration Confirmation
      'longDurationTitle': 'Long Duration',
      'longDurationMessage': 'Duration is over {0}, is that correct?',
      'durationMinutesShort': '{0}m',
      'durationHoursShort': '{0}h',
      'durationHoursMinutesShort': '{0}h {1}m',

      // Feature Flags (dev/qa only)
      'featureFlagsTitle': 'Feature Flags',
      'featureFlagsWarning':
          'These settings are for testing only. Changes affect app behavior.',
      'featureFlagsSponsorSelection': 'Sponsor Configuration',
      'featureFlagsSponsorId': 'Sponsor ID',
      'featureFlagsCurrentSponsor': 'Current sponsor: {0}',
      'featureFlagsLoad': 'Load',
      'featureFlagsLoadSuccess': 'Loaded configuration for {0}',
      'featureFlagsSectionUI': 'UI Features',
      'featureFlagsSectionValidation': 'Validation Features',
      'featureFlagsUseReviewScreen': 'Use Review Screen',
      'featureFlagsUseReviewScreenDescription':
          'Show review screen after ending a nosebleed',
      'featureFlagsUseAnimations': 'Use Animations',
      'featureFlagsUseAnimationsDescription':
          'Enable animations and show user preference toggle',
      'featureFlagsUseOnePageRecordingScreen': 'Use One-Page Recording Screen',
      'featureFlagsUseOnePageRecordingScreenDescription':
          'Use simplified one-page recording screen instead of multi-page flow',
      'featureFlagsOldEntryJustification': 'Old Entry Justification',
      'featureFlagsOldEntryJustificationDescription':
          'Require justification when editing entries older than one day',
      'featureFlagsShortDurationConfirmation': 'Short Duration Confirmation',
      'featureFlagsShortDurationConfirmationDescription':
          'Prompt to confirm durations of 1 minute or less',
      'featureFlagsLongDurationConfirmation': 'Long Duration Confirmation',
      'featureFlagsLongDurationConfirmationDescription':
          'Prompt to confirm durations exceeding the threshold',
      'featureFlagsLongDurationThreshold': 'Long Duration Threshold',
      'featureFlagsLongDurationThresholdDescription':
          'Current threshold: {0} minutes',
      'featureFlagsResetToDefaults': 'Reset to Defaults',
      'featureFlagsResetTitle': 'Reset Feature Flags?',
      'featureFlagsResetConfirmation':
          'Reset all feature flags to their default values?',
      'featureFlagsResetButton': 'Reset',
      'featureFlagsResetSuccess': 'Feature flags reset to defaults',
      // CUR-528: Font feature flags
      'featureFlagsSectionFonts': 'Font Accessibility',
      'featureFlagsFontSelectorVisible':
          'Font selector will be shown in Settings',
      'featureFlagsFontSelectorHidden':
          'Font selector will be hidden (only default font available)',
      'fontDescriptionRoboto': 'System default font',
      'fontDescriptionOpenDyslexic':
          'Font designed to help readers with dyslexia',
      'fontDescriptionAtkinson': 'Font optimized for low vision readers',
      'fontSelection': 'Font',
      'fontSelectionDescription': 'Choose a font that works best for you',
      'hours': 'hours',
      'hour': 'hour',

      // Version Update
      'updateAvailable': 'Update Available',
      'updateRequired': 'Update Required',
      'updateNow': 'Update Now',
      'later': 'Later',
      'newVersionAvailable': 'Version {0} is available',
      'updateRequiredMessage':
          'A new version is required to continue using this app. Please update now.',
      'currentVersionLabel': 'Current version:',
      'requiredVersionLabel': 'Required version:',
      'whatsNew': "What's New",
      'checkForUpdates': 'Check for updates',
      'youAreUpToDate': 'You are up to date',
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
      'yes': 'Si',
      'no': 'No',
      'ok': 'OK',
      'error': 'Error',
      'reset': 'Reiniciar',

      // Home Screen
      'recordNosebleed': 'Registrar Hemorragia Nasal',
      'noEventsToday': 'sin eventos hoy',
      'noEventsYesterday': 'sin eventos ayer',
      'incompleteRecords': 'Registros Incompletos',
      'tapToComplete': 'Toca para completar',
      'exampleDataAdded': 'Datos de ejemplo agregados',
      'resetAllData': 'Reiniciar todos los datos?',
      'resetAllDataMessage':
          'Esto eliminara permanentemente todos tus datos registrados. Esta accion no se puede deshacer.',
      'allDataReset': 'Todos los datos han sido reiniciados',
      'endClinicalTrial': 'Finalizar ensayo clinico?',
      'endClinicalTrialMessage':
          'Estas seguro de que deseas finalizar tu participacion en el ensayo clinico? Tus datos se conservaran pero ya no se sincronizaran.',
      'endTrial': 'Finalizar',
      'leftClinicalTrial': 'Has dejado el ensayo clinico',
      'userMenu': 'Menu de usuario',
      'privacyComingSoon': 'Configuracion de privacidad proximamente',
      'switchedToSimpleUI': 'Cambiado a interfaz simple',
      'switchedToClassicUI': 'Cambiado a interfaz clasica',
      'usingSimpleUI': 'Usando interfaz simple (toca para cambiar)',
      'usingClassicUI': 'Usando interfaz clasica (toca para simple)',
      'noEvents': 'sin eventos',

      // Login/Account
      'login': 'Iniciar sesion',
      'logout': 'Cerrar sesion',
      'account': 'Cuenta',
      'createAccount': 'Crear cuenta',
      'savedCredentialsQuestion': 'Has guardado tu usuario y contrasena?',
      'credentialsAvailableInAccount':
          'Si no guardaste tus credenciales, estan disponibles en la pagina de Cuenta.',
      'yesLogout': 'Si, cerrar sesion',
      'syncingData': 'Sincronizando tus datos...',
      'syncFailed': 'Error de sincronizacion',
      'syncFailedMessage':
          'No se pudieron sincronizar tus datos con el servidor. Por favor verifica tu conexion a internet e intenta de nuevo.',
      'loggedOut': 'Has cerrado sesion',
      'privacyNotice': 'Aviso de privacidad',
      'privacyNoticeDescription':
          'Para tu privacidad no usamos direcciones de correo electronico para las cuentas.',
      'noAtSymbol': 'No se permite el simbolo @ en el nombre de usuario.',
      'important': 'Importante',
      'storeCredentialsSecurely':
          'Guarda tu nombre de usuario y contrasena de forma segura.',
      'lostCredentialsWarning':
          'Si pierdes tu nombre de usuario y contrasena, la aplicacion no puede enviarte un enlace para restablecerla.',
      'usernameRequired': 'El nombre de usuario es requerido',
      'usernameTooShort':
          'El nombre de usuario debe tener al menos {0} caracteres',
      'usernameNoAt': 'El nombre de usuario no puede contener @',
      'usernameLettersOnly': 'Solo se permiten letras, numeros y guiones bajos',
      'passwordRequired': 'La contrasena es requerida',
      'passwordTooShort': 'La contrasena debe tener al menos {0} caracteres',
      'passwordsDoNotMatch': 'Las contrasenas no coinciden',
      'username': 'Nombre de usuario',
      'enterUsername': 'Ingresa nombre de usuario (sin @)',
      'password': 'Contrasena',
      'enterPassword': 'Ingresa contrasena',
      'confirmPassword': 'Confirmar contrasena',
      'reenterPassword': 'Vuelve a ingresar la contrasena',
      'noAccountCreate': 'No tienes cuenta? Crea una',
      'hasAccountLogin': 'Ya tienes cuenta? Inicia sesion',
      'minimumCharacters': 'Minimo {0} caracteres',

      // Account Profile
      'changePassword': 'Cambiar contrasena',
      'currentPassword': 'Contrasena actual',
      'currentPasswordRequired': 'La contrasena actual es requerida',
      'newPassword': 'Nueva contrasena',
      'newPasswordRequired': 'La nueva contrasena es requerida',
      'confirmNewPassword': 'Confirmar nueva contrasena',
      'passwordChangedSuccess': 'Contrasena cambiada exitosamente',
      'yourCredentials': 'Tus credenciales',
      'keepCredentialsSafe':
          'Guardalas de forma segura - no hay recuperacion de contrasena.',
      'hidePassword': 'Ocultar contrasena',
      'showPassword': 'Mostrar contrasena',
      'securityReminder': 'Recordatorio de seguridad',
      'securityReminderText':
          'Escribe tu nombre de usuario y contrasena y guardalos en un lugar seguro. Si pierdes estas credenciales, no podras recuperar tu cuenta.',

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
      'useAnimation': 'Usar Animaciones',
      'useAnimationDescription':
          'Habilitar animaciones visuales y transiciones en toda la aplicacion',
      'compactView': 'Vista Compacta',
      'compactViewDescription':
          'Reducir el espacio entre entradas en la lista de eventos para una visualizacion mas densa',
      'language': 'Idioma',
      'languageDescription': 'Elige tu idioma preferido',
      'accessibilityAndPreferences': 'Accesibilidad y Preferencias',
      'privacy': 'Privacidad',
      'enrollInClinicalTrial': 'Inscribirse en Ensayo Clinico',
      'comingSoon': 'Proximamente',
      'comingSoonEnglishOnly': 'Proximamente - Solo ingles por ahora',

      // Calendar
      'selectDate': 'Seleccionar Fecha',
      'nosebleedEvents': 'Eventos de hemorragia nasal',
      'noNosebleeds': 'Sin hemorragias nasales',
      'confirmedNoEvents': 'Confirmado sin eventos para este dia',
      'unknown': 'Desconocido',
      'unableToRecallEvents': 'No se pueden recordar los eventos de este dia',
      'plusOneDay': '(+1 dia)',
      'incomplete': 'Incompleto',
      'incompleteMissing': 'Incompleto/Faltante',
      'notRecorded': 'No registrado',
      'tapToAddOrEdit': 'Toca una fecha para agregar o editar eventos',

      // Recording
      'whenDidItStart': 'Cuando empezo la hemorragia nasal?',
      'whenDidItStop': 'Cuando paro la hemorragia nasal?',
      'howSevere': 'Que tan intensa es la hemorragia?',
      'selectBestOption': 'Selecciona la opcion que mejor describe el sangrado',
      'anyNotes': 'Alguna nota adicional?',
      'notesPlaceholder': 'Notas opcionales sobre esta hemorragia nasal...',
      'start': 'Inicio',
      'end': 'Fin',
      'selectIntensity': 'Toca para seleccionar',
      'notSet': 'No establecido',
      'intensity': 'Intensidad',
      'maxIntensity': 'Intensidad Máxima',
      'nosebleedStart': 'Inicio de hemorragia',
      'setStartTime': 'Establecer hora de inicio',
      'nosebleedEnd': 'Fin de hemorragia',
      'nosebleedEndTime': 'Hora de fin de hemorragia',
      'setEndTime': 'Establecer hora de fin',
      'completeRecord': 'Completar registro',
      'editRecord': 'Editar registro',
      'recordComplete': 'Registro completo',
      'reviewAndSave': 'Revisa la informacion y guarda cuando estes listo',
      'tapFieldToEdit': 'Toca cualquier campo arriba para editarlo',
      'durationMinutes': 'Duracion: {0} minutos',
      'cannotSaveOverlap':
          'No se puede guardar: Este evento se superpone con eventos existentes. Por favor ajusta la hora.',
      'cannotSaveOverlapCount':
          'No se puede guardar: Este evento se superpone con {0} {1} existente(s)',
      'event': 'evento',
      'events': 'eventos',
      'failedToSave': 'Error al guardar',
      'endTimeAfterStart':
          'La hora de fin debe ser despues de la hora de inicio',
      'updateNosebleed': 'Actualizar hemorragia',
      'addNosebleed': 'Agregar hemorragia',
      'saveChanges': 'Guardar cambios',
      'finished': 'Finalizado',
      'deleteRecordTooltip': 'Eliminar registro',
      'setFields': 'Establecer {0}',
      'saveAsIncomplete': 'Guardar como incompleto?',
      'saveAsIncompleteDescription':
          'Has ingresado alguna informacion. Te gustaria guardarla como un registro incompleto?',
      'discard': 'Descartar',
      'keepEditing': 'Seguir editando',

      // Intensity
      'spotting': 'Manchado',
      'dripping': 'Goteo',
      'drippingQuickly': 'Goteo rapido',
      'steadyStream': 'Flujo constante',
      'pouring': 'Derramando',
      'gushing': 'Brotando',

      // Yesterday banner
      'confirmYesterday': 'Confirmar Ayer',
      'confirmYesterdayDate': 'Confirmar Ayer - {0}',
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

      // Time picker
      'cannotSelectFutureTime': 'No se puede seleccionar una hora en el futuro',

      // Notes input
      'notes': 'Notas',
      'notesRequired': 'Requerido para participantes del ensayo clinico',
      'notesHint': 'Agrega detalles adicionales sobre esta hemorragia nasal...',
      'next': 'Siguiente',

      // Logo menu
      'appMenu': 'Menu de la aplicacion',
      'dataManagement': 'Gestion de Datos',
      'exportData': 'Exportar Datos',
      'importData': 'Importar Datos',
      'exportSuccess': 'Datos exportados exitosamente',
      'exportFailed': 'Error al exportar datos',
      'importSuccess': '{0} registros importados',
      'importFailed': 'Error al importar datos: {0}',
      'importConfirmTitle': 'Importar Datos',
      'importConfirmMessage':
          'Esto importara datos del archivo seleccionado. '
          'Los registros existentes se conservaran. Continuar?',
      'clinicalTrialLabel': 'Ensayo Clinico',
      'instructionsAndFeedback': 'Instrucciones y Comentarios',

      // Overlap warning
      'overlappingEventsDetected': 'Eventos Superpuestos Detectados',
      'overlappingEventsCount':
          'Este evento se superpone con {0} {1} existente(s)',
      'overlappingEventTimeRange':
          'Este horario se superpone con un registro de hemorragia nasal existente de {0} a {1}',
      'viewConflictingRecord': 'Ver',

      // Enrollment screen
      'welcomeToNosebleedDiary': 'Bienvenido a\nDiario de Hemorragias Nasales',
      'enterCodeToGetStarted':
          'Ingresa tu codigo de inscripcion para comenzar.',
      'enrollmentCodePlaceholder': 'CUREHHT#',
      'getStarted': 'Comenzar',
      'codeMustBe8Chars': 'El codigo debe tener 8 caracteres',
      'pleaseEnterEnrollmentCode': 'Por favor ingresa tu codigo de inscripcion',

      // Date records screen
      'addNewEvent': 'Agregar nuevo evento',
      'noEventsRecordedForDay': 'No hay eventos registrados para este dia',
      'eventCountSingular': '1 evento',
      'eventCountPlural': '{0} eventos',

      // Profile screen
      'userProfile': 'Perfil de Usuario',
      'enterYourName': 'Ingresa tu nombre',
      'editName': 'Editar nombre',
      'shareWithCureHHT': 'Compartir con CureHHT',
      'stopSharingWithCureHHT': 'Dejar de Compartir con CureHHT',
      'privacyDataProtection': 'Privacidad y Proteccion de Datos',
      'healthDataStoredLocally':
          'Tus datos de salud se almacenan localmente en tu dispositivo.',
      'dataSharedAnonymized':
          ' Los datos anonimizados se comparten con CureHHT para fines de investigacion.',
      'clinicalTrialSharingActive':
          ' La participacion en el ensayo clinico implica compartir datos anonimizados con investigadores segun el protocolo del estudio.',
      'clinicalTrialEndedMessage':
          ' La participacion en el ensayo clinico termino el {0}. Los datos compartidos previamente permanecen con los investigadores indefinidamente para analisis cientifico.',
      'noDataSharedMessage':
          ' No se comparten datos con terceros a menos que elijas participar en investigacion o ensayos clinicos.',
      'enrolledInClinicalTrialStatus': 'Inscrito en Ensayo Clinico',
      'clinicalTrialEnrollmentEnded':
          'Inscripcion al Ensayo Clinico: Terminada',
      'enrollmentCodeLabel': 'Codigo de Inscripcion: {0}',
      'enrolledLabel': 'Inscrito: {0}',
      'endedLabel': 'Terminado: {0}',
      'sharingWithCureHHT': 'Compartiendo con CureHHT',
      'sharingNoteActive':
          'Nota: El logo mostrado en la pantalla de inicio de la aplicacion es un recordatorio de que estas compartiendo tus datos con un tercero.',
      'sharingNoteEnded':
          'Nota: Los datos compartidos durante la participacion en el ensayo clinico permanecen con los investigadores indefinidamente para analisis cientifico.',

      // REQ-CAL-p00001: Old Entry Justification
      'oldEntryJustificationTitle': 'Modificacion de Entrada Antigua',
      'oldEntryJustificationPrompt':
          'Este es un evento de hace mas de un dia. Por favor explica por que lo estas agregando/cambiando ahora:',
      'justificationPaperRecords': 'Ingresado desde registros en papel',
      'justificationRemembered': 'Recorde un evento especifico',
      'justificationEstimated': 'Evento estimado',
      'confirm': 'Confirmar',

      // REQ-CAL-p00002: Short Duration Confirmation
      'shortDurationTitle': 'Duracion Corta',
      'shortDurationMessage': 'La duracion es menor a 1 minuto, es correcto?',

      // REQ-CAL-p00003: Long Duration Confirmation
      'longDurationTitle': 'Duracion Larga',
      'longDurationMessage': 'La duracion es mayor a {0}, es correcto?',
      'durationMinutesShort': '{0}m',
      'durationHoursShort': '{0}h',
      'durationHoursMinutesShort': '{0}h {1}m',

      // Feature Flags (dev/qa only)
      'featureFlagsTitle': 'Feature Flags',
      'featureFlagsWarning':
          'Estos ajustes son solo para pruebas. Los cambios afectan el comportamiento de la app.',
      'featureFlagsSponsorSelection': 'Configuracion del Patrocinador',
      'featureFlagsSponsorId': 'ID del Patrocinador',
      'featureFlagsCurrentSponsor': 'Patrocinador actual: {0}',
      'featureFlagsLoad': 'Cargar',
      'featureFlagsLoadSuccess': 'Configuracion cargada para {0}',
      'featureFlagsSectionUI': 'Funciones de Interfaz',
      'featureFlagsSectionValidation': 'Funciones de Validacion',
      'featureFlagsUseReviewScreen': 'Usar Pantalla de Revision',
      'featureFlagsUseReviewScreenDescription':
          'Mostrar pantalla de revision al terminar una hemorragia',
      'featureFlagsUseAnimations': 'Usar Animaciones',
      'featureFlagsUseAnimationsDescription':
          'Habilitar animaciones y mostrar preferencia de usuario',
      'featureFlagsUseOnePageRecordingScreen':
          'Usar Pantalla de Registro de Una Pagina',
      'featureFlagsUseOnePageRecordingScreenDescription':
          'Usar pantalla de registro simplificada en lugar de flujo de varias paginas',
      'featureFlagsOldEntryJustification': 'Justificacion de Entrada Antigua',
      'featureFlagsOldEntryJustificationDescription':
          'Requerir justificacion al editar entradas de mas de un dia',
      'featureFlagsShortDurationConfirmation': 'Confirmacion Duracion Corta',
      'featureFlagsShortDurationConfirmationDescription':
          'Solicitar confirmacion para duraciones de 1 minuto o menos',
      'featureFlagsLongDurationConfirmation': 'Confirmacion Duracion Larga',
      'featureFlagsLongDurationConfirmationDescription':
          'Solicitar confirmacion para duraciones que excedan el umbral',
      'featureFlagsLongDurationThreshold': 'Umbral de Duracion Larga',
      'featureFlagsLongDurationThresholdDescription':
          'Umbral actual: {0} minutos',
      'featureFlagsResetToDefaults': 'Restablecer Valores',
      'featureFlagsResetTitle': 'Restablecer Feature Flags?',
      'featureFlagsResetConfirmation':
          'Restablecer todos los feature flags a sus valores predeterminados?',
      'featureFlagsResetButton': 'Restablecer',
      'featureFlagsResetSuccess': 'Feature flags restablecidos',
      // CUR-528: Font feature flags
      'featureFlagsSectionFonts': 'Accesibilidad de Fuentes',
      'featureFlagsFontSelectorVisible':
          'Selector de fuentes se mostrara en Configuracion',
      'featureFlagsFontSelectorHidden':
          'Selector de fuentes oculto (solo fuente predeterminada)',
      'fontDescriptionRoboto': 'Fuente predeterminada del sistema',
      'fontDescriptionOpenDyslexic':
          'Fuente disenada para lectores con dislexia',
      'fontDescriptionAtkinson':
          'Fuente optimizada para lectores con baja vision',
      'fontSelection': 'Fuente',
      'fontSelectionDescription': 'Elige la fuente que mejor funcione para ti',
      'hours': 'horas',
      'hour': 'hora',

      // Version Update
      'updateAvailable': 'Actualizacion Disponible',
      'updateRequired': 'Actualizacion Requerida',
      'updateNow': 'Actualizar Ahora',
      'later': 'Mas Tarde',
      'newVersionAvailable': 'Version {0} disponible',
      'updateRequiredMessage':
          'Se requiere una nueva version para continuar usando esta aplicacion. Por favor actualiza ahora.',
      'currentVersionLabel': 'Version actual:',
      'requiredVersionLabel': 'Version requerida:',
      'whatsNew': 'Novedades',
      'checkForUpdates': 'Buscar actualizaciones',
      'youAreUpToDate': 'Esta actualizado',
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
      'yes': 'Oui',
      'no': 'Non',
      'ok': 'OK',
      'error': 'Erreur',
      'reset': 'Reinitialiser',

      // Home Screen
      'recordNosebleed': 'Enregistrer un Saignement',
      'noEventsToday': "pas d'evenements aujourd'hui",
      'noEventsYesterday': "pas d'evenements hier",
      'incompleteRecords': 'Enregistrements Incomplets',
      'tapToComplete': 'Appuyez pour completer',
      'exampleDataAdded': 'Donnees exemple ajoutees',
      'resetAllData': 'Reinitialiser toutes les donnees?',
      'resetAllDataMessage':
          'Cela supprimera definitivement toutes vos donnees enregistrees. Cette action ne peut pas etre annulee.',
      'allDataReset': 'Toutes les donnees ont ete reinitialiser',
      'endClinicalTrial': "Terminer l'essai clinique?",
      'endClinicalTrialMessage':
          "Etes-vous sur de vouloir mettre fin a votre participation a l'essai clinique? Vos donnees seront conservees mais ne seront plus synchronisees.",
      'endTrial': 'Terminer',
      'leftClinicalTrial': "Vous avez quitte l'essai clinique",
      'userMenu': 'Menu utilisateur',
      'privacyComingSoon': 'Parametres de confidentialite bientot disponibles',
      'switchedToSimpleUI': "Interface simple d'enregistrement activee",
      'switchedToClassicUI': "Interface classique d'enregistrement activee",
      'usingSimpleUI': 'Interface simple (appuyez pour changer)',
      'usingClassicUI': 'Interface classique (appuyez pour simple)',
      'noEvents': "pas d'evenements",

      // Login/Account
      'login': 'Connexion',
      'logout': 'Deconnexion',
      'account': 'Compte',
      'createAccount': 'Creer un compte',
      'savedCredentialsQuestion':
          "Avez-vous enregistre votre nom d'utilisateur et mot de passe?",
      'credentialsAvailableInAccount':
          "Si vous n'avez pas enregistre vos identifiants, ils sont disponibles dans la page Compte.",
      'yesLogout': 'Oui, deconnecter',
      'syncingData': 'Synchronisation de vos donnees...',
      'syncFailed': 'Echec de la synchronisation',
      'syncFailedMessage':
          'Impossible de synchroniser vos donnees avec le serveur. Veuillez verifier votre connexion internet et reessayer.',
      'loggedOut': 'Vous avez ete deconnecte',
      'privacyNotice': 'Avis de confidentialite',
      'privacyNoticeDescription':
          "Pour votre vie privee, nous n'utilisons pas d'adresses e-mail pour les comptes.",
      'noAtSymbol':
          "Le symbole @ n'est pas autorise pour le nom d'utilisateur.",
      'important': 'Important',
      'storeCredentialsSecurely':
          "Conservez votre nom d'utilisateur et mot de passe en securite.",
      'lostCredentialsWarning':
          "Si vous perdez votre nom d'utilisateur et mot de passe, l'application ne peut pas vous envoyer de lien pour le reinitialiser.",
      'usernameRequired': "Le nom d'utilisateur est requis",
      'usernameTooShort':
          "Le nom d'utilisateur doit comporter au moins {0} caracteres",
      'usernameNoAt': "Le nom d'utilisateur ne peut pas contenir @",
      'usernameLettersOnly':
          'Seuls les lettres, chiffres et tirets bas sont autorises',
      'passwordRequired': 'Le mot de passe est requis',
      'passwordTooShort':
          'Le mot de passe doit comporter au moins {0} caracteres',
      'passwordsDoNotMatch': 'Les mots de passe ne correspondent pas',
      'username': "Nom d'utilisateur",
      'enterUsername': "Entrez le nom d'utilisateur (sans @)",
      'password': 'Mot de passe',
      'enterPassword': 'Entrez le mot de passe',
      'confirmPassword': 'Confirmer le mot de passe',
      'reenterPassword': 'Ressaisissez le mot de passe',
      'noAccountCreate': 'Pas de compte? Creez-en un',
      'hasAccountLogin': 'Vous avez deja un compte? Connectez-vous',
      'minimumCharacters': 'Minimum {0} caracteres',

      // Account Profile
      'changePassword': 'Changer le mot de passe',
      'currentPassword': 'Mot de passe actuel',
      'currentPasswordRequired': 'Le mot de passe actuel est requis',
      'newPassword': 'Nouveau mot de passe',
      'newPasswordRequired': 'Le nouveau mot de passe est requis',
      'confirmNewPassword': 'Confirmer le nouveau mot de passe',
      'passwordChangedSuccess': 'Mot de passe change avec succes',
      'yourCredentials': 'Vos identifiants',
      'keepCredentialsSafe':
          "Gardez-les en securite - il n'y a pas de recuperation de mot de passe.",
      'hidePassword': 'Masquer le mot de passe',
      'showPassword': 'Afficher le mot de passe',
      'securityReminder': 'Rappel de securite',
      'securityReminderText':
          "Notez votre nom d'utilisateur et mot de passe et conservez-les dans un endroit sur. Si vous perdez ces identifiants, vous ne pourrez pas recuperer votre compte.",

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
      'useAnimation': 'Utiliser les Animations',
      'useAnimationDescription':
          "Activer les animations visuelles et les transitions dans l'application",
      'compactView': 'Vue Compacte',
      'compactViewDescription':
          "Reduire l'espacement entre les entrees dans la liste des evenements pour un affichage plus dense",
      'language': 'Langue',
      'languageDescription': 'Choisissez votre langue preferee',
      'accessibilityAndPreferences': 'Accessibilite et Preferences',
      'privacy': 'Confidentialite',
      'enrollInClinicalTrial': "S'inscrire a un Essai Clinique",
      'comingSoon': 'Bientot disponible',
      'comingSoonEnglishOnly':
          'Bientot disponible - Anglais uniquement pour le moment',

      // Calendar
      'selectDate': 'Selectionner une Date',
      'nosebleedEvents': 'Evenements de saignement de nez',
      'noNosebleeds': 'Pas de saignements de nez',
      'confirmedNoEvents': 'Confirme aucun evenement pour ce jour',
      'unknown': 'Inconnu',
      'unableToRecallEvents':
          'Impossible de se souvenir des evenements de ce jour',
      'plusOneDay': '(+1 jour)',
      'incomplete': 'Incomplet',
      'incompleteMissing': 'Incomplet/Manquant',
      'notRecorded': 'Non enregistre',
      'tapToAddOrEdit':
          'Appuyez sur une date pour ajouter ou modifier des evenements',

      // Recording
      'whenDidItStart': 'Quand le saignement de nez a-t-il commence?',
      'whenDidItStop': "Quand le saignement de nez s'est-il arrete?",
      'howSevere': "Quelle est l'intensite du saignement?",
      'selectBestOption':
          "Selectionnez l'option qui decrit le mieux le saignement",
      'anyNotes': 'Des notes supplementaires?',
      'notesPlaceholder': 'Notes optionnelles sur ce saignement de nez...',
      'start': 'Debut',
      'end': 'Fin',
      'selectIntensity': 'Appuyez pour definir',
      'notSet': 'Non defini',
      'intensity': 'Intensite',
      'maxIntensity': 'Intensite Maximale',
      'nosebleedStart': 'Debut du saignement',
      'setStartTime': "Definir l'heure de debut",
      'nosebleedEnd': 'Fin du saignement',
      'nosebleedEndTime': 'Heure de fin du saignement',
      'setEndTime': 'Definir heure de fin',
      'completeRecord': "Completer l'enregistrement",
      'editRecord': "Modifier l'enregistrement",
      'recordComplete': 'Enregistrement complet',
      'reviewAndSave':
          'Verifiez les informations et enregistrez quand vous etes pret',
      'tapFieldToEdit': 'Appuyez sur un champ ci-dessus pour le modifier',
      'durationMinutes': 'Duree: {0} minutes',
      'cannotSaveOverlap':
          "Impossible d'enregistrer: Cet evenement chevauche des evenements existants. Veuillez ajuster l'heure.",
      'cannotSaveOverlapCount':
          "Impossible d'enregistrer: Cet evenement chevauche {0} {1} existant(s)",
      'event': 'evenement',
      'events': 'evenements',
      'failedToSave': "Echec de l'enregistrement",
      'endTimeAfterStart': "L'heure de fin doit etre apres l'heure de debut",
      'updateNosebleed': 'Mettre a jour le saignement',
      'addNosebleed': 'Ajouter un saignement',
      'saveChanges': 'Enregistrer les modifications',
      'finished': 'Termine',
      'deleteRecordTooltip': "Supprimer l'enregistrement",
      'setFields': 'Definir {0}',
      'saveAsIncomplete': 'Enregistrer comme incomplet?',
      'saveAsIncompleteDescription':
          'Vous avez entre des informations. Voulez-vous les enregistrer comme un enregistrement incomplet?',
      'discard': 'Jeter',
      'keepEditing': 'Continuer a editer',

      // Intensity
      'spotting': 'Taches',
      'dripping': 'Gouttes',
      'drippingQuickly': 'Gouttes rapides',
      'steadyStream': 'Flux constant',
      'pouring': 'Coulant',
      'gushing': 'Jaillissant',

      // Yesterday banner
      'confirmYesterday': 'Confirmer Hier',
      'confirmYesterdayDate': 'Confirmer Hier - {0}',
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

      // Time picker
      'cannotSelectFutureTime':
          'Impossible de selectionner une heure dans le futur',

      // Notes input
      'notes': 'Notes',
      'notesRequired': 'Requis pour les participants aux essais cliniques',
      'notesHint':
          'Ajoutez des details supplementaires sur ce saignement de nez...',
      'next': 'Suivant',

      // Logo menu
      'appMenu': "Menu de l'application",
      'dataManagement': 'Gestion des Donnees',
      'exportData': 'Exporter les Donnees',
      'importData': 'Importer les Donnees',
      'exportSuccess': 'Donnees exportees avec succes',
      'exportFailed': "Echec de l'exportation des donnees",
      'importSuccess': '{0} enregistrements importes',
      'importFailed': "Echec de l'importation des donnees: {0}",
      'importConfirmTitle': 'Importer les Donnees',
      'importConfirmMessage':
          'Cela importera les donnees du fichier selectionne. '
          'Les enregistrements existants seront conserves. Continuer?',
      'clinicalTrialLabel': 'Essai Clinique',
      'instructionsAndFeedback': 'Instructions et Commentaires',

      // Overlap warning
      'overlappingEventsDetected': 'Evenements Chevauches Detectes',
      'overlappingEventsCount': 'Cet evenement chevauche {0} {1} existant(s)',
      'overlappingEventTimeRange':
          'Cet horaire chevauche un enregistrement de saignement de nez existant de {0} a {1}',
      'viewConflictingRecord': 'Voir',

      // Enrollment screen
      'welcomeToNosebleedDiary':
          'Bienvenue dans\nJournal des Saignements de Nez',
      'enterCodeToGetStarted':
          "Entrez votre code d'inscription pour commencer.",
      'enrollmentCodePlaceholder': 'CUREHHT#',
      'getStarted': 'Commencer',
      'codeMustBe8Chars': 'Le code doit comporter 8 caracteres',
      'pleaseEnterEnrollmentCode': "Veuillez entrer votre code d'inscription",

      // Date records screen
      'addNewEvent': 'Ajouter un nouvel evenement',
      'noEventsRecordedForDay': 'Aucun evenement enregistre pour ce jour',
      'eventCountSingular': '1 evenement',
      'eventCountPlural': '{0} evenements',

      // Profile screen
      'userProfile': 'Profil Utilisateur',
      'enterYourName': 'Entrez votre nom',
      'editName': 'Modifier le nom',
      'shareWithCureHHT': 'Partager avec CureHHT',
      'stopSharingWithCureHHT': 'Arreter le Partage avec CureHHT',
      'privacyDataProtection': 'Confidentialite et Protection des Donnees',
      'healthDataStoredLocally':
          'Vos donnees de sante sont stockees localement sur votre appareil.',
      'dataSharedAnonymized':
          ' Les donnees anonymisees sont partagees avec CureHHT a des fins de recherche.',
      'clinicalTrialSharingActive':
          " La participation a l'essai clinique implique le partage de donnees anonymisees avec les chercheurs selon le protocole de l'etude.",
      'clinicalTrialEndedMessage':
          " La participation a l'essai clinique s'est terminee le {0}. Les donnees precedemment partagees restent indefiniment avec les chercheurs pour analyse scientifique.",
      'noDataSharedMessage':
          " Aucune donnee n'est partagee avec des tiers sauf si vous choisissez de participer a la recherche ou aux essais cliniques.",
      'enrolledInClinicalTrialStatus': 'Inscrit a un Essai Clinique',
      'clinicalTrialEnrollmentEnded':
          'Inscription a un Essai Clinique: Terminee',
      'enrollmentCodeLabel': "Code d'Inscription: {0}",
      'enrolledLabel': 'Inscrit: {0}',
      'endedLabel': 'Termine: {0}',
      'sharingWithCureHHT': 'Partage avec CureHHT',
      'sharingNoteActive':
          "Note: Le logo affiche sur l'ecran d'accueil de l'application est un rappel que vous partagez vos donnees avec un tiers.",
      'sharingNoteEnded':
          "Note: Les donnees partagees pendant la participation a l'essai clinique restent indefiniment avec les chercheurs pour analyse scientifique.",

      // REQ-CAL-p00001: Old Entry Justification
      'oldEntryJustificationTitle': "Modification d'une Ancienne Entree",
      'oldEntryJustificationPrompt':
          "Cet evenement date de plus d'un jour. Veuillez expliquer pourquoi vous l'ajoutez/modifiez maintenant:",
      'justificationPaperRecords': 'Saisi a partir de dossiers papier',
      'justificationRemembered': "Je me suis souvenu d'un evenement specifique",
      'justificationEstimated': 'Evenement estime',
      'confirm': 'Confirmer',

      // REQ-CAL-p00002: Short Duration Confirmation
      'shortDurationTitle': 'Duree Courte',
      'shortDurationMessage':
          'La duree est inferieure a 1 minute, est-ce correct?',

      // REQ-CAL-p00003: Long Duration Confirmation
      'longDurationTitle': 'Duree Longue',
      'longDurationMessage': 'La duree est superieure a {0}, est-ce correct?',
      'durationMinutesShort': '{0}m',
      'durationHoursShort': '{0}h',
      'durationHoursMinutesShort': '{0}h {1}m',

      // Feature Flags (dev/qa only)
      'featureFlagsTitle': 'Feature Flags',
      'featureFlagsWarning':
          "Ces parametres sont uniquement pour les tests. Les modifications affectent le comportement de l'application.",
      'featureFlagsSponsorSelection': 'Configuration du Sponsor',
      'featureFlagsSponsorId': 'ID du Sponsor',
      'featureFlagsCurrentSponsor': 'Sponsor actuel: {0}',
      'featureFlagsLoad': 'Charger',
      'featureFlagsLoadSuccess': 'Configuration chargee pour {0}',
      'featureFlagsSectionUI': "Fonctionnalites d'Interface",
      'featureFlagsSectionValidation': 'Fonctionnalites de Validation',
      'featureFlagsUseReviewScreen': 'Utiliser Ecran de Revision',
      'featureFlagsUseReviewScreenDescription':
          "Afficher l'ecran de revision apres avoir termine un saignement",
      'featureFlagsUseAnimations': 'Utiliser Animations',
      'featureFlagsUseAnimationsDescription':
          'Activer les animations et afficher la preference utilisateur',
      'featureFlagsUseOnePageRecordingScreen':
          "Utiliser Ecran d'Enregistrement Une Page",
      'featureFlagsUseOnePageRecordingScreenDescription':
          "Utiliser l'ecran d'enregistrement simplifie au lieu du flux multi-pages",
      'featureFlagsOldEntryJustification': 'Justification Ancienne Entree',
      'featureFlagsOldEntryJustificationDescription':
          "Exiger une justification lors de la modification d'entrees de plus d'un jour",
      'featureFlagsShortDurationConfirmation': 'Confirmation Duree Courte',
      'featureFlagsShortDurationConfirmationDescription':
          "Demander confirmation pour les durees d'une minute ou moins",
      'featureFlagsLongDurationConfirmation': 'Confirmation Duree Longue',
      'featureFlagsLongDurationConfirmationDescription':
          'Demander confirmation pour les durees depassant le seuil',
      'featureFlagsLongDurationThreshold': 'Seuil de Duree Longue',
      'featureFlagsLongDurationThresholdDescription':
          'Seuil actuel: {0} minutes',
      'featureFlagsResetToDefaults': 'Reinitialiser',
      'featureFlagsResetTitle': 'Reinitialiser Feature Flags?',
      'featureFlagsResetConfirmation':
          'Reinitialiser tous les feature flags a leurs valeurs par defaut?',
      'featureFlagsResetButton': 'Reinitialiser',
      'featureFlagsResetSuccess': 'Feature flags reinitialises',
      // CUR-528: Font feature flags
      'featureFlagsSectionFonts': 'Accessibilite des Polices',
      'featureFlagsFontSelectorVisible':
          'Selecteur de polices affiche dans Parametres',
      'featureFlagsFontSelectorHidden':
          'Selecteur de polices masque (police par defaut uniquement)',
      'fontDescriptionRoboto': 'Police par defaut du systeme',
      'fontDescriptionOpenDyslexic':
          'Police concue pour les lecteurs dyslexiques',
      'fontDescriptionAtkinson':
          'Police optimisee pour les lecteurs malvoyants',
      'fontSelection': 'Police',
      'fontSelectionDescription': 'Choisissez la police qui vous convient',
      'hours': 'heures',
      'hour': 'heure',

      // Version Update
      'updateAvailable': 'Mise a Jour Disponible',
      'updateRequired': 'Mise a Jour Requise',
      'updateNow': 'Mettre a Jour',
      'later': 'Plus Tard',
      'newVersionAvailable': 'La version {0} est disponible',
      'updateRequiredMessage':
          'Une nouvelle version est requise pour continuer a utiliser cette application. Veuillez mettre a jour maintenant.',
      'currentVersionLabel': 'Version actuelle:',
      'requiredVersionLabel': 'Version requise:',
      'whatsNew': 'Nouveautes',
      'checkForUpdates': 'Rechercher des mises a jour',
      'youAreUpToDate': 'Vous etes a jour',
    },
    'de': {
      // General
      'appTitle': 'Nasenbluten-Tagebuch',
      'back': 'Zuruck',
      'cancel': 'Abbrechen',
      'save': 'Speichern',
      'delete': 'Loschen',
      'close': 'Schliessen',
      'today': 'Heute',
      'yesterday': 'Gestern',
      'calendar': 'Kalender',
      'yes': 'Ja',
      'no': 'Nein',
      'ok': 'OK',
      'error': 'Fehler',
      'reset': 'Zurucksetzen',

      // Home Screen
      'recordNosebleed': 'Nasenbluten erfassen',
      'noEventsToday': 'keine Ereignisse heute',
      'noEventsYesterday': 'keine Ereignisse gestern',
      'incompleteRecords': 'Unvollstandige Eintrage',
      'tapToComplete': 'Tippen zum Vervollstandigen',
      'exampleDataAdded': 'Beispieldaten hinzugefugt',
      'resetAllData': 'Alle Daten zurucksetzen?',
      'resetAllDataMessage':
          'Dies wird alle Ihre aufgezeichneten Daten dauerhaft loschen. Diese Aktion kann nicht ruckgangig gemacht werden.',
      'allDataReset': 'Alle Daten wurden zuruckgesetzt',
      'endClinicalTrial': 'Klinische Studie beenden?',
      'endClinicalTrialMessage':
          'Sind Sie sicher, dass Sie Ihre Teilnahme an der klinischen Studie beenden mochten? Ihre Daten werden aufbewahrt, aber nicht mehr synchronisiert.',
      'endTrial': 'Beenden',
      'leftClinicalTrial': 'Sie haben die klinische Studie verlassen',
      'userMenu': 'Benutzermenu',
      'privacyComingSoon': 'Datenschutzeinstellungen kommen bald',
      'switchedToSimpleUI': 'Zur einfachen Aufnahme-Oberflache gewechselt',
      'switchedToClassicUI': 'Zur klassischen Aufnahme-Oberflache gewechselt',
      'usingSimpleUI': 'Einfache Oberflache (tippen zum Wechseln)',
      'usingClassicUI': 'Klassische Oberflache (tippen fur einfach)',
      'noEvents': 'keine Ereignisse',

      // Login/Account
      'login': 'Anmelden',
      'logout': 'Abmelden',
      'account': 'Konto',
      'createAccount': 'Konto erstellen',
      'savedCredentialsQuestion':
          'Haben Sie Ihren Benutzernamen und Ihr Passwort gespeichert?',
      'credentialsAvailableInAccount':
          'Wenn Sie Ihre Anmeldedaten nicht gespeichert haben, sind sie auf der Kontoseite verfugbar.',
      'yesLogout': 'Ja, abmelden',
      'syncingData': 'Ihre Daten werden synchronisiert...',
      'syncFailed': 'Synchronisierung fehlgeschlagen',
      'syncFailedMessage':
          'Ihre Daten konnten nicht mit dem Server synchronisiert werden. Bitte uberprufen Sie Ihre Internetverbindung und versuchen Sie es erneut.',
      'loggedOut': 'Sie wurden abgemeldet',
      'privacyNotice': 'Datenschutzhinweis',
      'privacyNoticeDescription':
          'Fur Ihre Privatsphare verwenden wir keine E-Mail-Adressen fur Konten.',
      'noAtSymbol': 'Das @-Symbol ist im Benutzernamen nicht erlaubt.',
      'important': 'Wichtig',
      'storeCredentialsSecurely':
          'Speichern Sie Ihren Benutzernamen und Ihr Passwort sicher.',
      'lostCredentialsWarning':
          'Wenn Sie Ihren Benutzernamen und Ihr Passwort verlieren, kann die App Ihnen keinen Link zum Zurucksetzen senden.',
      'usernameRequired': 'Benutzername ist erforderlich',
      'usernameTooShort': 'Der Benutzername muss mindestens {0} Zeichen haben',
      'usernameNoAt': 'Benutzername darf kein @ enthalten',
      'usernameLettersOnly': 'Nur Buchstaben, Zahlen und Unterstriche erlaubt',
      'passwordRequired': 'Passwort ist erforderlich',
      'passwordTooShort': 'Das Passwort muss mindestens {0} Zeichen haben',
      'passwordsDoNotMatch': 'Passworter stimmen nicht uberein',
      'username': 'Benutzername',
      'enterUsername': 'Benutzername eingeben (ohne @)',
      'password': 'Passwort',
      'enterPassword': 'Passwort eingeben',
      'confirmPassword': 'Passwort bestatigen',
      'reenterPassword': 'Passwort erneut eingeben',
      'noAccountCreate': 'Kein Konto? Erstellen Sie eines',
      'hasAccountLogin': 'Bereits ein Konto? Anmelden',
      'minimumCharacters': 'Mindestens {0} Zeichen',

      // Account Profile
      'changePassword': 'Passwort andern',
      'currentPassword': 'Aktuelles Passwort',
      'currentPasswordRequired': 'Aktuelles Passwort ist erforderlich',
      'newPassword': 'Neues Passwort',
      'newPasswordRequired': 'Neues Passwort ist erforderlich',
      'confirmNewPassword': 'Neues Passwort bestatigen',
      'passwordChangedSuccess': 'Passwort erfolgreich geandert',
      'yourCredentials': 'Ihre Anmeldedaten',
      'keepCredentialsSafe':
          'Bewahren Sie diese sicher auf - es gibt keine Passwortwiederherstellung.',
      'hidePassword': 'Passwort verbergen',
      'showPassword': 'Passwort anzeigen',
      'securityReminder': 'Sicherheitshinweis',
      'securityReminderText':
          'Schreiben Sie Ihren Benutzernamen und Ihr Passwort auf und bewahren Sie sie an einem sicheren Ort auf. Wenn Sie diese Anmeldedaten verlieren, konnen Sie Ihr Konto nicht wiederherstellen.',

      // Settings
      'settings': 'Einstellungen',
      'colorScheme': 'Farbschema',
      'chooseAppearance': 'Wahlen Sie Ihr bevorzugtes Erscheinungsbild',
      'lightMode': 'Heller Modus',
      'lightModeDescription': 'Helle Darstellung mit hellen Hintergrunden',
      'darkMode': 'Dunkler Modus',
      'darkModeDescription': 'Reduzierte Helligkeit mit dunklen Hintergrunden',
      'accessibility': 'Barrierefreiheit',
      'accessibilityDescription':
          'Passen Sie die App fur bessere Lesbarkeit und Benutzerfreundlichkeit an',
      'dyslexiaFriendlyFont': 'Legasthenie-freundliche Schrift',
      'dyslexiaFontDescription':
          'Verwenden Sie die OpenDyslexic-Schrift fur verbesserte Lesbarkeit.',
      'learnMoreOpenDyslexic': 'Mehr erfahren auf opendyslexic.org',
      'largerTextAndControls': 'Grosserer Text und Steuerelemente',
      'largerTextDescription':
          'Vergrossern Sie Text und interaktive Elemente fur einfacheres Lesen und Navigieren',
      'useAnimation': 'Animationen verwenden',
      'useAnimationDescription':
          'Visuelle Animationen und Ubergange in der gesamten App aktivieren',
      'compactView': 'Kompakte Ansicht',
      'compactViewDescription':
          'Reduziert den Abstand zwischen Eintragen in der Ereignisliste fur eine dichtere Anzeige',
      'language': 'Sprache',
      'languageDescription': 'Wahlen Sie Ihre bevorzugte Sprache',
      'accessibilityAndPreferences': 'Barrierefreiheit & Einstellungen',
      'privacy': 'Datenschutz',
      'enrollInClinicalTrial': 'An klinischer Studie teilnehmen',
      'comingSoon': 'Demnachst verfugbar',
      'comingSoonEnglishOnly': 'Demnachst verfugbar - Vorerst nur Englisch',

      // Calendar
      'selectDate': 'Datum auswahlen',
      'nosebleedEvents': 'Nasenbluten-Ereignisse',
      'noNosebleeds': 'Kein Nasenbluten',
      'confirmedNoEvents': 'Bestatigt keine Ereignisse fur diesen Tag',
      'unknown': 'Unbekannt',
      'unableToRecallEvents':
          'Ereignisse fur diesen Tag konnen nicht erinnert werden',
      'plusOneDay': '(+1 Tag)',
      'incomplete': 'Unvollstandig',
      'incompleteMissing': 'Unvollstandig/Fehlend',
      'notRecorded': 'Nicht erfasst',
      'tapToAddOrEdit':
          'Tippen Sie auf ein Datum, um Ereignisse hinzuzufugen oder zu bearbeiten',

      // Recording
      'whenDidItStart': 'Wann hat das Nasenbluten begonnen?',
      'whenDidItStop': 'Wann hat das Nasenbluten aufgehort?',
      'howSevere': 'Wie intensiv ist das Nasenbluten?',
      'selectBestOption':
          'Wahlen Sie die Option, die die Blutung am besten beschreibt',
      'anyNotes': 'Zusatzliche Anmerkungen?',
      'notesPlaceholder': 'Optionale Notizen zu diesem Nasenbluten...',
      'start': 'Start',
      'end': 'Ende',
      'selectIntensity': 'Tippen zum Einstellen',
      'notSet': 'Nicht eingestellt',
      'intensity': 'Intensitat',
      'maxIntensity': 'Maximale Intensitat',
      'nosebleedStart': 'Nasenbluten-Start',
      'setStartTime': 'Startzeit festlegen',
      'nosebleedEnd': 'Nasenbluten-Ende',
      'nosebleedEndTime': 'Nasenbluten-Endzeit',
      'setEndTime': 'Endzeit festlegen',
      'completeRecord': 'Eintrag vervollstandigen',
      'editRecord': 'Eintrag bearbeiten',
      'recordComplete': 'Eintrag vollstandig',
      'reviewAndSave':
          'Uberprufen Sie die Informationen und speichern Sie, wenn Sie bereit sind',
      'tapFieldToEdit': 'Tippen Sie auf ein Feld oben, um es zu bearbeiten',
      'durationMinutes': 'Dauer: {0} Minuten',
      'cannotSaveOverlap':
          'Kann nicht gespeichert werden: Dieses Ereignis uberschneidet sich mit vorhandenen Ereignissen. Bitte passen Sie die Zeit an.',
      'cannotSaveOverlapCount':
          'Kann nicht gespeichert werden: Dieses Ereignis uberschneidet sich mit {0} vorhandenen {1}',
      'event': 'Ereignis',
      'events': 'Ereignissen',
      'failedToSave': 'Speichern fehlgeschlagen',
      'endTimeAfterStart': 'Die Endzeit muss nach der Startzeit liegen',
      'updateNosebleed': 'Nasenbluten aktualisieren',
      'addNosebleed': 'Nasenbluten hinzufugen',
      'saveChanges': 'Anderungen speichern',
      'finished': 'Fertig',
      'deleteRecordTooltip': 'Eintrag loschen',
      'setFields': '{0} festlegen',
      'saveAsIncomplete': 'Als unvollstandig speichern?',
      'saveAsIncompleteDescription':
          'Sie haben einige Informationen eingegeben. Mochten Sie diese als unvollstandigen Eintrag speichern?',
      'discard': 'Verwerfen',
      'keepEditing': 'Weiter bearbeiten',

      // Intensity
      'spotting': 'Leicht',
      'dripping': 'Tropfend',
      'drippingQuickly': 'Schnell tropfend',
      'steadyStream': 'Stetiger Fluss',
      'pouring': 'Stromend',
      'gushing': 'Stark stromend',

      // Yesterday banner
      'confirmYesterday': 'Gestern bestatigen',
      'confirmYesterdayDate': 'Gestern bestatigen - {0}',
      'didYouHaveNosebleeds': 'Hatten Sie Nasenbluten?',
      'noNosebleedsYesterday': 'Kein Nasenbluten',
      'hadNosebleeds': 'Hatte Nasenbluten',
      'dontRemember': 'Ich erinnere mich nicht',

      // Enrollment
      'enrollmentTitle': 'An klinischer Studie teilnehmen',
      'enterEnrollmentCode': 'Geben Sie Ihren Anmeldecode ein',
      'enrollmentCodeHint': 'XXXXX-XXXXX',
      'enroll': 'Anmelden',
      'enrollmentSuccess': 'Erfolgreich angemeldet!',
      'enrollmentError': 'Anmeldung fehlgeschlagen',

      // Delete confirmation
      'deleteRecord': 'Eintrag loschen',
      'selectDeleteReason':
          'Bitte wahlen Sie einen Grund fur das Loschen dieses Eintrags:',
      'enteredByMistake': 'Versehentlich eingegeben',
      'duplicateEntry': 'Doppelter Eintrag',
      'incorrectInformation': 'Falsche Informationen',
      'other': 'Sonstiges',
      'pleaseSpecify': 'Bitte angeben',

      // Time picker
      'cannotSelectFutureTime':
          'Es kann keine Zeit in der Zukunft ausgewahlt werden',

      // Notes input
      'notes': 'Notizen',
      'notesRequired': 'Erforderlich fur Teilnehmer an klinischen Studien',
      'notesHint': 'Fugen Sie weitere Details zu diesem Nasenbluten hinzu...',
      'next': 'Weiter',

      // Logo menu
      'appMenu': 'App-Menu',
      'dataManagement': 'Datenverwaltung',
      'exportData': 'Daten exportieren',
      'importData': 'Daten importieren',
      'exportSuccess': 'Daten erfolgreich exportiert',
      'exportFailed': 'Fehler beim Exportieren der Daten',
      'importSuccess': '{0} Datensatze importiert',
      'importFailed': 'Fehler beim Importieren der Daten: {0}',
      'importConfirmTitle': 'Daten importieren',
      'importConfirmMessage':
          'Dadurch werden Daten aus der ausgewahlten Datei importiert. '
          'Vorhandene Datensatze werden beibehalten. Fortfahren?',
      'clinicalTrialLabel': 'Klinische Studie',
      'instructionsAndFeedback': 'Anleitungen & Feedback',

      // Overlap warning
      'overlappingEventsDetected': 'Uberlappende Ereignisse erkannt',
      'overlappingEventsCount':
          'Dieses Ereignis uberschneidet sich mit {0} vorhandenen {1}',
      'overlappingEventTimeRange':
          'Dieser Zeitraum uberschneidet sich mit einem vorhandenen Nasenbluten-Eintrag von {0} bis {1}',
      'viewConflictingRecord': 'Anzeigen',

      // Enrollment screen
      'welcomeToNosebleedDiary': 'Willkommen beim\nNasenbluten-Tagebuch',
      'enterCodeToGetStarted':
          'Geben Sie Ihren Anmeldecode ein, um zu beginnen.',
      'enrollmentCodePlaceholder': 'CUREHHT#',
      'getStarted': 'Loslegen',
      'codeMustBe8Chars': 'Der Code muss 8 Zeichen haben',
      'pleaseEnterEnrollmentCode': 'Bitte geben Sie Ihren Anmeldecode ein',

      // Date records screen
      'addNewEvent': 'Neues Ereignis hinzufugen',
      'noEventsRecordedForDay': 'Keine Ereignisse fur diesen Tag aufgezeichnet',
      'eventCountSingular': '1 Ereignis',
      'eventCountPlural': '{0} Ereignisse',

      // Profile screen
      'userProfile': 'Benutzerprofil',
      'enterYourName': 'Geben Sie Ihren Namen ein',
      'editName': 'Name bearbeiten',
      'shareWithCureHHT': 'Mit CureHHT teilen',
      'stopSharingWithCureHHT': 'Teilen mit CureHHT beenden',
      'privacyDataProtection': 'Datenschutz & Datensicherheit',
      'healthDataStoredLocally':
          'Ihre Gesundheitsdaten werden lokal auf Ihrem Gerat gespeichert.',
      'dataSharedAnonymized':
          ' Anonymisierte Daten werden zu Forschungszwecken mit CureHHT geteilt.',
      'clinicalTrialSharingActive':
          ' Die Teilnahme an der klinischen Studie beinhaltet das Teilen anonymisierter Daten mit Forschern gemaß dem Studienprotokoll.',
      'clinicalTrialEndedMessage':
          ' Die Teilnahme an der klinischen Studie endete am {0}. Zuvor geteilte Daten verbleiben unbefristet bei den Forschern fur wissenschaftliche Analysen.',
      'noDataSharedMessage':
          ' Es werden keine Daten mit externen Parteien geteilt, es sei denn, Sie entscheiden sich fur die Teilnahme an Forschung oder klinischen Studien.',
      'enrolledInClinicalTrialStatus': 'In klinischer Studie angemeldet',
      'clinicalTrialEnrollmentEnded':
          'Anmeldung zur klinischen Studie: Beendet',
      'enrollmentCodeLabel': 'Anmeldecode: {0}',
      'enrolledLabel': 'Angemeldet: {0}',
      'endedLabel': 'Beendet: {0}',
      'sharingWithCureHHT': 'Teilen mit CureHHT',
      'sharingNoteActive':
          'Hinweis: Das Logo auf dem Startbildschirm der App erinnert Sie daran, dass Sie Ihre Daten mit einem Dritten teilen.',
      'sharingNoteEnded':
          'Hinweis: Wahrend der Teilnahme an der klinischen Studie geteilte Daten verbleiben unbefristet bei den Forschern fur wissenschaftliche Analysen.',

      // REQ-CAL-p00001: Old Entry Justification
      'oldEntryJustificationTitle': 'Alte Eintrag Anderung',
      'oldEntryJustificationPrompt':
          'Dieses Ereignis ist mehr als einen Tag alt. Bitte erklaren Sie, warum Sie es jetzt hinzufugen/andern:',
      'justificationPaperRecords': 'Aus Papierunterlagen eingetragen',
      'justificationRemembered': 'An bestimmtes Ereignis erinnert',
      'justificationEstimated': 'Geschatztes Ereignis',
      'confirm': 'Bestatigen',

      // REQ-CAL-p00002: Short Duration Confirmation
      'shortDurationTitle': 'Kurze Dauer',
      'shortDurationMessage':
          'Die Dauer betragt weniger als 1 Minute, ist das korrekt?',

      // REQ-CAL-p00003: Long Duration Confirmation
      'longDurationTitle': 'Lange Dauer',
      'longDurationMessage': 'Die Dauer ist langer als {0}, ist das korrekt?',
      'durationMinutesShort': '{0}m',
      'durationHoursShort': '{0}h',
      'durationHoursMinutesShort': '{0}h {1}m',

      // Feature Flags (dev/qa only)
      'featureFlagsTitle': 'Feature Flags',
      'featureFlagsWarning':
          'Diese Einstellungen sind nur fur Tests. Anderungen beeinflussen das App-Verhalten.',
      'featureFlagsSponsorSelection': 'Sponsor-Konfiguration',
      'featureFlagsSponsorId': 'Sponsor-ID',
      'featureFlagsCurrentSponsor': 'Aktueller Sponsor: {0}',
      'featureFlagsLoad': 'Laden',
      'featureFlagsLoadSuccess': 'Konfiguration fur {0} geladen',
      'featureFlagsSectionUI': 'Oberflachenfunktionen',
      'featureFlagsSectionValidation': 'Validierungsfunktionen',
      'featureFlagsUseReviewScreen': 'Uberprufungsbildschirm Verwenden',
      'featureFlagsUseReviewScreenDescription':
          'Uberprufungsbildschirm nach Beendigung einer Blutung anzeigen',
      'featureFlagsUseAnimations': 'Animationen Verwenden',
      'featureFlagsUseAnimationsDescription':
          'Animationen aktivieren und Benutzereinstellung anzeigen',
      'featureFlagsUseOnePageRecordingScreen':
          'Einseitigen Aufnahmebildschirm Verwenden',
      'featureFlagsUseOnePageRecordingScreenDescription':
          'Vereinfachten einseitigen Aufnahmebildschirm statt mehrseitigem Ablauf verwenden',
      'featureFlagsOldEntryJustification': 'Alte Eintrag Begrundung',
      'featureFlagsOldEntryJustificationDescription':
          'Begrundung bei Bearbeitung von Eintragen alter als ein Tag erforderlich',
      'featureFlagsShortDurationConfirmation': 'Bestatigung Kurze Dauer',
      'featureFlagsShortDurationConfirmationDescription':
          'Bestatigung fur Dauern von einer Minute oder weniger anfordern',
      'featureFlagsLongDurationConfirmation': 'Bestatigung Lange Dauer',
      'featureFlagsLongDurationConfirmationDescription':
          'Bestatigung fur Dauern uber dem Schwellenwert anfordern',
      'featureFlagsLongDurationThreshold': 'Schwellenwert Lange Dauer',
      'featureFlagsLongDurationThresholdDescription':
          'Aktueller Schwellenwert: {0} Minuten',
      'featureFlagsResetToDefaults': 'Zurucksetzen',
      'featureFlagsResetTitle': 'Feature Flags Zurucksetzen?',
      'featureFlagsResetConfirmation':
          'Alle Feature Flags auf Standardwerte zurucksetzen?',
      'featureFlagsResetButton': 'Zurucksetzen',
      'featureFlagsResetSuccess': 'Feature Flags zuruckgesetzt',
      // CUR-528: Font feature flags
      'featureFlagsSectionFonts': 'Schriftarten-Barrierefreiheit',
      'featureFlagsFontSelectorVisible':
          'Schriftartenauswahl wird in Einstellungen angezeigt',
      'featureFlagsFontSelectorHidden':
          'Schriftartenauswahl ausgeblendet (nur Standardschrift)',
      'fontDescriptionRoboto': 'Systemstandardschrift',
      'fontDescriptionOpenDyslexic':
          'Schrift fur Leser mit Legasthenie entwickelt',
      'fontDescriptionAtkinson': 'Schrift fur sehbehinderte Leser optimiert',
      'fontSelection': 'Schriftart',
      'fontSelectionDescription': 'Wahlen Sie die Schriftart die fur Sie passt',
      'hours': 'Stunden',
      'hour': 'Stunde',

      // Version Update
      'updateAvailable': 'Update Verfugbar',
      'updateRequired': 'Update Erforderlich',
      'updateNow': 'Jetzt Aktualisieren',
      'later': 'Spater',
      'newVersionAvailable': 'Version {0} ist verfugbar',
      'updateRequiredMessage':
          'Eine neue Version ist erforderlich, um diese App weiter zu verwenden. Bitte jetzt aktualisieren.',
      'currentVersionLabel': 'Aktuelle Version:',
      'requiredVersionLabel': 'Erforderliche Version:',
      'whatsNew': 'Was ist neu',
      'checkForUpdates': 'Nach Updates suchen',
      'youAreUpToDate': 'Sie sind auf dem neuesten Stand',
    },
  };

  String translate(String key) {
    return _localizedStrings[locale.languageCode]?[key] ??
        _localizedStrings['en']?[key] ??
        key;
  }

  /// Translate with parameter substitution
  /// Parameters are replaced using {0}, {1}, etc. placeholders
  String translateWithParams(String key, List<dynamic> params) {
    var result = translate(key);
    for (var i = 0; i < params.length; i++) {
      result = result.replaceAll('{$i}', params[i].toString());
    }
    return result;
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
  String get yes => translate('yes');
  String get no => translate('no');
  String get ok => translate('ok');
  String get error => translate('error');
  String get reset => translate('reset');

  // Home Screen
  String get recordNosebleed => translate('recordNosebleed');
  String get noEventsToday => translate('noEventsToday');
  String get noEventsYesterday => translate('noEventsYesterday');
  String get incompleteRecords => translate('incompleteRecords');
  String get tapToComplete => translate('tapToComplete');
  String get exampleDataAdded => translate('exampleDataAdded');
  String get resetAllData => translate('resetAllData');
  String get resetAllDataMessage => translate('resetAllDataMessage');
  String get allDataReset => translate('allDataReset');
  String get endClinicalTrial => translate('endClinicalTrial');
  String get endClinicalTrialMessage => translate('endClinicalTrialMessage');
  String get endTrial => translate('endTrial');
  String get leftClinicalTrial => translate('leftClinicalTrial');
  String get userMenu => translate('userMenu');
  String get privacyComingSoon => translate('privacyComingSoon');
  String get switchedToSimpleUI => translate('switchedToSimpleUI');
  String get switchedToClassicUI => translate('switchedToClassicUI');
  String get usingSimpleUI => translate('usingSimpleUI');
  String get usingClassicUI => translate('usingClassicUI');
  String get noEvents => translate('noEvents');
  String incompleteRecordCount(int count) => translateWithParams(
    count == 1 ? 'incompleteRecordSingular' : 'incompleteRecordPlural',
    [count],
  );

  // Login/Account
  String get login => translate('login');
  String get logout => translate('logout');
  String get account => translate('account');
  String get createAccount => translate('createAccount');
  String get savedCredentialsQuestion => translate('savedCredentialsQuestion');
  String get credentialsAvailableInAccount =>
      translate('credentialsAvailableInAccount');
  String get yesLogout => translate('yesLogout');
  String get syncingData => translate('syncingData');
  String get syncFailed => translate('syncFailed');
  String get syncFailedMessage => translate('syncFailedMessage');
  String get loggedOut => translate('loggedOut');
  String get privacyNotice => translate('privacyNotice');
  String get privacyNoticeDescription => translate('privacyNoticeDescription');
  String get noAtSymbol => translate('noAtSymbol');
  String get important => translate('important');
  String get storeCredentialsSecurely => translate('storeCredentialsSecurely');
  String get lostCredentialsWarning => translate('lostCredentialsWarning');
  String get usernameRequired => translate('usernameRequired');
  String usernameTooShort(int minLength) =>
      translateWithParams('usernameTooShort', [minLength]);
  String get usernameNoAt => translate('usernameNoAt');
  String get usernameLettersOnly => translate('usernameLettersOnly');
  String get passwordRequired => translate('passwordRequired');
  String passwordTooShort(int minLength) =>
      translateWithParams('passwordTooShort', [minLength]);
  String get passwordsDoNotMatch => translate('passwordsDoNotMatch');
  String get username => translate('username');
  String get enterUsername => translate('enterUsername');
  String get password => translate('password');
  String get enterPassword => translate('enterPassword');
  String get confirmPassword => translate('confirmPassword');
  String get reenterPassword => translate('reenterPassword');
  String get noAccountCreate => translate('noAccountCreate');
  String get hasAccountLogin => translate('hasAccountLogin');
  String minimumCharacters(int count) =>
      translateWithParams('minimumCharacters', [count]);

  // Account Profile
  String get changePassword => translate('changePassword');
  String get currentPassword => translate('currentPassword');
  String get currentPasswordRequired => translate('currentPasswordRequired');
  String get newPassword => translate('newPassword');
  String get newPasswordRequired => translate('newPasswordRequired');
  String get confirmNewPassword => translate('confirmNewPassword');
  String get passwordChangedSuccess => translate('passwordChangedSuccess');
  String get yourCredentials => translate('yourCredentials');
  String get keepCredentialsSafe => translate('keepCredentialsSafe');
  String get hidePassword => translate('hidePassword');
  String get showPassword => translate('showPassword');
  String get securityReminder => translate('securityReminder');
  String get securityReminderText => translate('securityReminderText');

  // Settings
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
  String get useAnimation => translate('useAnimation');
  String get useAnimationDescription => translate('useAnimationDescription');
  String get compactView => translate('compactView');
  String get compactViewDescription => translate('compactViewDescription');
  String get language => translate('language');
  String get languageDescription => translate('languageDescription');
  String get accessibilityAndPreferences =>
      translate('accessibilityAndPreferences');
  String get privacy => translate('privacy');
  String get enrollInClinicalTrial => translate('enrollInClinicalTrial');
  String get comingSoon => translate('comingSoon');
  String get comingSoonEnglishOnly => translate('comingSoonEnglishOnly');

  // Calendar
  String get selectDate => translate('selectDate');
  String get nosebleedEvents => translate('nosebleedEvents');
  String get noNosebleeds => translate('noNosebleeds');
  String get unknown => translate('unknown');
  String get incompleteMissing => translate('incompleteMissing');
  String get notRecorded => translate('notRecorded');
  String get tapToAddOrEdit => translate('tapToAddOrEdit');

  // Recording
  String get whenDidItStart => translate('whenDidItStart');
  String get whenDidItStop => translate('whenDidItStop');
  String get howSevere => translate('howSevere');
  String get anyNotes => translate('anyNotes');
  String get notesPlaceholder => translate('notesPlaceholder');
  String get start => translate('start');
  String get end => translate('end');
  String get selectIntensity => translate('selectIntensity');
  String get notSet => translate('notSet');
  String get incomplete => translate('incomplete');
  String get intensity => translate('intensity');
  String get maxIntensity => translate('maxIntensity');
  String get nosebleedStart => translate('nosebleedStart');
  String get setStartTime => translate('setStartTime');
  String get nosebleedEnd => translate('nosebleedEnd');
  String get nosebleedEndTime => translate('nosebleedEndTime');
  String get setEndTime => translate('setEndTime');
  String get completeRecord => translate('completeRecord');
  String get editRecord => translate('editRecord');
  String get recordComplete => translate('recordComplete');
  String get reviewAndSave => translate('reviewAndSave');
  String get tapFieldToEdit => translate('tapFieldToEdit');
  String durationMinutes(int minutes) =>
      translateWithParams('durationMinutes', [minutes]);
  String get cannotSaveOverlap => translate('cannotSaveOverlap');
  String cannotSaveOverlapCount(int count) => translateWithParams(
    'cannotSaveOverlapCount',
    [count, if (count == 1) translate('event') else translate('events')],
  );
  String get failedToSave => translate('failedToSave');
  String get endTimeAfterStart => translate('endTimeAfterStart');
  String get updateNosebleed => translate('updateNosebleed');
  String get addNosebleed => translate('addNosebleed');
  String get saveChanges => translate('saveChanges');
  String get finished => translate('finished');
  String get deleteRecordTooltip => translate('deleteRecordTooltip');
  String setFields(String fields) => translateWithParams('setFields', [fields]);
  String get saveAsIncomplete => translate('saveAsIncomplete');
  String get saveAsIncompleteDescription =>
      translate('saveAsIncompleteDescription');
  String get discard => translate('discard');
  String get keepEditing => translate('keepEditing');

  // Intensity
  String get spotting => translate('spotting');
  String get dripping => translate('dripping');
  String get drippingQuickly => translate('drippingQuickly');
  String get steadyStream => translate('steadyStream');
  String get pouring => translate('pouring');
  String get gushing => translate('gushing');

  /// Get localized Intensity name for a given Intensity enum value
  String intensityName(String intensity) {
    switch (intensity) {
      case 'spotting':
        return spotting;
      case 'dripping':
        return dripping;
      case 'drippingQuickly':
        return drippingQuickly;
      case 'steadyStream':
        return steadyStream;
      case 'pouring':
        return pouring;
      case 'gushing':
        return gushing;
      default:
        return intensity;
    }
  }

  // Yesterday banner
  String get confirmYesterday => translate('confirmYesterday');
  String confirmYesterdayDate(String date) =>
      translateWithParams('confirmYesterdayDate', [date]);
  String get didYouHaveNosebleeds => translate('didYouHaveNosebleeds');
  String get noNosebleedsYesterday => translate('noNosebleedsYesterday');
  String get hadNosebleeds => translate('hadNosebleeds');
  String get dontRemember => translate('dontRemember');

  // Enrollment
  String get enrollmentTitle => translate('enrollmentTitle');
  String get enterEnrollmentCode => translate('enterEnrollmentCode');
  String get enrollmentCodeHint => translate('enrollmentCodeHint');
  String get enroll => translate('enroll');
  String get enrollmentSuccess => translate('enrollmentSuccess');
  String get enrollmentError => translate('enrollmentError');

  // Delete confirmation
  String get deleteRecord => translate('deleteRecord');
  String get selectDeleteReason => translate('selectDeleteReason');
  String get enteredByMistake => translate('enteredByMistake');
  String get duplicateEntry => translate('duplicateEntry');
  String get incorrectInformation => translate('incorrectInformation');
  String get other => translate('other');
  String get pleaseSpecify => translate('pleaseSpecify');
  String get confirm => translate('confirm');

  // Time picker
  String get cannotSelectFutureTime => translate('cannotSelectFutureTime');

  // Notes input
  String get notes => translate('notes');
  String get notesRequired => translate('notesRequired');
  String get notesHint => translate('notesHint');
  String get next => translate('next');

  // Logo menu
  String get appMenu => translate('appMenu');
  String get dataManagement => translate('dataManagement');
  String get exportData => translate('exportData');
  String get importData => translate('importData');
  String get exportSuccess => translate('exportSuccess');
  String get exportFailed => translate('exportFailed');
  String importSuccess(int count) =>
      translateWithParams('importSuccess', [count]);
  String importFailed(String error) =>
      translateWithParams('importFailed', [error]);
  String get importConfirmTitle => translate('importConfirmTitle');
  String get importConfirmMessage => translate('importConfirmMessage');
  String get clinicalTrialLabel => translate('clinicalTrialLabel');
  String get instructionsAndFeedback => translate('instructionsAndFeedback');

  // Overlap warning
  String get overlappingEventsDetected =>
      translate('overlappingEventsDetected');
  String overlappingEventsCount(int count) => translateWithParams(
    'overlappingEventsCount',
    [count, if (count == 1) translate('event') else translate('events')],
  );
  String overlappingEventTimeRange(String startTime, String endTime) =>
      translateWithParams('overlappingEventTimeRange', [startTime, endTime]);
  String get viewConflictingRecord => translate('viewConflictingRecord');

  // Enrollment screen
  String get welcomeToNosebleedDiary => translate('welcomeToNosebleedDiary');
  String get enterCodeToGetStarted => translate('enterCodeToGetStarted');
  String get enrollmentCodePlaceholder =>
      translate('enrollmentCodePlaceholder');
  String get getStarted => translate('getStarted');
  String get codeMustBe8Chars => translate('codeMustBe8Chars');
  String get pleaseEnterEnrollmentCode =>
      translate('pleaseEnterEnrollmentCode');

  // Date records screen
  String get addNewEvent => translate('addNewEvent');
  String get noEventsRecordedForDay => translate('noEventsRecordedForDay');
  String get eventCountSingular => translate('eventCountSingular');
  String eventCountPlural(int count) =>
      translateWithParams('eventCountPlural', [count]);
  String eventCount(int count) =>
      count == 1 ? eventCountSingular : eventCountPlural(count);

  // Profile screen
  String get userProfile => translate('userProfile');
  String get enterYourName => translate('enterYourName');
  String get editName => translate('editName');
  String get shareWithCureHHT => translate('shareWithCureHHT');
  String get stopSharingWithCureHHT => translate('stopSharingWithCureHHT');
  String get privacyDataProtection => translate('privacyDataProtection');
  String get healthDataStoredLocally => translate('healthDataStoredLocally');
  String get dataSharedAnonymized => translate('dataSharedAnonymized');
  String get clinicalTrialSharingActive =>
      translate('clinicalTrialSharingActive');
  String clinicalTrialEndedMessage(String date) =>
      translateWithParams('clinicalTrialEndedMessage', [date]);
  String get noDataSharedMessage => translate('noDataSharedMessage');
  String get enrolledInClinicalTrialStatus =>
      translate('enrolledInClinicalTrialStatus');
  String get clinicalTrialEnrollmentEnded =>
      translate('clinicalTrialEnrollmentEnded');
  String enrollmentCodeLabel(String code) =>
      translateWithParams('enrollmentCodeLabel', [code]);
  String enrolledLabel(String date) =>
      translateWithParams('enrolledLabel', [date]);
  String endedLabel(String date) => translateWithParams('endedLabel', [date]);
  String get sharingWithCureHHT => translate('sharingWithCureHHT');
  String get sharingNoteActive => translate('sharingNoteActive');
  String get sharingNoteEnded => translate('sharingNoteEnded');

  // Feature Flags
  String get featureFlagsTitle => translate('featureFlagsTitle');
  String get featureFlagsWarning => translate('featureFlagsWarning');
  String get featureFlagsSponsorSelection =>
      translate('featureFlagsSponsorSelection');
  String get featureFlagsSponsorId => translate('featureFlagsSponsorId');
  String featureFlagsCurrentSponsor(String sponsorId) =>
      translateWithParams('featureFlagsCurrentSponsor', [sponsorId]);
  String get featureFlagsLoad => translate('featureFlagsLoad');
  String featureFlagsLoadSuccess(String sponsorId) =>
      translateWithParams('featureFlagsLoadSuccess', [sponsorId]);
  String get featureFlagsSectionUI => translate('featureFlagsSectionUI');
  String get featureFlagsSectionValidation =>
      translate('featureFlagsSectionValidation');
  String get featureFlagsUseReviewScreen =>
      translate('featureFlagsUseReviewScreen');
  String get featureFlagsUseReviewScreenDescription =>
      translate('featureFlagsUseReviewScreenDescription');
  String get featureFlagsUseAnimations =>
      translate('featureFlagsUseAnimations');
  String get featureFlagsUseAnimationsDescription =>
      translate('featureFlagsUseAnimationsDescription');
  String get featureFlagsUseOnePageRecordingScreen =>
      translate('featureFlagsUseOnePageRecordingScreen');
  String get featureFlagsUseOnePageRecordingScreenDescription =>
      translate('featureFlagsUseOnePageRecordingScreenDescription');
  String get featureFlagsOldEntryJustification =>
      translate('featureFlagsOldEntryJustification');
  String get featureFlagsOldEntryJustificationDescription =>
      translate('featureFlagsOldEntryJustificationDescription');
  String get featureFlagsShortDurationConfirmation =>
      translate('featureFlagsShortDurationConfirmation');
  String get featureFlagsShortDurationConfirmationDescription =>
      translate('featureFlagsShortDurationConfirmationDescription');
  String get featureFlagsLongDurationConfirmation =>
      translate('featureFlagsLongDurationConfirmation');
  String get featureFlagsLongDurationConfirmationDescription =>
      translate('featureFlagsLongDurationConfirmationDescription');
  String get featureFlagsLongDurationThreshold =>
      translate('featureFlagsLongDurationThreshold');
  String featureFlagsLongDurationThresholdDescription(int minutes) =>
      translateWithParams('featureFlagsLongDurationThresholdDescription', [
        minutes,
      ]);
  String get featureFlagsResetToDefaults =>
      translate('featureFlagsResetToDefaults');
  String get featureFlagsResetTitle => translate('featureFlagsResetTitle');
  String get featureFlagsResetConfirmation =>
      translate('featureFlagsResetConfirmation');
  String get featureFlagsResetButton => translate('featureFlagsResetButton');
  String get featureFlagsResetSuccess => translate('featureFlagsResetSuccess');

  // CUR-528: Font feature flags
  String get featureFlagsSectionFonts => translate('featureFlagsSectionFonts');
  String get featureFlagsFontSelectorVisible =>
      translate('featureFlagsFontSelectorVisible');
  String get featureFlagsFontSelectorHidden =>
      translate('featureFlagsFontSelectorHidden');
  String get fontDescriptionRoboto => translate('fontDescriptionRoboto');
  String get fontDescriptionOpenDyslexic =>
      translate('fontDescriptionOpenDyslexic');
  String get fontDescriptionAtkinson => translate('fontDescriptionAtkinson');
  String get fontSelection => translate('fontSelection');
  String get fontSelectionDescription => translate('fontSelectionDescription');

  // Version Update
  String get updateAvailable => translate('updateAvailable');
  String get updateRequired => translate('updateRequired');
  String get updateNow => translate('updateNow');
  String get later => translate('later');
  String newVersionAvailable(String version) =>
      translateWithParams('newVersionAvailable', [version]);
  String get updateRequiredMessage => translate('updateRequiredMessage');
  String get currentVersionLabel => translate('currentVersionLabel');
  String get requiredVersionLabel => translate('requiredVersionLabel');
  String get whatsNew => translate('whatsNew');
  String get checkForUpdates => translate('checkForUpdates');
  String get youAreUpToDate => translate('youAreUpToDate');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'es', 'fr', 'de'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
