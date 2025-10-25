
## Benefits

### For Development Team

✅ **Single codebase**: Maintain one public repository for core platform
✅ **Type safety**: Abstract classes enforce API contracts
✅ **Automated testing**: Contract tests validate all implementations
✅ **Easy onboarding**: Template repo scaffolds new sponsors quickly
✅ **Version control**: Sponsors upgrade core at their own pace

### For Sponsors

✅ **Customizable**: Extend with custom branding, features, EDC integrations
✅ **Isolated**: Complete separation from other sponsors
✅ **Auditable**: Export code snapshot for regulatory compliance
✅ **Scalable**: Same architecture for 1 site or 1000 sites
✅ **Compliant**: FDA 21 CFR Part 11 compliance built-in

### For End Users (Patients)

✅ **Consistent experience**: All sponsors use same high-quality mobile app
✅ **Offline-first**: Works without internet connection
✅ **Secure**: Data encrypted, access controlled, audit trail complete
✅ **Reliable**: Battle-tested core platform across multiple sponsors

---## Technology Choices

### Why Flutter

**Mobile**: Single codebase for iOS and Android
- Reduce development time by 50%
- Consistent UI/UX across platforms
- Hot reload for fast development
- Strong typing with Dart
- Excellent offline support

**Portal**: Flutter Web for consistency
- Share code with mobile app
- Same widgets and business logic
- Type-safe client-server communication
- Not SEO-critical (authenticated app)

### Why Supabase

**Alternatives considered**: Custom API server, AWS Amplify, Fireb>

**Supabase chosen because**:
- PostgreSQL (required for Event Sourcing)
- Built-in RLS (security at database level)
- Auto-generated REST API (no backend code)
- Real-time subscriptions (WebSocket built-in)
- Edge Functions (custom logic without servers)
- Open source (not locked to vendor)

### Why Dart Build System

**Alternatives considered**: Bash scripts, Make, Bazel

**Dart chosen because**:
- Type-safe build scripts
- Same language as application code
- Excellent file manipulation libraries
- Cross-platform (works on macOS, Linux, Windows)
- Easy to test and maintain


## Design Decisions

## Technology Choices

### Why Flutter

**Mobile**: Single codebase for iOS and Android
- Reduce development time by 50%
- Consistent UI/UX across platforms
- Hot reload for fast development
- Strong typing with Dart
- Excellent offline support

**Portal**: Flutter Web for consistency
- Share code with mobile app
- Same widgets and business logic
- Type-safe client-server communication
- Not SEO-critical (authenticated app)

### Why Supabase

**Alternatives considered**: Custom API server, AWS Amplify, Firebase

**Supabase chosen because**:
- PostgreSQL (required for Event Sourcing)
- Built-in RLS (security at database level)
- Auto-generated REST API (no backend code)
- Real-time subscriptions (WebSocket built-in)
- Edge Functions (custom logic without servers)
- Open source (not locked to vendor)

### Why Dart Build System

**Alternatives considered**: Bash scripts, Make, Bazel

**Dart chosen because**:
- Type-safe build scripts
- Same language as application code
- Excellent file manipulation libraries
- Cross-platform (works on macOS, Linux, Windows)
- Easy to test and maintain

### Why Abstract Classes Instead of Interfaces?

Dart abstract classes can provide default implementations while still enforcing contracts. This allows:
- Core provides default behavior
- Sponsors override only what they need
- Less boilerplate in sponsor repos

### Why Single Mobile App?

**Alternative considered**: Separate app per sponsor

**Single app chosen because**:
- Easier distribution (one App Store listing)
- Shared bug fixes and features
- Lower maintenance burden
- User can use app w/o any clinical trials or studies
- App functionality is 90%+ identical across Sponsors

### Why Build-Time Composition?

**Alternative considered**: Runtime plugin loading

**Build-time chosen because**:
- Type safety at compile time
- No runtime plugin discovery needed
- Smaller app bundle (only one sponsor's code)
- Better performance
- Simpler debugging

---
