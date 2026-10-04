import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/core/constants/supabase_config.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  
  final supabase = Supabase.instance.client;
  
  try {
    final response = await supabase
        .from('user_devices')
        .delete()
        .is_('email', null)
        .not('device_id', 'like', 'quota:%')
        .select();
        
    print("Deleted ${response.length} old device records.");
  } catch (e) {
    print("Error: $e");
  }
  
  exit(0);
}
