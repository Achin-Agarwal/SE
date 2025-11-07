import 'dart:convert';
import 'package:app/components/role_item_card.dart';
import 'package:app/components/booking_detail_card.dart';
import 'package:app/providers/set.dart';
import 'package:app/url.dart';
import 'package:app/utils/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:app/providers/userid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/utils/mount.dart';

class RoleList2 extends ConsumerStatefulWidget {
  const RoleList2({
    super.key,
    required this.selectedRole,
    required this.projectId,
  });

  final String? selectedRole;
  final String projectId;

  @override
  ConsumerState<RoleList2> createState() => _RoleList2State();
}

class _RoleList2State extends ConsumerState<RoleList2> {
  List<Map<String, dynamic>> roles = [];
  Map<String, dynamic>? selectedVendor;
  bool isLoading = true;
  Set<String> completedRequests = {};
  String? projectName;
  String? token;

  @override
  void initState() {
    super.initState();
    Future(() {
      ref.read(setIndexProvider.notifier).state = 4;
    });
    _loadTokenAndFetch();
  }

  Future<void> _loadTokenAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    safeSetState(() {
      token = prefs.getString('token');
    });
    if (token == null) {
      showSnackBar(context, "Token not found");
      safeSetState(() => isLoading = false);
      return;
    }
    await fetchUserRequests();
  }

  Future<void> fetchUserRequests() async {
    safeSetState(() => isLoading = true);
    try {
      final userId = ref.read(userIdProvider);
      final urls = Uri.parse("$url/user/$userId/accepted/${widget.projectId}");
      final response = await http.get(urls, headers: {"Authorization": "Bearer $token","Content-Type": "application/json"});
      if (!mounted) return;
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List requests = data["requests"] ?? [];
        projectName = data["project"]?["name"] ?? "Untitled Project";
        final fetchedRoles = requests
            .where(
              (req) =>
                  req["role"].toString().toLowerCase() ==
                  widget.selectedRole?.toLowerCase(),
            )
            .map((req) {
              final vendor = req["vendor"];
              final vendorStatus = req["vendorStatus"];
              final status = vendorStatus?.toLowerCase() == "pending"
                  ? "Requested"
                  : "Accepted";
              return {
                'requestId': req["_id"],
                'vendorId': vendor["_id"],
                'name': vendor["name"] ?? "Unknown",
                'description': req["description"] ?? "No description",
                'rating': (vendor["rating"] ?? 0).toDouble(),
                'status': status,
                'statusColor': status == "Accepted"
                    ? const Color(0xFFFF4B7D)
                    : Colors.grey,
                'budget': req["budget"]?.toString() ?? "N/A",
                'email': vendor["email"],
                'phone': vendor["phone"],
                'role': vendor["role"],
                'userStatus': req["userStatus"]?.toString() ?? "pending",
                'projectId': data["project"]["_id"],
                'projectName': data["project"]["name"],
                'startDate': req["startDateTime"],
                'endDate': req["endDateTime"],
                'location': req["location"],
              };
            })
            .toList();
        fetchedRoles.sort((a, b) {
          if (a['status'] == b['status']) return 0;
          if (a['status'] == 'Accepted') return -1;
          return 1;
        });
        safeSetState(() {
          roles = fetchedRoles;
          isLoading = false;
        });
      } else {
        final data = jsonDecode(response.body);
        showSnackBar(context, data['message'] ?? "Failed to fetch requests");
        safeSetState(() => isLoading = false);
      }
    } catch (e) {
      showSnackBar(context, "Error fetching requests");
      safeSetState(() => isLoading = false);
    }
  }

  void markRequestCompleted(String requestId) {
    safeSetState(() {
      completedRequests.add(requestId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (roles.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: size.height * 0.05),
          child: Text(
            "No vendors found for this role.",
            style: TextStyle(
              fontSize: size.width * 0.045,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }
    return PopScope(
      canPop: selectedVendor == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selectedVendor != null) {
          safeSetState(() {
            selectedVendor = null;
          });
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: selectedVendor != null
            ? BookingDetailCard(
                key: ValueKey(selectedVendor!['requestId']),
                name: selectedVendor!['name'],
                vendorId: selectedVendor!['vendorId'],
                rating: selectedVendor!['rating'],
                description: selectedVendor!['description'],
                budget: selectedVendor!['budget'],
                requestId: selectedVendor!['requestId'],
                role: selectedVendor!['role'],
                userStatus: selectedVendor!['userStatus'],
                projectName: selectedVendor!['projectName'],
                startDate: selectedVendor!['startDate'],
                endDate: selectedVendor!['endDate'],
                location: selectedVendor!['location'],
                actionCompleted: completedRequests.contains(
                  selectedVendor!['requestId'],
                ),
                onClose: () => safeSetState(() => selectedVendor = null),
                onActionCompleted: markRequestCompleted,
              )
            : SizedBox(
                height: size.height,
                child: RefreshIndicator(
                  color: const Color(0xFFFF4B7D),
                  onRefresh: fetchUserRequests,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(
                      vertical: size.height * 0.01,
                      horizontal: size.width * 0.05,
                    ),
                    itemCount: roles.length,
                    itemBuilder: (context, index) {
                      final role = roles[index];
                      return GestureDetector(
                        onTap: () {
                          if (role['status'] == 'Accepted') {
                            safeSetState(() => selectedVendor = role);
                          }
                        },
                        child: RoleItemCard(
                          name: role['name'],
                          description: role['description'],
                          rating: role['rating'],
                          status: role['status'],
                          statusColor: role['statusColor'],
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}