import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
import 'app/app.dart';
import 'features/shared/services/interaction_monitor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await SupabaseClientService().initialize(
    supabaseUrl: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  InteractionMonitor.instance.ensureStarted();
  runApp(const ProviderScope(child: FitnessApp()));
}
