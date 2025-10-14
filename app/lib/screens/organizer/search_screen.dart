import 'package:flutter/material.dart';
import 'search_results.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String? selectedRole;
  DateTime? selectedDate;
  final TextEditingController locationController = TextEditingController();
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
      locationController.text.trim().isNotEmpty &&
      descriptionController.text.trim().isNotEmpty;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    locationController.addListener(_onFormChange);
    descriptionController.addListener(_onFormChange);
  }

  void _onFormChange() => setState(() {});

  @override
  void dispose() {
    locationController.dispose();
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
        padding: EdgeInsets.only(
          left: size.width * 0.04,
          right: size.width * 0.04,
        ),
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
            "What are you looking for ?",
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
              labelStyle: TextStyle(
                fontSize: size.width * 0.048,
                fontWeight: FontWeight.w500,
              ),
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

          TextFormField(
            readOnly: true,
            onTap: () => _selectDate(context),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.calendar_today_outlined,
                size: size.width * 0.075,
              ),
              labelText: "Select Date",
              labelStyle: TextStyle(
                fontSize: size.width * 0.048,
                fontWeight: FontWeight.w500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            controller: TextEditingController(
              text: selectedDate == null
                  ? ''
                  : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
            ),
          ),
          SizedBox(height: size.height * 0.02),

          TextFormField(
            controller: locationController,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.location_on_outlined,
                size: size.width * 0.075,
              ),
              labelText: "Enter Location",
              labelStyle: TextStyle(
                fontSize: size.width * 0.048,
                fontWeight: FontWeight.w500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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
              hintStyle: TextStyle(
                fontSize: size.width * 0.048,
                color: Colors.grey,
              ),
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
                  ? () => setState(() => showResults = true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4B7D),
                padding: EdgeInsets.symmetric(vertical: size.height * 0.018),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: Text(
                "Find Vendors",
                style: TextStyle(
                  fontSize: size.width * 0.05,
                  color: isFormValid ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
