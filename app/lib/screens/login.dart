import 'dart:convert';
import 'package:app/screens/dashboard.dart';
import 'package:app/screens/signup.dart';
import 'package:app/screens/vendor_dashboard.dart';
import 'package:app/url.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/providers/username.dart';
import 'package:app/providers/userid.dart';
import 'package:app/providers/image.dart';
import 'package:lottie/lottie.dart';

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
  bool _passwordVisible = false;

  final List<String> roles = ['User', 'Photographer', 'Caterer', 'Decorator'];

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$url/vendor/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
          "role": _selectedRole != null
              ? _selectedRole![0].toLowerCase() + _selectedRole!.substring(1)
              : null,
        }),
      );

      final data = jsonDecode(response.body);
      print("Response data: $data");

      if (response.statusCode == 200 && data['status'] == 'success') {
        final user = data['data']['user'] ?? null;
        final vendor = data['data']['vendor'] ?? null;
        final token = data['data']['token'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('role', _selectedRole!);

        if (_selectedRole == 'User') {
          print("Setting user data");
          ref.read(usernameProvider.notifier).state = user['name'];
          ref.read(userIdProvider.notifier).state = user['id'];
          ref.read(imageProvider.notifier).state = user['image'];
        } else {
          print("Setting vendor data");
          ref.read(usernameProvider.notifier).state = vendor['name'];
          ref.read(userIdProvider.notifier).state = vendor['id'];
          ref.read(imageProvider.notifier).state = vendor['image'];
        }
        print(token);

        print("Login successful! Welcome ");
        if (_selectedRole == 'User') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SafeArea(child: Dashboard()),
            ),
          );
        } else {
          print("Vendor Dashboard");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SafeArea(child: VendorDashboard()),
            ),
          );
        }
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
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: size.width * 0.55,
                    child: Lottie.asset('assets/cocktail.json'),
                  ),
                  const SizedBox(height: 5),
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'EVENT ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                            fontSize: 26,
                          ),
                        ),
                        TextSpan(
                          text: 'FLOW',
                          style: TextStyle(
                            color: Color(0xFFE57373),
                            fontWeight: FontWeight.w600,
                            fontSize: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Wrapper Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: const Icon(Icons.email_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (val) =>
                              val!.isEmpty ? "Enter your email" : null,
                        ),

                        const SizedBox(height: 18),

                        StatefulBuilder(
                          builder: (context, setPassState) {
                            return TextFormField(
                              controller: _passwordController,
                              obscureText: !_passwordVisible,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _passwordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setPassState(
                                      () =>
                                          _passwordVisible = !_passwordVisible,
                                    );
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              validator: (val) =>
                                  val!.isEmpty ? "Enter your password" : null,
                            );
                          },
                        ),
                        const SizedBox(height: 18),

                        StatefulBuilder(
                          builder: (context, setPassState) {
                            return TextFormField(
                              controller: _passwordController,
                              obscureText: !_passwordVisible,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _passwordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setPassState(
                                      () =>
                                          _passwordVisible = !_passwordVisible,
                                    );
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              validator: (val) =>
                                  val!.isEmpty ? "Enter your password" : null,
                            );
                          },
                        ),
                        const SizedBox(height: 18),

                        StatefulBuilder(
                          builder: (context, setPassState) {
                            return TextFormField(
                              controller: _passwordController,
                              obscureText: !_passwordVisible,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _passwordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setPassState(
                                      () =>
                                          _passwordVisible = !_passwordVisible,
                                    );
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              validator: (val) =>
                                  val!.isEmpty ? "Enter your password" : null,
                            );
                          },
                        ),
                        const SizedBox(height: 18),

                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          items: roles
                              .map(
                                (r) =>
                                    DropdownMenuItem(value: r, child: Text(r)),
                              )
                              .toList(),
                          decoration: InputDecoration(
                            labelText: 'Select Role',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onChanged: (value) =>
                              setState(() => _selectedRole = value),
                          validator: (val) =>
                              val == null ? "Please select a role" : null,
                        ),

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

                        const SizedBox(height: 12),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: size.width,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5A8C),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: const Text(
                              "Login",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account? "),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
                              },
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
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
