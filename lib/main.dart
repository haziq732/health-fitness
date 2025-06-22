import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAUh5BxHVYmtyOiK3cEzw-DARTrnGxBvH8",
        authDomain: "health-fitness-707c0.firebaseapp.com",
        projectId: "health-fitness-707c0",
        storageBucket: "health-fitness-707c0.firebasestorage.app",
        messagingSenderId: "1080417929314",
        appId: "1:1080417929314:web:2a59ebe8379f32e899e93b",
        measurementId: "G-J54Z5LJB8M"
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health & Fitness AI',
      theme: ThemeData(primarySwatch: Colors.green),
      home: LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}