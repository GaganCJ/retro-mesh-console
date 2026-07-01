import 'package:flutter/foundation.dart';

class ConsoleLogger {
  static final ValueNotifier<List<String>> logs = ValueNotifier<List<String>>([]);
  
  static void log(String tag, String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final formatted = '[$timestamp][$tag] $message';
    debugPrint(formatted);
    
    // Run on microtask or post-frame to avoid ValueNotifier build collisions
    Future.microtask(() {
      final currentLogs = List<String>.from(logs.value);
      currentLogs.add(formatted);
      if (currentLogs.length > 25) {
        currentLogs.removeAt(0); // keep last 25 lines for terminal
      }
      logs.value = currentLogs;
    });
  }
}
