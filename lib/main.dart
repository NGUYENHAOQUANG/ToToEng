import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:totoeng/firebase_options.dart';
import 'package:totoeng/services/notification_service.dart'; // ✅ THÊM
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().initialize();
  runApp(MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, brightness: Brightness.dark),
      home: SplashScreen(),
    );
  }
}
