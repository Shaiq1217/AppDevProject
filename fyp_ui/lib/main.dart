import 'package:flutter/material.dart';
import 'login.dart';
import 'main_screen.dart';
import 'CameraScreen.dart';
import 'FileListScreen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photogrammetry',
      theme: ThemeData(
        primaryColor: Colors.black,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/main': (context) => const MainScreen(),
        '/camera': (context) => const CameraScreen(),
        '/fileList': (context) => FileListScreen(),
      },
    );
  }
}
