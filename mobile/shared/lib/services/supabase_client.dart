import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientService {
  static final SupabaseClientService _instance = SupabaseClientService._();
  factory SupabaseClientService() => _instance;
  SupabaseClientService._();

  SupabaseClient get client => Supabase.instance.client;

  Future<void> initialize({
    required String supabaseUrl,
    required String anonKey,
  }) async {
    await Supabase.initialize(url: supabaseUrl, anonKey: anonKey);
  }
}
