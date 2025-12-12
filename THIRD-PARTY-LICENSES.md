# Third-Party Licenses

This document lists the licenses of third-party dependencies used in the Clinical Trial Diary Platform.

**Project License**: AGPL-3.0 (see [LICENSE](./LICENSE))

**Last Verified**: 2025-12-05

---

## AGPL-3.0 Compatibility Summary

All dependencies use permissive licenses (BSD-3-Clause, MIT, Apache-2.0) that are compatible with AGPL-3.0.

---

## Flutter/Dart Dependencies

| Package | License | AGPL Compatible | Source |
| ------- | ------- | --------------- | ------ |
| flutter (SDK) | BSD-3-Clause | Yes | [flutter.dev](https://flutter.dev) |
| firebase_core | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/firebase_core/license) |
| cloud_firestore | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/cloud_firestore/license) |
| crypto | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/crypto/license) |
| signals | Apache-2.0 | Yes | [pub.dev](https://pub.dev/packages/signals/license) |
| shared_preferences | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/shared_preferences/license) |
| flutter_secure_storage | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/flutter_secure_storage/license) |
| uuid | MIT | Yes | [pub.dev](https://pub.dev/packages/uuid/license) |
| dart_jsonwebtoken | MIT | Yes | [pub.dev](https://pub.dev/packages/dart_jsonwebtoken/license) |
| http | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/http/license) |
| intl | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/intl/license) |
| collection | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/collection/license) |
| table_calendar | MIT | Yes | [pub.dev](https://pub.dev/packages/table_calendar/license) |
| url_launcher | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/url_launcher/license) |
| package_info_plus | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/package_info_plus/license) |
| go_router | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/go_router/license) |
| provider | MIT | Yes | [pub.dev](https://pub.dev/packages/provider/license) |
| flutter_svg | MIT | Yes | [pub.dev](https://pub.dev/packages/flutter_svg/license) |
| url_strategy | MIT | Yes | [pub.dev](https://pub.dev/packages/url_strategy/license) |
| sembast | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/sembast/license) |
| sembast_web | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/sembast_web/license) |
| path_provider | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/path_provider/license) |
| path | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/path/license) |
| json_annotation | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/json_annotation/license) |
| dartastic_opentelemetry | Apache-2.0 | Yes | [pub.dev](https://pub.dev/packages/dartastic_opentelemetry/license) |

### Dev Dependencies

| Package | License | AGPL Compatible | Source |
| ------- | ------- | --------------- | ------ |
| flutter_test (SDK) | BSD-3-Clause | Yes | [flutter.dev](https://flutter.dev) |
| flutter_lints | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/flutter_lints/license) |
| fake_cloud_firestore | BSD-3-Clause | Yes | [pub.dev](https://pub.dev/packages/fake_cloud_firestore/license) |
| flutter_launcher_icons | MIT | Yes | [pub.dev](https://pub.dev/packages/flutter_launcher_icons/license) |
| flutter_native_splash | MIT | Yes | [pub.dev](https://pub.dev/packages/flutter_native_splash/license) |

---

## Node.js Dependencies (Tools)

| Package | License | AGPL Compatible | Source |
| ------- | ------- | --------------- | ------ |
| @modelcontextprotocol/sdk | MIT | Yes | [npm](https://www.npmjs.com/package/@modelcontextprotocol/sdk) |

---

## License Compatibility Notes

### Permissive Licenses (Compatible with AGPL-3.0)

- **MIT**: Permissive, allows sublicensing under AGPL-3.0
- **BSD-3-Clause**: Permissive, allows sublicensing under AGPL-3.0
- **Apache-2.0**: Permissive with patent grant, compatible with AGPL-3.0

### AGPL-3.0 Requirements

When distributing this software or providing it as a network service:

1. Source code must be made available to users
2. Modifications must be released under AGPL-3.0
3. Third-party permissive-licensed code retains its original license
4. Attribution requirements of included licenses must be preserved

---

## Updating This Document

When adding new dependencies:

1. Check the license on [pub.dev](https://pub.dev) or [npm](https://npmjs.com)
2. Verify AGPL-3.0 compatibility
3. Add to the appropriate table above
4. Update the "Last Verified" date

**Incompatible licenses** (do NOT use):
- GPL-2.0-only (without "or later")
- Proprietary/Commercial licenses
- SSPL (Server Side Public License)
- Commons Clause
