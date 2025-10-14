import 'package:app/screens/dashboard.dart';
import 'package:app/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  runApp(ProviderScope(child: Shop(token: token)));
}

class Shop extends StatelessWidget {
  final String? token;
  const Shop({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shop Admin',
      theme: ThemeData(
        visualDensity: VisualDensity.adaptivePlatformDensity,
        primaryColor: Colors.white,
        useMaterial3: true,
      ),
      home: SafeArea(child: (token == null) ? LoginScreen() : Dashboard()),
    );
  }
}
