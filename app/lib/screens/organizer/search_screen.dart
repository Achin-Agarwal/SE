import 'dart:convert';
import 'package:app/providers/projectId.dart';
import 'package:app/providers/role.dart';
import 'package:app/providers/date.dart';
import 'package:app/providers/location.dart';
import 'package:app/providers/description.dart';
import 'package:app/providers/projectname.dart';
import 'package:app/providers/userid.dart';
import 'package:app/screens/login.dart';
import 'package:app/url.dart';
import 'package:app/utils/mount.dart';
import 'package:app/utils/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'search_results.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String? selectedRole;
  DateTime? selectedDate;
  DateTime? endDate;
  String? currentLocation;
  double? latitude;
  double? longitude;
  List<Map<String, dynamic>> projects = [];
  Map<String, dynamic>? selectedProject;
  bool isLoadingProjects = false;
  List<String> disabledRoles = [];
  final TextEditingController descriptionController = TextEditingController();
  bool showResults = false;
  final List<String> roles = [
    'Photographer',
    'Caterer',
    'Decorator',
    'Dj',
  ];

  bool get isFormValid =>
      selectedProject != null &&
      selectedRole != null &&
      selectedDate != null &&
      endDate != null &&
      latitude != null &&
      longitude != null &&
      descriptionController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    fetchProjects();
    descriptionController.addListener(() => safeSetState(() {}));
  }

  Future<void> _selectStartDateTime(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null) return;
    safeSetState(() {
      selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _selectEndDateTime(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: selectedDate ?? DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime:
          (selectedDate != null &&
              pickedDate.year == selectedDate!.year &&
              pickedDate.month == selectedDate!.month &&
              pickedDate.day == selectedDate!.day)
          ? TimeOfDay(
              hour: (selectedDate!.hour + 1) % 24,
              minute: selectedDate!.minute,
            )
          : TimeOfDay.now(),
    );
    if (pickedTime == null) return;
    final chosenEndDate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    if (selectedDate != null && !chosenEndDate.isAfter(selectedDate!)) {
      showSnackBar(context, "End date & time must be after start date & time");
      return;
    }
    safeSetState(() => endDate = chosenEndDate);
  }

  Future<void> fetchProjects() async {
    safeSetState(() => isLoadingProjects = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        showSnackBar(context, "Session expired. Please log in again.");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }
      final id = ref.read(userIdProvider);
      final apiUrl = Uri.parse('$url/user/project/$id');
      final response = await http.get(
        apiUrl,
        headers: {
          "Authorization": 'Bearer $token',
          "Content-Type": "application/json",
        },
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final fetchedProjects = (data as List)
            .map((p) => {'id': p['_id'], 'name': p['name']})
            .toList();
        safeSetState(() => projects = fetchedProjects);
        final savedProject = ref.read(projectNameProvider);
        if (savedProject.isNotEmpty) {
          final matchedProject = fetchedProjects.firstWhere(
            (p) => p['name'] == savedProject,
            orElse: () => {},
          );
          if (matchedProject.isNotEmpty) {
            safeSetState(() => selectedProject = matchedProject);
            _saveToProviders();
          }
        }
      } else {
        showSnackBar(context, "Failed to load projects");
      }
    } catch (e) {
      showSnackBar(context, "Error fetching projects");
    } finally {
      safeSetState(() => isLoadingProjects = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        showSnackBar(context, 'Please enable location services');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          showSnackBar(context, 'Location permission denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        showSnackBar(context, 'Location permission permanently denied');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      safeSetState(() {
        latitude = position.latitude;
        longitude = position.longitude;
        currentLocation =
            "Lat: ${latitude!.toStringAsFixed(5)}, Lng: ${longitude!.toStringAsFixed(5)}";
      });
    } catch (e) {
      showSnackBar(context, "Error fetching location");
    }
  }

  void _saveToProviders() {
    ref.read(projectNameProvider.notifier).state =
        selectedProject?['name'] ?? '';
    ref.read(projectIdProvider.notifier).state = selectedProject?['id'] ?? '';
    ref.read(roleProvider.notifier).state = selectedRole;
    ref.read(dateProvider.notifier).state = {
      'start': selectedDate,
      'end': endDate,
    };
    ref.read(locationProvider.notifier).state = {
      'latitude': latitude ?? 0.0,
      'longitude': longitude ?? 0.0,
    };
    ref.read(descriptionProvider.notifier).state = descriptionController.text
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (showResults) {
          safeSetState(() => showResults = false);
        } else {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: Align(
        alignment: Alignment.center,
        child: Container(
          width: size.width * 0.9,
          height: size.height * 0.72,
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size.width * 0.03),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: showResults
              ? SearchResult(selectedRole: selectedRole)
              : _buildForm(size),
        ),
      ),
    );
  }

  Widget _buildForm(Size size) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: size.height * 0.02),
          Text(
            "Select Project",
            style: TextStyle(
              fontSize: size.width * 0.05,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: size.height * 0.015),
          isLoadingProjects
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.folder_open,
                      size: size.width * 0.075,
                    ),
                    labelText: "Select Project",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(size.width * 0.03),
                    ),
                  ),
                  value: selectedProject,
                  onChanged: (value) =>
                      safeSetState(() => selectedProject = value),
                  items: projects
                      .map(
                        (proj) => DropdownMenuItem(
                          value: proj,
                          child: Text(proj['name']),
                        ),
                      )
                      .toList(),
                ),
          SizedBox(height: size.height * 0.03),
          Text(
            "What are you looking for?",
            style: TextStyle(
              fontSize: size.width * 0.055,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: size.height * 0.02),
          _roleDropdown(size),
          SizedBox(height: size.height * 0.02),
          _dateSelectors(size),
          _locationField(size),
          _descriptionField(size),
          _findVendorsButton(size),
        ],
      ),
    );
  }

  Widget _roleDropdown(Size size) {
    final filteredRoles = roles
        .where((r) => !disabledRoles.contains(r))
        .toList();
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.work_outline, size: size.width * 0.075),
        labelText: "Select Role",
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(size.width * 0.03),
        ),
      ),
      value: filteredRoles.contains(selectedRole) ? selectedRole : null,
      onChanged: (value) => safeSetState(() => selectedRole = value),
      items: filteredRoles
          .map(
            (role) => DropdownMenuItem(
              value: role,
              child: Text(role, style: TextStyle(fontSize: size.width * 0.04)),
            ),
          )
          .toList(),
    );
  }

  Widget _dateSelectors(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Start Date & Time",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: size.width * 0.048,
          ),
        ),
        SizedBox(height: size.height * 0.01),
        TextFormField(
          readOnly: true,
          onTap: () => _selectStartDateTime(context),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.calendar_today_outlined,
              size: size.width * 0.075,
            ),
            labelText: "Select Start Date & Time",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          controller: TextEditingController(
            text: selectedDate == null
                ? ''
                : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year} ${selectedDate!.hour}:${selectedDate!.minute.toString().padLeft(2, '0')}",
          ),
        ),
        SizedBox(height: size.height * 0.02),
        Text(
          "End Date & Time",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: size.width * 0.048,
          ),
        ),
        SizedBox(height: size.height * 0.01),
        TextFormField(
          readOnly: true,
          onTap: () => _selectEndDateTime(context),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.access_time, size: size.width * 0.075),
            labelText: "Select End Date & Time",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          controller: TextEditingController(
            text: endDate == null
                ? ''
                : "${endDate!.day}/${endDate!.month}/${endDate!.year} ${endDate!.hour}:${endDate!.minute.toString().padLeft(2, '0')}",
          ),
        ),
        SizedBox(height: size.height * 0.02),
      ],
    );
  }

  Widget _locationField(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Location",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: size.width * 0.048,
          ),
        ),
        SizedBox(height: size.height * 0.01),
        Row(
          children: [
            Expanded(
              child: Text(
                currentLocation ?? "Location not fetched",
                style: TextStyle(
                  fontSize: size.width * 0.04,
                  color: currentLocation == null ? Colors.grey : Colors.black,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.my_location, color: Color(0xFFFF4B7D)),
              onPressed: _getCurrentLocation,
            ),
          ],
        ),
      ],
    );
  }

  Widget _descriptionField(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: size.height * 0.02),
        Text(
          "Description",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: size.width * 0.048,
          ),
        ),
        SizedBox(height: size.height * 0.01),
        TextFormField(
          controller: descriptionController,
          maxLines: size.height > 700 ? 6 : 4,
          decoration: InputDecoration(
            hintText: "Add Description",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _findVendorsButton(Size size) {
    return Padding(
      padding: EdgeInsets.only(top: size.height * 0.03),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isFormValid
              ? () {
                  _saveToProviders();
                  safeSetState(() => showResults = true);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF4B7D),
            padding: EdgeInsets.symmetric(vertical: size.height * 0.018),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Text(
            "Find Vendors",
            style: TextStyle(fontSize: size.width * 0.05, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
