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

  // 🧠 Fetch vendorId (stored after login)
  Future<String?> _getVendorId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('vendor_id');
  }

  // 🧠 Fetch requests from API
  Future<void> fetchRequests() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final vendorId = await _getVendorId();

      if (vendorId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Vendor ID not found. Please log in again."),
          ),
        );
        return;
      }

      final response = await http.get(
        Uri.parse('https://se-hxdx.onrender.com/vendor/$vendorId/requests'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _requests = data['data'] ?? []);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to fetch requests (${response.statusCode})"),
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
                      labelText: "Budget (₹)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _detailsController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Additional Details",
                      border: OutlineInputBorder(),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF43A047),
                  ),
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

        if (budget.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please enter a budget.")),
          );
          return;
        }
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
          if (budget != null && budget.isNotEmpty)
            "budget": int.tryParse(budget) ?? 0,
          if (details != null && details.isNotEmpty)
            "additionalDetails": details,
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

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return "${date.day}-${date.month}-${date.year}";
    } catch (_) {
      return "—";
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
        backgroundColor: const Color(0xFFE91E63),
        title: const Text(
          "Vendor Dashboard",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
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
                final user = req['user'] ?? {};
                final status = req['vendorStatus'];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['name'] ?? "Unknown User",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text("📧 ${user['email'] ?? '—'}"),
                        Text("📞 ${user['phone'] ?? '—'}"),
                        const Divider(height: 16),
                        Text("🎭 Role: ${req['role']}"),
                        Text("📍 Location: ${req['location']}"),
                        Text("📅 Date: ${_formatDate(req['eventDate'])}"),
                        Text("📝 Description: ${req['description']}"),
                        const SizedBox(height: 8),

                        if (status == 'Accepted')
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("💰 Budget: ₹${req['budget'] ?? '—'}"),
                              Text(
                                "📋 Details: ${req['additionalDetails'] ?? '—'}",
                              ),
                            ],
                          ),

                        const SizedBox(height: 12),

                        if (status == 'Pending')
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check),
                                onPressed: () =>
                                    respondToRequest(req['_id'], "accept"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF43A047),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                                label: const Text("Accept"),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    respondToRequest(req['_id'], "reject"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE53935),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                                label: const Text("Reject"),
                              ),
                            ],
                          ),

                        if (status == 'Accepted')
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  respondToRequest(req['_id'], "accept"),
                              child: const Text(
                                "✏️ Edit Offer",
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
