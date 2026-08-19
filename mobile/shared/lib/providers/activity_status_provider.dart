import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';

final memberActivityStatusProvider = FutureProvider.autoDispose.family<bool, String>((ref, memberId) async {
  final client = SupabaseClientService().client;
  final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
  final response = await client
      .from('attendance')
      .select('check_in_date')
      .eq('member_id', memberId)
      .gte('check_in_date', sevenDaysAgo)
      .limit(1);
  return (response as List).isNotEmpty;
});