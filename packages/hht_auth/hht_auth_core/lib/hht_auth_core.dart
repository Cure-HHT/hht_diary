/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces
///   REQ-d00079: Linking Code Pattern Matching interfaces
///   REQ-d00080: Session Management interfaces
///   REQ-d00081: User Document Schema
///   REQ-d00082: Password Hashing interfaces
///
/// Shared core library for HHT Diary authentication system.
///
/// This package provides models, interfaces, and utilities for authentication
/// across the HHT Diary platform. It includes:
///
/// - **Models**: Data structures for authentication (tokens, users, sponsors)
/// - **Interfaces**: Service contracts for auth, session, and password operations
/// - **Errors**: Exception types for authentication failures
/// - **Constants**: Validation rules and configuration values
/// - **Testing**: Fakes and fixtures for testing
///
/// This package is shared between:
/// - `hht_auth_client`: Flutter Web client authentication
/// - `hht_auth_server`: Cloud Run authentication service
library hht_auth_core;

// Models
export 'src/models/auth_token.dart';
export 'src/models/web_user.dart';
export 'src/models/sponsor_pattern.dart';
export 'src/models/sponsor_config.dart';
export 'src/models/auth_result.dart';
export 'src/models/registration_request.dart';
export 'src/models/login_request.dart';
export 'src/models/linking_code_validation.dart';

// Interfaces
export 'src/interfaces/auth_service.dart';
export 'src/interfaces/token_storage.dart';
export 'src/interfaces/session_manager.dart';
export 'src/interfaces/password_hasher.dart';
export 'src/interfaces/sponsor_pattern_matcher.dart';

// Errors
export 'src/errors/auth_exception.dart';
export 'src/errors/validation_exception.dart';

// Constants
export 'src/constants/validation_rules.dart';
export 'src/constants/token_config.dart';

// Testing (exported from separate entry point to avoid production dependencies)
// Use: import 'package:hht_auth_core/testing.dart';
