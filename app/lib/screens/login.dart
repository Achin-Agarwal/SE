import 'dart:convert';
import 'package:app/screens/dashboard.dart';
import 'package:app/screens/vendor_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/providers/username.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _selectedRole;
  bool _isLoading = false;

  final List<String> roles = ['User', 'Photographer', 'Caterer', 'Decorator'];

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    const String apiUrl = "https://se-hxdx.onrender.com/vendor/login";

    try {
      // final response = await http.post(
      //   Uri.parse(apiUrl),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({
      //     "email": _emailController.text.trim(),
      //     "password": _passwordController.text,
      //     "role": _selectedRole,
      //   }),
      // );

      // final data = jsonDecode(response.body);

      // if (response.statusCode == 200 && data['status'] == 'success') {
      //   final user = data['data']['user'];
      // final token = data['data']['token'];
      final token =
          "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY4ZWRlOWViZWZmOWM1ZjMyZTMwNmJhMCIsInJvbGUiOiJ1c2VyIiwiaWF0IjoxNzYwNDQ1MzEzLCJleHAiOjE3NjEwNTAxMTN9.NLTCsqDhiqkHeRdxSnOjUX85CX8SZ46E88REpHQvm6g";

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);

      // ref.read(usernameProvider.notifier).state = user['name'];
      // ref.read(userIdProvider.notifier).state = user['id'];

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Login successful! Welcome ${user['name']}")),
      // );

      // TODO: Navigate to your dashboard or main screen
      // Navigator.pushReplacementNamed(context, '/dashboard');
      // } else {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text(data['message'] ?? "Login failed")),
      //   );
      // }
      print("Login successful! Welcome ");
      if (_selectedRole == 'User') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SafeArea(child: Dashboard())),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SafeArea(child: VendorDashboard()),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  Image.asset('assets/logo.png', height: 80),
                  const SizedBox(height: 10),
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'EVENT ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                            fontSize: 22,
                          ),
                        ),
                        TextSpan(
                          text: 'FLOW',
                          style: TextStyle(
                            color: Color(0xFFE57373),
                            fontWeight: FontWeight.w500,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'you@example.com',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? "Enter your email" : null,
              ),
              const SizedBox(height: 20),

              // Role Dropdown
              DropdownButtonFormField<String>(
                value: _selectedRole,
                items: roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                decoration: InputDecoration(
                  labelText: 'Role',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) => setState(() => _selectedRole = value),
                validator: (val) => val == null ? "Please select a role" : null,
              ),
              const SizedBox(height: 20),

              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? "Enter your password" : null,
              ),
              const SizedBox(height: 10),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(color: Color(0xFFE57373)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Login button
              SizedBox(
                width: size.width,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5A8C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Login",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Sign Up
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don’t have an account? "),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(
                        color: Color(0xFFE57373),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
