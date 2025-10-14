import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/screens/login.dart';
import 'package:http/http.dart' as http;
import 'package:app/providers/userid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VendorDashboard extends ConsumerStatefulWidget {
  const VendorDashboard({super.key});

  @override
  ConsumerState<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends ConsumerState<VendorDashboard> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _requests = [];
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  // 🧠 Fetch requests from API
  Future<void> fetchRequests() async {
    setState(() => _isLoading = true);

    try {
      final vendorId = ref.read(userIdProvider);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (vendorId == null || token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Session expired. Please log in again."),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      final response = await http.get(
        Uri.parse(
          'https://achin-se-9kiip.ondigitalocean.app/vendor/$vendorId/requests',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // ✅ API returns a list directly
        if (decoded is List) {
          setState(() {
            _requests = decoded
                .whereType<Map<String, dynamic>>() // ensure elements are maps
                .toList();
          });
        } else {
          setState(() => _requests = []);
        }
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

  // ✅ Accept / Reject request
  Future<void> respondToRequest(String requestId, String action) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Missing authentication token.")),
        );
        return;
      }

      String? budget;
      String? details;

      // 🟩 If vendor is accepting, ask for details
      if (action == "accept") {
        bool submitted = false;

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
                    if (_budgetController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter a budget.")),
                      );
                      return;
                    }
                    submitted = true;
                    Navigator.pop(context);
                  },
                  child: const Text("Submit"),
                ),
              ],
            );
          },
        );

        if (!submitted) return; // if user cancelled

        budget = _budgetController.text.trim();
        details = _detailsController.text.trim();

        _budgetController.clear();
        _detailsController.clear();
      }

      // 🟨 Build the payload
      final payload = {
        "requestId": requestId,
        "action": action,
        if (budget != null && budget.isNotEmpty)
          "budget": int.tryParse(budget) ?? 0,
        if (details != null && details.isNotEmpty) "additionalDetails": details,
      };

      // 🟧 Send API request
      final response = await http.post(
        Uri.parse('https://achin-se-9kiip.ondigitalocean.app/vendor/respond'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Request ${action == 'accept' ? 'accepted' : 'rejected'} successfully!",
            ),
          ),
        );
        fetchRequests();
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

  String _formatDate(String? isoString) {
    try {
      if (isoString == null) return "—";
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
            onPressed: () {
              ref.invalidate(userIdProvider);
              SharedPreferences.getInstance().then((prefs) {
                prefs.remove('auth_token');
              });
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchRequests,
        color: const Color(0xFFE91E63),
        backgroundColor: Colors.white,
        child: _isLoading
            ? ListView(
                children: const [
                  SizedBox(
                    height: 400,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              )
            : _requests.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 400,
                    child: Center(child: Text("No pending requests")),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _requests.length,
                itemBuilder: (context, index) {
                  final req = _requests[index];
                  final userStatus = req['userStatus']?.toString() ?? "Pending";
                  final vendorStatus =
                      req['vendorStatus']?.toString() ?? "Pending";
                  final user = (req['user'] is Map)
                      ? req['user'] as Map<String, dynamic>
                      : {};
                  final status = req['vendorStatus']?.toString() ?? "Pending";

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
                            user['name']?.toString() ?? "Unknown User",
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
                          Text("🎭 Role: ${req['role'] ?? '—'}"),
                          Text("📍 Location: ${req['location'] ?? '—'}"),
                          Text("📅 Date: ${_formatDate(req['eventDate'])}"),
                          Text("📝 Description: ${req['description'] ?? '—'}"),
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

                          if (userStatus == 'Pending')
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.check),
                                  onPressed: () => respondToRequest(
                                    req['_id']?.toString() ?? "",
                                    "accept",
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF43A047),
                                  ),
                                  label: const Text("Accept"),
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => respondToRequest(
                                    req['_id']?.toString() ?? "",
                                    "reject",
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE53935),
                                  ),
                                  label: const Text("Reject"),
                                ),
                              ],
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: userStatus == 'Accepted'
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "User has ${userStatus.toLowerCase()} your offer",
                                style: TextStyle(
                                  color: userStatus == 'Accepted'
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
