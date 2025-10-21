import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app/providers/role.dart';
import 'package:app/providers/date.dart';
import 'package:app/providers/location.dart';
import 'package:app/providers/description.dart';
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

  final TextEditingController descriptionController = TextEditingController();
  bool showResults = false;

  final List<String> roles = [
    'Photographer',
    'Caterer',
    'Decorator',
    'Musician',
  ];

  bool get isFormValid =>
      selectedRole != null &&
      selectedDate != null &&
      endDate != null &&
      latitude != null &&
      longitude != null &&
      descriptionController.text.trim().isNotEmpty;

  Future<void> _selectStartDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _selectEndDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: selectedDate ?? DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          endDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
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

    setState(() {
      latitude = position.latitude;
      longitude = position.longitude;
      currentLocation =
          "Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}";
    });
  }

  void _saveToProviders() {
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
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Align(
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
    );
  }

  Widget _buildForm(Size size) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: size.height * 0.02),
          Text(
            "What are you looking for?",
            style: TextStyle(
              fontSize: size.width * 0.055,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: size.height * 0.02),

          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.work_outline, size: size.width * 0.075),
              labelText: "Select Role",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(size.width * 0.03),
              ),
            ),
            value: selectedRole,
            onChanged: (value) => setState(() => selectedRole = value),
            items: roles
                .map(
                  (role) => DropdownMenuItem(
                    value: role,
                    child: Text(
                      role,
                      style: TextStyle(fontSize: size.width * 0.04),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: size.height * 0.02),

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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            controller: TextEditingController(
              text: endDate == null
                  ? ''
                  : "${endDate!.day}/${endDate!.month}/${endDate!.year} ${endDate!.hour}:${endDate!.minute.toString().padLeft(2, '0')}",
            ),
          ),
          SizedBox(height: size.height * 0.02),

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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          SizedBox(height: size.height * 0.03),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isFormValid
                  ? () {
                      _saveToProviders();
                      setState(() => showResults = true);
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
                style: TextStyle(
                  fontSize: size.width * 0.05,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
