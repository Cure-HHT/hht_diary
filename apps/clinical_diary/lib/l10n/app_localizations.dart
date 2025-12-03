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
      'start': 'Start',
      'end': 'End',
      'severity': 'Severity',
      'selectSeverity': 'Select...',
      'intensity': 'Intensity',
      'nosebleedStart': 'Nosebleed Start',
      'setStartTime': 'Set Start Time',
      'nosebleedEnd': 'Nosebleed End',
      'nosebleedEndTime': 'Nosebleed End Time',
      'nosebleedEnded': 'Nosebleed Ended',
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

      // Severity
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
      'start': 'Inicio',
      'end': 'Fin',
      'severity': 'Severidad',
      'selectSeverity': 'Seleccionar...',
      'intensity': 'Intensidad',
      'nosebleedStart': 'Inicio de hemorragia',
      'setStartTime': 'Establecer hora de inicio',
      'nosebleedEnd': 'Fin de hemorragia',
      'nosebleedEndTime': 'Hora de fin de hemorragia',
      'nosebleedEnded': 'Hemorragia finalizada',
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

      // Severity
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
      'noAccountCreate': "Pas de compte? Creez-en un",
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
      'notesPlaceholder': 'Notes optionnelles sur ce saignement de nez...',
      'start': 'Debut',
      'end': 'Fin',
      'severity': 'Gravite',
      'selectSeverity': 'Selectionner...',
      'intensity': 'Intensite',
      'nosebleedStart': 'Debut du saignement',
      'setStartTime': "Definir l'heure de debut",
      'nosebleedEnd': 'Fin du saignement',
      'nosebleedEndTime': 'Heure de fin du saignement',
      'nosebleedEnded': 'Saignement termine',
      'completeRecord': "Completer l'enregistrement",
      'editRecord': "Modifier l'enregistrement",
      'recordComplete': 'Enregistrement complet',
      'reviewAndSave':
          "Verifiez les informations et enregistrez quand vous etes pret",
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

      // Severity
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
      'unknown': 'Unbekannt',
      'incompleteMissing': 'Unvollstandig/Fehlend',
      'notRecorded': 'Nicht erfasst',
      'tapToAddOrEdit':
          'Tippen Sie auf ein Datum, um Ereignisse hinzuzufugen oder zu bearbeiten',

      // Recording
      'whenDidItStart': 'Wann hat das Nasenbluten begonnen?',
      'whenDidItStop': 'Wann hat das Nasenbluten aufgehort?',
      'howSevere': 'Wie stark war es?',
      'anyNotes': 'Zusatzliche Anmerkungen?',
      'notesPlaceholder': 'Optionale Notizen zu diesem Nasenbluten...',
      'start': 'Start',
      'end': 'Ende',
      'severity': 'Schweregrad',
      'selectSeverity': 'Auswahlen...',
      'intensity': 'Intensitat',
      'nosebleedStart': 'Nasenbluten-Start',
      'setStartTime': 'Startzeit festlegen',
      'nosebleedEnd': 'Nasenbluten-Ende',
      'nosebleedEndTime': 'Nasenbluten-Endzeit',
      'nosebleedEnded': 'Nasenbluten beendet',
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

      // Severity
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
    count == 1 ? 'incompleteRecord' : 'incompleteRecords',
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
  String get severity => translate('severity');
  String get selectSeverity => translate('selectSeverity');
  String get intensity => translate('intensity');
  String get nosebleedStart => translate('nosebleedStart');
  String get setStartTime => translate('setStartTime');
  String get nosebleedEnd => translate('nosebleedEnd');
  String get nosebleedEndTime => translate('nosebleedEndTime');
  String get nosebleedEnded => translate('nosebleedEnded');
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
    [count, count == 1 ? translate('event') : translate('events')],
  );
  String get failedToSave => translate('failedToSave');
  String get endTimeAfterStart => translate('endTimeAfterStart');
  String get updateNosebleed => translate('updateNosebleed');
  String get addNosebleed => translate('addNosebleed');
  String get saveChanges => translate('saveChanges');
  String get finished => translate('finished');
  String get deleteRecordTooltip => translate('deleteRecordTooltip');

  // Severity
  String get spotting => translate('spotting');
  String get dripping => translate('dripping');
  String get drippingQuickly => translate('drippingQuickly');
  String get steadyStream => translate('steadyStream');
  String get pouring => translate('pouring');
  String get gushing => translate('gushing');

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
