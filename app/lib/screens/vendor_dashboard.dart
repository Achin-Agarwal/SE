import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/screens/login.dart';
import 'package:http/http.dart' as http;
import 'package:app/providers/userid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ionicons/ionicons.dart';

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
        if (decoded is List) {
          setState(() {
            _requests = decoded.whereType<Map<String, dynamic>>().toList();
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

      if (action == "accept") {
        bool submitted = false;

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text("Provide Offer Details"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Budget (₹)",
                    prefixIcon: Icon(Ionicons.cash_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _detailsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Additional Details",
                    prefixIcon: Icon(Ionicons.document_text_outline),
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
                  backgroundColor: const Color(0xFFE91E63),
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
          ),
        );

        if (!submitted) return;
        budget = _budgetController.text.trim();
        details = _detailsController.text.trim();
        _budgetController.clear();
        _detailsController.clear();
      }

      final payload = {
        "requestId": requestId,
        "action": action,
        if (budget != null && budget.isNotEmpty)
          "budget": int.tryParse(budget) ?? 0,
        if (details != null && details.isNotEmpty) "additionalDetails": details,
      };

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
            backgroundColor: action == 'accept' ? Colors.green : Colors.red,
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
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Ionicons.log_out_outline, color: Colors.white),
            onPressed: () {
              ref.invalidate(userIdProvider);
              SharedPreferences.getInstance().then(
                (prefs) => prefs.remove('auth_token'),
              );
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
            ? const Center(child: CircularProgressIndicator())
            : _requests.isEmpty
            ? const Center(child: Text("No pending requests"))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _requests.length,
                itemBuilder: (context, index) {
                  final req = _requests[index];
                  final user = (req['user'] is Map)
                      ? req['user'] as Map<String, dynamic>
                      : {};
                  final userStatus = req['userStatus'] ?? "Pending";
                  final vendorStatus = req['vendorStatus'] ?? "Pending";
                  final statusColor = vendorStatus == "Accepted"
                      ? Colors.green
                      : vendorStatus == "Rejected"
                      ? Colors.red
                      : Colors.orange;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.pink.shade50, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink.withOpacity(0.15),
                          offset: const Offset(0, 4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 26,
                                backgroundColor: Color(0xFFE91E63),
                                child: Icon(
                                  Ionicons.person_outline,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user['name']?.toString() ??
                                          "Unknown User",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user['email'] ?? "No email",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                vendorStatus == "Accepted"
                                    ? Ionicons.checkmark_circle
                                    : vendorStatus == "Rejected"
                                    ? Ionicons.close_circle
                                    : Ionicons.time_outline,
                                color: statusColor,
                                size: 28,
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              const Icon(Ionicons.briefcase_outline, size: 18),
                              const SizedBox(width: 6),
                              Text("Role: ${req['role'] ?? '—'}"),
                            ],
                          ),
                          // Row(
                          //   children: [
                          //     const Icon(Ionicons.location_outline, size: 18),
                          //     const SizedBox(width: 6),
                          //     Text("Location: ${req['location'] ?? '—'}"),
                          //   ],
                          // ),
                          Row(
                            children: [
                              const Icon(Ionicons.calendar_outline, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                "Event Date: ${_formatDate(req['eventDate'])}",
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text("📝 ${req['description'] ?? '—'}"),
                          const SizedBox(height: 10),

                          if (vendorStatus == "Accepted")
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("💰 Budget: ₹${req['budget'] ?? '—'}"),
                                  Text(
                                    "📋 Details: ${req['additionalDetails'] ?? '—'}",
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 12),
                          if (userStatus == "Pending")
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Ionicons.checkmark_outline),
                                  label: const Text("Accept"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => respondToRequest(
                                    req['_id'] ?? "",
                                    "accept",
                                  ),
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Ionicons.close_outline),
                                  label: const Text("Reject"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => respondToRequest(
                                    req['_id'] ?? "",
                                    "reject",
                                  ),
                                ),
                              ],
                            )
                          else
                            Center(
                              child: Container(
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
