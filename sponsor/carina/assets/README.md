# Carina Branding Assets

This directory contains branding assets for the Carina sponsor.

## Required Assets

### Portal
- `logo.png` - Main logo (recommended: 200x60px, transparent background)
- `icon.png` - App icon (recommended: 512x512px)
- `favicon.png` - Browser favicon (recommended: 32x32px)

### Mobile App
- `logo.png` - Same as portal logo
- `icon.png` - Mobile app icon (1024x1024px for iOS, 512x512px for Android)

## Placeholder Assets

Currently using placeholder assets. Replace with actual Carina branding assets before production deployment.

## Asset Guidelines

- **File Format**: PNG with transparency
- **Color Space**: sRGB
- **Logo**: Should work on both light and dark backgrounds
- **Icon**: Should be recognizable at small sizes (32x32px)

## Implementation Notes

Assets are referenced in:
- `sponsor/config/carina/portal.yaml`
- `sponsor/config/carina/mobile.yaml`
- `apps/portal/pubspec.yaml`
