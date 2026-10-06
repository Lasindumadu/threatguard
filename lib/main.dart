import 'package:flutter/material.dart';

//import 'features/analyzer/presentation/screens/analyzer_screen.dart';
import 'features/sms/presentation/screens/sms_inbox_screen.dart';

void main() {
  runApp(const ThreatGuardApp());
}

class ThreatGuardApp extends StatelessWidget {
  const ThreatGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThreatGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SmsInboxScreen(),
    );
  }
}
