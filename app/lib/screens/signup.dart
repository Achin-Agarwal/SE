import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:app/components/signup_controller.dart';
import 'package:lottie/lottie.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late SignUpController controller;  

  @override
  void initState() {
    super.initState();
    controller = Get.put(SignUpController());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F7),
      body: SafeArea(
        child: Obx(() {
          bool showExtra =
              controller.role.value.isNotEmpty &&
              controller.role.value != 'User';

          bool isEnabled = controller.isFormComplete();

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    // ✅ Branding Header
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
                    const SizedBox(height: 25),

                    // ✅ Form Card UI
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Form(
                        key: controller.formKey,
                        onChanged: () => setState(() {}),
                        child: Column(
                          children: [
                            // Profile Avatar Upload
                            GestureDetector(
                              onTap: () => controller.pickProfileImage(context),
                              child: Obx(
                                () => CircleAvatar(
                                  radius: 48,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage:
                                      controller.profileImage.value != null
                                      ? FileImage(
                                          controller.profileImage.value!,
                                        )
                                      : null,
                                  child: controller.profileImage.value == null
                                      ? const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Name
                            TextFormField(
                              controller: controller.name,
                              decoration: _inputDecoration(
                                "Full Name",
                                icon: Icons.person,
                              ),
                            ),
                            const SizedBox(height: 15),

                            // Role Selection
                            DropdownButtonFormField<String>(
                              decoration: _inputDecoration(
                                "Role",
                                icon: Icons.work,
                              ),
                              items:
                                  [
                                        "User",
                                        "Photographer",
                                        "Caterer",
                                        "DJ",
                                        "Decorator",
                                      ]
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (val) {
                                controller.role.value = val ?? '';
                                setState(() {});
                              },
                            ),
                            const SizedBox(height: 15),

                            TextFormField(
                              controller: controller.email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration(
                                "Email",
                                icon: Icons.email,
                              ),
                            ),
                            const SizedBox(height: 15),

                            TextFormField(
                              controller: controller.password,
                              obscureText: true,
                              decoration: _inputDecoration(
                                "Password",
                                icon: Icons.lock,
                              ),
                            ),
                            const SizedBox(height: 15),

                            TextFormField(
                              controller: controller.phone,
                              keyboardType: TextInputType.phone,
                              decoration: _inputDecoration(
                                "Phone Number",
                                icon: Icons.phone,
                              ),
                            ),
                            const SizedBox(height: 20),

                            if (showExtra) ...[
                              TextFormField(
                                controller: controller.description,
                                decoration: _inputDecoration(
                                  "About Your Service",
                                  icon: Icons.description,
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 20),

                              // Work Images Section
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text(
                                    "Work Images",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Icon(
                                    Icons.photo_library_rounded,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              Obx(
                                () => Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    ...controller.workImages.map(
                                      (file) => ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Stack(
                                          children: [
                                            Image.file(
                                              file,
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                            ),
                                            Positioned(
                                              right: 4,
                                              top: 4,
                                              child: GestureDetector(
                                                onTap: () => controller
                                                    .workImages
                                                    .remove(file),
                                                child: const CircleAvatar(
                                                  radius: 10,
                                                  backgroundColor:
                                                      Colors.black54,
                                                  child: Icon(
                                                    Icons.close,
                                                    size: 12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () =>
                                          controller.pickWorkImages(context),
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.add_a_photo,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // ✅ Location
                              Obx(
                                () => Column(
                                  children: [
                                    Text(
                                      controller.currentLocation.value.isEmpty
                                          ? "No location selected"
                                          : controller.currentLocation.value,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 5),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1A237E,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => controller
                                          .getCurrentLocation(context),
                                      child: const Text("Get Current Location"),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),
                            ],

                            // ✅ Enhanced Sign Up Button
                            AnimatedOpacity(
                              opacity: isEnabled ? 1 : 0.5,
                              duration: const Duration(milliseconds: 300),
                              child: ElevatedButton(
                                onPressed: isEnabled
                                    ? () => controller.submitForm(context)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  backgroundColor: const Color(0xFFFF5A8C),
                                ),
                                child: const Text(
                                  "Sign Up",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    GestureDetector(
                      onTap: () => Get.back(),
                      child: const Text(
                        "Already have an account? Login",
                        style: TextStyle(
                          color: Color(0xFFE57373),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.black54),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
