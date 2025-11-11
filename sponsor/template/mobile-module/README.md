# Mobile Module

This directory contains the sponsor-specific mobile app integration code.

## Structure

- `lib/`: Dart code for mobile module
- `assets/`: Images, fonts, etc.
- `config.yml`: Module configuration

## Requirements

The mobile module must:
1. Export a `SponsorModule` class
2. Implement required interfaces from core packages
3. Follow Flutter best practices
4. Include comprehensive tests

## Example Structure

```
mobile-module/
├── lib/
│   ├── sponsor_module.dart       # Main module export
│   ├── models/                   # Data models
│   ├── screens/                  # UI screens
│   ├── services/                 # Business logic
│   └── widgets/                  # Reusable widgets
├── assets/
│   ├── images/
│   └── fonts/
└── test/
    └── ...
```

## Integration

The mobile module will be copied into `apps/mobile/lib/sponsors/<sponsor-name>/`
during the build process by the integration script.

## Testing

Test the module independently:
```bash
cd mobile-module
flutter test
```

Test integration with core app:
```bash
# From repo root
./tools/build/integrate-sponsors.sh --sponsors-dir sponsor --manifest <manifest>
cd apps/mobile
flutter test
```
