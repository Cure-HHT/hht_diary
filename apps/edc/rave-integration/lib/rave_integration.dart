/// Dart client library for Medidata RAVE Web Services API.
///
/// This library provides integration with the RAVE EDC system for
/// synchronizing clinical trial site data.
///
/// ## Usage
///
/// ```dart
/// import 'package:rave_integration/rave_integration.dart';
///
/// final client = RaveClient(
///   baseUrl: 'https://your-instance.mdsol.com',
///   username: 'your-username',
///   password: 'your-password',
/// );
///
/// // Sanity check - verify connectivity (no auth)
/// final version = await client.getVersion();
///
/// // Sanity check - verify authentication
/// final studies = await client.getStudies();
///
/// // Get sites for a study (or omit studyOid for all studies)
/// final sites = await client.getSites(studyOid: 'YOUR-STUDY-OID');
/// ```
library;

export 'src/client.dart' show RaveClient;
export 'src/models/exceptions.dart';
export 'src/models/site.dart' show RaveSite;
export 'src/odm_parser.dart' show OdmParser;
