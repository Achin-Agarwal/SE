import 'dart:convert';

import 'package:app/providers/username.dart';
import 'package:app/providers/url.dart';
import 'package:app/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class OrganizerDashboard extends ConsumerStatefulWidget {
  const OrganizerDashboard({super.key});

  @override
  ConsumerState<OrganizerDashboard> createState() => _OrganizerDashboardState();
}

class _OrganizerDashboardState extends ConsumerState<OrganizerDashboard> {
  // Future<void> getSaleToday(String url) async {
  //   final response = await http.get(Uri.parse("$url/sale/today"));

  //   if (response.statusCode == 200) {
  //     final jsonRes = await jsonDecode(response.body);
  //     ref.read(saleProvider.notifier).list(jsonRes['sale']);
  //   }
  // }

  @override
  void initState() {
    final url = ref.read(urlProvider);
    // getSaleToday(url);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    void logout() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.clear();

      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Login()),
      );
    }

    final username = ref.watch(usernameProvider);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
        child: Column(
          children: [
            Text('Welcome, $username'),
            ElevatedButton(
              onPressed: () => logout(),
              child: Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}