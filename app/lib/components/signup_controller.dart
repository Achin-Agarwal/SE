import 'dart:io';
import 'package:app/screens/login.dart';
import 'package:app/url.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class SignUpController extends GetxController {
  final formKey = GlobalKey<FormState>();
  var profileImage = Rx<File?>(null);
  var workImages = <File>[].obs;
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final phone = TextEditingController();
  final description = TextEditingController();
  // var gender = ''.obs;
  var role = ''.obs;

  // Location
  var latitude = 0.0.obs;
  var longitude = 0.0.obs;
  var currentLocation = ''.obs;

  final picker = ImagePicker();

  Future<void> pickProfileImage(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.pinkAccent),
                title: const Text('Take a photo'),
                onTap: () async {
                  final picked = await picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (picked != null) {
                    profileImage.value = File(picked.path);
                  }
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Colors.purpleAccent,
                ),
                title: const Text('Choose from gallery'),
                onTap: () async {
                  final picked = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (picked != null) {
                    profileImage.value = File(picked.path);
                  }
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void clearForm() {
    name.clear();
    email.clear();
    password.clear();
    phone.clear();
    description.clear();
    role.value = '';
    profileImage.value = null;
    workImages.clear();
    currentLocation.value = '';
    latitude.value = 0.0;
    longitude.value = 0.0;
    formKey.currentState?.reset();
  }

  Future<void> pickWorkImages(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.pinkAccent),
                title: const Text('Take a photo'),
                onTap: () async {
                  final picked = await picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (picked != null) {
                    workImages.add(File(picked.path));
                  }
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Colors.purpleAccent,
                ),
                title: const Text('Choose from gallery'),
                onTap: () async {
                  final pickedList = await picker.pickMultiImage();
                  if (pickedList.isNotEmpty) {
                    workImages.addAll(pickedList.map((e) => File(e.path)));
                  }
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> getCurrentLocation(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission permanently denied')),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    latitude.value = position.latitude;
    longitude.value = position.longitude;
    currentLocation.value =
        "Lat: ${position.latitude}, Lng: ${position.longitude}";
  }

  bool isFormComplete() {
    if (name.text.isEmpty ||
        email.text.isEmpty ||
        password.text.isEmpty ||
        phone.text.isEmpty ||
        role.value.isEmpty ||
        profileImage.value == null) {
      return false;
    }

    // For non-user roles: also require work images and location
    if (role.value != 'User') {
      if (workImages.isEmpty || currentLocation.value.isEmpty) return false;
    }

    return true;
  }

  Future<void> submitForm(BuildContext context) async {
    if (formKey.currentState == null || !formKey.currentState!.validate()) {
      Get.snackbar('Invalid', 'Please complete all required fields');
      return;
    }

    try {
      final String apiUrl = role.value == 'User'
          ? '$url/user/register'
          : '$url/vendor/register';

      Get.snackbar(
        'Uploading',
        'Please wait while we upload your data...',
        snackPosition: SnackPosition.BOTTOM,
      );

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      request.fields.addAll({
        'name': name.text,
        'email': email.text,
        'password': password.text,
        'phone': phone.text,
        'description': description.text,
        'role': role.value,
        'location': '{"lat": ${latitude.value}, "lon": ${longitude.value}}',
      });

      if (profileImage.value != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profileImage',
            profileImage.value!.path,
          ),
        );
      }

      for (var img in workImages) {
        request.files.add(
          await http.MultipartFile.fromPath('workImages', img.path),
        );
      }

      var response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        clearForm();
        Get.snackbar(
          'Success',
          'Signup successful!',
          snackPosition: SnackPosition.BOTTOM,
        );
        Get.offAll(() => const LoginScreen());
      } else {
        var error = await response.stream.bytesToString();
        Get.snackbar(
          'Error',
          'Signup failed: $error',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Something went wrong: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
