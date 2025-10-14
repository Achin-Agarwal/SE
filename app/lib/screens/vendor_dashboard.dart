import 'dart:convert';
import 'package:app/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  bool _isLoading = false;
  List<dynamic> _requests = [];

  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  // 🧠 Fetch requests from API
  Future<void> fetchRequests() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('https://se-hxdx.onrender.com/vendor/requests'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _requests = data['data'] ?? []);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to fetch requests")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ Accept or Reject request
  Future<void> respondToRequest(String requestId, String action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      String? budget;
      String? details;

      if (action == "accept") {
        await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("Provide Offer Details"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _budgetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Budget",
                      hintText: "Enter budget amount",
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _detailsController,
                    decoration: const InputDecoration(
                      labelText: "Additional Details",
                      hintText: "Add optional notes",
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Submit"),
                ),
              ],
            );
          },
        );

        budget = _budgetController.text.trim();
        details = _detailsController.text.trim();
      }

      final response = await http.post(
        Uri.parse('https://se-hxdx.onrender.com/vendor/respond'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "requestId": requestId,
          "action": action,
          if (budget != null) "budget": budget,
          if (details != null) "additionalDetails": details,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Request $action successfully!")),
        );
        fetchRequests(); // Refresh list
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Action failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F7),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 216, 87, 166),
        title: GestureDetector(
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('auth_token'); // delete token

            // Navigate back to login screen
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false, // removes all previous routes
            );
          },
          child: const Text(
            "Vendor Dashboard",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? const Center(child: Text("No pending requests"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req['user']['name'] ?? "Unknown User",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text("Event: ${req['role']}"),
                        Text("Location: ${req['location']}"),
                        Text("Date: ${req['eventDate']}"),
                        Text("Description: ${req['description']}"),
                        if (req['vendorStatus'] == 'Accepted')
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Budget: ₹${req['budget'] ?? '—'}"),
                                Text(
                                  "Details: ${req['additionalDetails'] ?? '—'}",
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),
                        if (req['vendorStatus'] == 'Pending')
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                onPressed: () =>
                                    respondToRequest(req['_id'], "accept"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF43A047),
                                ),
                                child: const Text("Accept"),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    respondToRequest(req['_id'], "reject"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE53935),
                                ),
                                child: const Text("Reject"),
                              ),
                            ],
                          ),
                        if (req['vendorStatus'] == 'Accepted')
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => respondToRequest(
                                req['_id'],
                                "accept",
                              ), // to edit offer
                              child: const Text(
                                "Edit Offer",
                                style: TextStyle(color: Colors.blueAccent),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
