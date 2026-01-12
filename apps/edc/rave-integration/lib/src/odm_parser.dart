import 'package:xml/xml.dart';

import 'models/exceptions.dart';
import 'models/site.dart';

/// Parser for RAVE ODM (Operational Data Model) XML responses.
///
/// Handles parsing of Sites.odm and validates ODM response completeness.
class OdmParser {
  /// The mdsol namespace URI used in RAVE ODM responses.
  static const mdsolNamespace = 'http://www.mdsol.com/ns/odm/metadata';

  /// Validates that the ODM response is complete (has closing \</ODM> tag).
  ///
  /// Per RAVE documentation: "An unclosed ODM element indicates that not all
  /// the streamed data was received."
  static void validateComplete(String xml) {
    // Check for closing ODM tag (case-insensitive, allowing whitespace)
    final trimmed = xml.trim();
    if (!trimmed.endsWith('</ODM>') &&
        !trimmed.contains(RegExp(r'</ODM>\s*$'))) {
      throw const RaveIncompleteResponseException();
    }
  }

  /// Parses Sites.odm response and extracts site information.
  ///
  /// Expected format:
  /// ```xml
  /// <ODM>
  ///   <AdminData>
  ///     <Location OID="..." Name="..." LocationType="Site" mdsol:Active="Yes|No">
  ///       <MetaDataVersionRef StudyOID="..." MetaDataVersionOID="..."
  ///                           EffectiveDate="..." mdsol:StudySiteNumber="..."/>
  ///     </Location>
  ///   </AdminData>
  /// </ODM>
  /// ```
  static List<RaveSite> parseSites(String xml) {
    validateComplete(xml);

    final XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } on XmlException catch (e) {
      throw RaveParseException('Failed to parse ODM XML: ${e.message}');
    }

    final sites = <RaveSite>[];

    // Find all Location elements within AdminData
    final adminDataElements = document.findAllElements('AdminData');
    for (final adminData in adminDataElements) {
      final locationElements = adminData.findElements('Location');
      for (final location in locationElements) {
        final site = _parseLocation(location);
        if (site != null) {
          sites.add(site);
        }
      }
    }

    return sites;
  }

  /// Parses a single Location element into a RaveSite.
  static RaveSite? _parseLocation(XmlElement location) {
    final oid = location.getAttribute('OID');
    final name = location.getAttribute('Name');
    final locationType = location.getAttribute('LocationType');

    // Skip non-Site locations
    if (locationType != 'Site') {
      return null;
    }

    if (oid == null || name == null) {
      return null;
    }

    // Parse mdsol:Active attribute
    // Try with namespace prefix first, then without
    var activeValue = location.getAttribute(
      'Active',
      namespace: mdsolNamespace,
    );
    activeValue ??= location.getAttribute('mdsol:Active');
    final isActive = activeValue?.toLowerCase() == 'yes';

    // Get the first MetaDataVersionRef for study site number
    String? studySiteNumber;
    String? studyOid;
    String? metaDataVersionOid;
    DateTime? effectiveDate;

    final metaDataRefs = location.findElements('MetaDataVersionRef');
    if (metaDataRefs.isNotEmpty) {
      final ref = metaDataRefs.first;
      studyOid = ref.getAttribute('StudyOID');
      metaDataVersionOid = ref.getAttribute('MetaDataVersionOID');

      // Parse mdsol:StudySiteNumber
      studySiteNumber = ref.getAttribute(
        'StudySiteNumber',
        namespace: mdsolNamespace,
      );
      studySiteNumber ??= ref.getAttribute('mdsol:StudySiteNumber');

      // Parse EffectiveDate
      final effectiveDateStr = ref.getAttribute('EffectiveDate');
      if (effectiveDateStr != null) {
        effectiveDate = DateTime.tryParse(effectiveDateStr);
      }
    }

    return RaveSite(
      oid: oid,
      name: name,
      isActive: isActive,
      studySiteNumber: studySiteNumber,
      studyOid: studyOid,
      metaDataVersionOid: metaDataVersionOid,
      effectiveDate: effectiveDate,
    );
  }

  /// Checks if an ODM response is empty (no data returned).
  ///
  /// An empty ODM response indicates the user has no permission or
  /// no data matches the query.
  static bool isEmpty(String xml) {
    try {
      final document = XmlDocument.parse(xml);
      final adminData = document.findAllElements('AdminData');
      if (adminData.isEmpty) {
        return true;
      }
      // Check if there are any Location elements
      for (final admin in adminData) {
        if (admin.findElements('Location').isNotEmpty) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return true;
    }
  }
}
