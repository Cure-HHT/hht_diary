// IMPLEMENTS REQUIREMENTS:
//   REQ-p00009: Sponsor-Specific Web Portals
//   REQ-p00003: Separate Database Per Sponsor

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // TODO: Replace with actual Carina Supabase credentials
  // These should be loaded from environment variables in production
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
