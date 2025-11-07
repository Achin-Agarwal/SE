import 'dart:convert';
import 'package:app/providers/set.dart';
import 'package:app/screens/login.dart';
import 'package:app/screens/organizer/vendor_detail_page.dart';
import 'package:app/url.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/providers/navigation_provider.dart';
import 'package:http/http.dart' as http;
import 'package:app/providers/userid.dart';
import 'package:app/providers/location.dart';
import 'package:app/providers/date.dart';
import 'package:app/providers/description.dart';
import 'package:app/providers/projectId.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchResult extends ConsumerStatefulWidget {
  final String? selectedRole;
  const SearchResult({super.key, required this.selectedRole});

  @override
  ConsumerState<SearchResult> createState() => _SearchResultState();
}

class _SearchResultState extends ConsumerState<SearchResult> {
  Map<String, dynamic>? selectedVendor;
  List<Map<String, dynamic>> vendors = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    Future(() => ref.read(setIndexProvider.notifier).state = 1);
    fetchVendors();
  }

  void safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> fetchVendors() async {
    safeSetState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final location = ref.read(locationProvider);
      final lat = location['latitude'];
      final lon = location['longitude'];
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        _handleSessionExpired();
        return;
      }
      final userId = ref.read(userIdProvider);
      final projectId = ref.read(projectIdProvider);
      final uri = Uri.parse(
          '$url/user/vendors/${widget.selectedRole}?lat=$lat&lon=$lon&userId=$userId&projectId=$projectId');
      final response = await http.get(uri, headers: {
        "Authorization": 'Bearer $token',
        "Content-Type": "application/json",
      });
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! List) throw const FormatException("Invalid data format");
        final parsedVendors = decoded.map<Map<String, dynamic>>((v) {
          return {
            "id": v["_id"]?.toString() ?? "",
            "name": v["name"]?.toString() ?? "Unnamed",
            "role": v["role"]?.toString() ?? "",
            "rating": (v["rating"] is num) ? (v["rating"] as num).toDouble() : 0.0,
            "description": v["description"]?.toString() ?? "",
            "selected": false,
            "email": v["email"]?.toString() ?? "",
            "location": v["location"] ?? {},
            "profileImage": v["profileImage"]?.toString() ?? "",
            "workImages": (v["workImages"] is List)
                ? List<String>.from((v["workImages"] as List)
                    .map((img) => img?.toString() ?? "")
                    .where((img) => img.isNotEmpty))
                : <String>[],
          };
        }).toList();
        safeSetState(() => vendors = parsedVendors);
      } else if (response.statusCode == 401) {
        _handleSessionExpired();
      } else {
        throw Exception("Failed to load vendors (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("Fetch vendors error: $e");
      safeSetState(() => _hasError = true);
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  void _handleSessionExpired() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Session expired. Please log in again.")),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> sendRequestToVendors() async {
    final selectedVendorIds =
        vendors.where((v) => v["selected"] == true).map<String>((v) => v["id"]).toList();
    if (selectedVendorIds.isEmpty) {
      _showSnackbar("Please select at least one vendor");
      return;
    }
    final userId = ref.read(userIdProvider);
    final projectId = ref.read(projectIdProvider);
    final location = ref.read(locationProvider);
    final dateMap = ref.read(dateProvider);
    final description = ref.read(descriptionProvider);
    if (projectId == null || dateMap['start'] == null || dateMap['end'] == null) {
      _showSnackbar("Missing project or event details. Please fill them first.");
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      _handleSessionExpired();
      return;
    }
    final body = {
      "userId": userId,
      "projectId": projectId,
      "vendors": selectedVendorIds,
      "role": widget.selectedRole,
      "location": location,
      "startDateTime": (dateMap['start'] as DateTime).toIso8601String(),
      "endDateTime": (dateMap['end'] as DateTime).toIso8601String(),
      "description": description,
    };
    safeSetState(() => _isPosting = true);
    try {
      final response = await http.post(
        Uri.parse("$url/user/sendrequests"),
        headers: {
          "Authorization": 'Bearer $token',
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackbar("Requests sent successfully!", isSuccess: true);
        ref.read(navIndexProvider.notifier).state = 2;
      } else if (response.statusCode == 401) {
        _handleSessionExpired();
      } else {
        final msg = response.body.isNotEmpty
            ? (jsonDecode(response.body)['message'] ?? "Unknown error")
            : "Server error";
        _showSnackbar("Failed to send requests: $msg");
      }
    } catch (e) {
      _showSnackbar("Network error: ${e.toString()}");
    } finally {
      safeSetState(() => _isPosting = false);
    }
  }

  void _showSnackbar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final vendorsOfRole = vendors;
    final allSelected =
        vendorsOfRole.isNotEmpty && vendorsOfRole.every((v) => v["selected"]);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Failed to load vendors. Please try again."),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: fetchVendors,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4B7D),
              ),
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: fetchVendors,
      child: Container(
        padding: EdgeInsets.only(bottom: size.height * 0.015),
        width: size.width * 0.9,
        child: selectedVendor == null
            ? _buildVendorList(context, size, vendorsOfRole, allSelected)
            : VendorDetailCard(
                vendor: selectedVendor!,
                onClose: () => safeSetState(() => selectedVendor = null),
              ),
      ),
    );
  }

  Widget _buildVendorList(
      BuildContext context, Size size, List vendorsOfRole, bool allSelected) {
    return Column(
      children: [
        SizedBox(height: size.height * 0.01),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "List",
              style: TextStyle(
                fontSize: size.width * 0.06,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Text(
                  "All",
                  style: TextStyle(
                    fontSize: size.width * 0.04,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFFF4B7D),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    safeSetState(() {
                      for (var vendor in vendorsOfRole) {
                        vendor["selected"] = !allSelected;
                      }
                    });
                  },
                  icon: Icon(
                    allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: const Color(0xFFFF4B7D),
                    size: size.width * 0.07,
                  ),
                ),
              ],
            ),
          ],
        ),
        Expanded(
          child: ListView.builder(
            itemCount: vendorsOfRole.length,
            itemBuilder: (context, index) {
              final vendor = vendorsOfRole[index];
              return InkWell(
                onTap: () => safeSetState(() => selectedVendor = vendor),
                child: _buildVendorTile(size, vendor),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: size.height * 0.015),
          child: ElevatedButton(
            onPressed: _isPosting ? null : sendRequestToVendors,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4B7D),
              minimumSize: Size(double.infinity, size.height * 0.065),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: _isPosting
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    "Done",
                    style: TextStyle(
                      fontSize: size.width * 0.045,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildVendorTile(Size size, Map<String, dynamic> vendor) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      padding: EdgeInsets.symmetric(vertical: size.height * 0.006),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: size.width * 0.07,
            backgroundColor: Colors.grey[300],
            child: ClipOval(
              child: Image.network(
                vendor["profileImage"] ?? "",
                fit: BoxFit.cover,
                width: size.width * 0.14,
                height: size.width * 0.14,
                loadingBuilder: (context, child, loadingProgress) =>
                    loadingProgress == null
                        ? child
                        : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.person, color: Colors.black54, size: 28),
              ),
            ),
          ),
          SizedBox(width: size.width * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendor["name"],
                  style: TextStyle(
                    fontSize: size.width * 0.045,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: size.height * 0.004),
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < (vendor["rating"] ?? 0).floor()
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: size.width * 0.04,
                      ),
                    ),
                    SizedBox(width: size.width * 0.02),
                    Text(
                      vendor["rating"].toString(),
                      style: TextStyle(
                        fontSize: size.width * 0.035,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: size.height * 0.004),
                Text(
                  vendor["description"] ?? "",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: size.width * 0.035,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              safeSetState(() {
                vendor["selected"] = !vendor["selected"];
              });
            },
            icon: Icon(
              vendor["selected"]
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color:
                  vendor["selected"] ? const Color(0xFFFF4B7D) : Colors.grey[400],
              size: size.width * 0.07,
            ),
          ),
        ],
      ),
    );
  }
}
