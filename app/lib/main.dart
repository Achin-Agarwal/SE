import 'package:app/screens/dashboard.dart';
import 'package:app/screens/vendor_dashboard.dart';
import 'package:app/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final role = prefs.getString('role');

  runApp(
    ProviderScope(
      child: Shop(token: token, role: role),
    ),
  );
}

class Shop extends StatelessWidget {
  final String? token;
  final String? role;

  const Shop({super.key, this.token, this.role});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Event Flow',
      theme: ThemeData(
        visualDensity: VisualDensity.adaptivePlatformDensity,
        primaryColor: Colors.white,
        useMaterial3: true,
      ),
      home: SplashScreen(token: token, role: role),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final String? token;
  final String? role;

  const SplashScreen({super.key, this.token, this.role});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 3), () {
      if (widget.token == null || widget.role == null) {
        Get.offAll(() => const LoginScreen());
      } else if (widget.role == 'user') {
        Get.offAll(() => const Dashboard());
      } else {
        Get.offAll(() => const VendorDashboard());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: size.width * 0.6,
          height: size.width * 0.6,
          child: Lottie.asset(
            'assets/cocktail.json',
            repeat: true,
            animate: true,
          ),
        ),
      ),
    );
  }
}
