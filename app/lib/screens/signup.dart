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
      backgroundColor: const Color(0xFFF9F5F5),
      body: SafeArea(
        child: Obx(() {
          bool showExtra = controller.role.value.isNotEmpty &&
              controller.role.value != 'User';

          bool isEnabled = controller.isFormComplete();

          return Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  children: [
                    SizedBox(
                      width: size.width * 0.5,
                      child: Lottie.asset('assets/cocktail.json'),
                    ),
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
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: controller.formKey,
                    onChanged: () => setState(() {}),
                    child: Column(
                      children: [
                        // Profile Image
                        Obx(
                          () => GestureDetector(
                            onTap: () => controller.pickProfileImage(context),
                            child: CircleAvatar(
                              radius: 45,
                              backgroundColor: Colors.grey[300],
                              backgroundImage:
                                  controller.profileImage.value != null
                                      ? FileImage(controller.profileImage.value!)
                                      : null,
                              child: controller.profileImage.value == null
                                  ? const Icon(Icons.camera_alt,
                                      color: Colors.white)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: controller.fullName,
                          decoration:
                              const InputDecoration(labelText: "Full Name"),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: controller.lastName,
                          decoration:
                              const InputDecoration(labelText: "Last Name"),
                        ),
                        const SizedBox(height: 10),

                        DropdownButtonFormField<String>(
                          decoration:
                              const InputDecoration(labelText: "Gender"),
                          items: ["Male", "Female", "Other"]
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) {
                            controller.gender.value = val ?? '';
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 10),

                        DropdownButtonFormField<String>(
                          decoration:
                              const InputDecoration(labelText: "Role"),
                          items: [
                            "User",
                            "Photographer",
                            "Caterer",
                            "DJ",
                            "Decorator"
                          ]
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) {
                            controller.role.value = val ?? '';
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: controller.email,
                          decoration:
                              const InputDecoration(labelText: "Email"),
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: controller.password,
                          decoration:
                              const InputDecoration(labelText: "Password"),
                          obscureText: true,
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: controller.confirmPassword,
                          decoration: const InputDecoration(
                              labelText: "Confirm Password"),
                          obscureText: true,
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: controller.phone,
                          decoration: const InputDecoration(
                            labelText: "Phone Number",
                            suffixIcon: Icon(Icons.phone),
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (showExtra) ...[
                          // Work Images
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Work Images",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 10),
                              Obx(
                                () => Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    ...controller.workImages.map((file) {
                                      return Stack(
                                        alignment: Alignment.topRight,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: Image.file(
                                              file,
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => controller.workImages
                                                .remove(file),
                                            child: const CircleAvatar(
                                              radius: 10,
                                              backgroundColor: Colors.black54,
                                              child: Icon(Icons.close,
                                                  size: 12,
                                                  color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                    GestureDetector(
                                      onTap: () =>
                                          controller.pickWorkImages(context),
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius:
                                              BorderRadius.circular(10),
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
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Location Section
                          Obx(() => Column(
                                children: [
                                  Text(
                                    controller.currentLocation.value.isEmpty
                                        ? "No location selected"
                                        : controller.currentLocation.value,
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        controller.getCurrentLocation(context),
                                    icon: const Icon(Icons.location_on),
                                    label: const Text("Get Current Location"),
                                  ),
                                ],
                              )),
                          const SizedBox(height: 20),
                        ],

                        ElevatedButton(
                          onPressed: isEnabled
                              ? () => controller.submitForm()
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE57373),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text(
                            "Sign Up",
                            style:
                                TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: () => Get.back(),
                  child: const Text(
                    "Already have an account? Login",
                    style: TextStyle(
                      color: Color(0xFFE57373),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
