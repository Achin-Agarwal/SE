import 'dart:convert';
import 'dart:developer';

import 'package:app/providers/url.dart';
import 'package:app/screens/organizer_dashboard.dart';
import 'package:app/providers/username.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Login extends ConsumerWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TextEditingController username = TextEditingController();
    TextEditingController password = TextEditingController();

    final url = ref.read(urlProvider);

    Future<void> loginAdmin() async {
      if (username.text.trim().isEmpty || password.text.trim().isEmpty) {
        const snackbar = SnackBar(
          content: Text('Both the fields are required'),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackbar);
        return;
      }

      final body = {
        "username": username.text.trim(),
        "password": password.text.trim(),
      };

      try {
        final response = await http.post(
          Uri.parse("$url/admin/login"),
          body: jsonEncode(body),
          headers: {'Content-Type': 'application/json'},
        );

        final jsonRes = await jsonDecode(response.body);
        if (!context.mounted) return;
        if (response.statusCode == 200) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', jsonRes['data']['token']);
          await prefs.setString('username', jsonRes['data']['username']);

          ref.read(usernameProvider.notifier).state =
              jsonRes['data']['username'];
          if (!context.mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => OrganizerDashboard()),
          );
        } else {
          const errorBar = SnackBar(content: Text('Error logging in'));
          ScaffoldMessenger.of(context).showSnackBar(errorBar);
        }
      } catch (e) {
        log(e.toString());
        const errorBar = SnackBar(content: Text('Error logging in'));
        ScaffoldMessenger.of(context).showSnackBar(errorBar);
      }
    }

    return Scaffold(
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.2,
              child: Center(
                child: Text(
                  'Shop',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 10,
                  children: [
                    TextField(
                      controller: username,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.black, width: 2),
                        ),
                        hintText: 'johndoe',
                        hintStyle: TextStyle(fontSize: 13),
                        labelStyle: TextStyle(fontSize: 13),
                        label: Text('Username'),
                      ),
                    ),
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.black, width: 2),
                        ),
                        hintText: '12345678',
                        label: Text('password'),
                        hintStyle: TextStyle(fontSize: 13),
                        labelStyle: TextStyle(fontSize: 13),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => loginAdmin(),
                      child: Text('Login'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          ],
        ),
      ),
    );
  }
}