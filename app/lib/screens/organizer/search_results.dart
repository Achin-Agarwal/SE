import 'dart:convert';
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
    fetchVendors();
  }

  Future<void> fetchVendors() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final location = ref.read(locationProvider);
    final lat = location['latitude'];
    final lon = location['longitude'];

    try {
      final userId = ref.read(userIdProvider);
      final projectId = ref.read(projectIdProvider);
      final response = await http.get(
        Uri.parse(
          '$url/user/vendors/${widget.selectedRole}?lat=$lat&lon=$lon&userId=$userId&projectId=$projectId',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print("Fetched vendors: $data");
        setState(() {
          vendors = data.map((v) {
            return {
              "id": v["_id"]?.toString() ?? "",
              "name": v["name"]?.toString() ?? "Unnamed",
              "role": v["role"]?.toString() ?? "",
              "rating": (v["rating"] is num)
                  ? (v["rating"] as num).toDouble()
                  : 0.0,
              "description": v["description"]?.toString() ?? "",
              "selected": false,
              "email": v["email"]?.toString() ?? "",
              "location": v["location"] ?? {},
              "profileImage": v["profileImage"]?.toString() ?? "",
              "workImages": (v["workImages"] is List)
                  ? List<String>.from(
                      (v["workImages"] as List)
                          .map((img) => img?.toString() ?? "")
                          .where((img) => img.isNotEmpty),
                    )
                  : <String>[],
            };
          }).toList();
        });
      } else {
        setState(() => _hasError = true);
      }
    } catch (e) {
      setState(() => _hasError = true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> sendRequestToVendors() async {
    final selectedVendorIds = vendors
        .where((v) => v["selected"] == true)
        .map<String>((v) => v["id"])
        .toList();

    if (selectedVendorIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one vendor")),
      );
      return;
    }

    final userId = ref.read(userIdProvider);
    final projectId = ref.read(projectIdProvider);
    final location = ref.read(locationProvider);
    final dateMap = ref.read(dateProvider);
    final description = ref.read(descriptionProvider);

    if (projectId == null ||
        dateMap['start'] == null ||
        dateMap['end'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Missing project or event details. Please fill them first.",
          ),
        ),
      );
      return;
    }

    final startDate = (dateMap['start'] as DateTime).toIso8601String();
    final endDate = (dateMap['end'] as DateTime).toIso8601String();

    final body = {
      "userId": userId,
      "projectId": projectId,
      "vendors": selectedVendorIds,
      "role": widget.selectedRole,
      "location": location,
      "startDateTime": startDate,
      "endDateTime": endDate,
      "description": description,
    };

    setState(() => _isPosting = true);

    try {
      print("Sending request body: $body");
      final response = await http.post(
        Uri.parse(
          "https://achin-se-9kiip.ondigitalocean.app/user/sendrequests",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Requests sent successfully!")),
        );
        ref.read(navIndexProvider.notifier).state = 2;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to send requests. (${response.statusCode}) Try again.",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error sending requests: $e")));
    } finally {
      setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final vendorsOfRole = vendors;
    final allSelected =
        vendorsOfRole.isNotEmpty &&
        vendorsOfRole.every((v) => v["selected"] == true);

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

    return Container(
      padding: EdgeInsets.only(bottom: size.height * 0.015),
      width: size.width * 0.9,
      child: selectedVendor == null
          ? Column(
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
                            setState(() {
                              for (var vendor in vendorsOfRole) {
                                vendor["selected"] = !allSelected;
                              }
                            });
                          },
                          icon: Icon(
                            allSelected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
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
                        onTap: () {
                          setState(() {
                            selectedVendor = vendor;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: size.height * 0.006,
                          ),
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
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          );
                                        },
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.person,
                                              color: Colors.black54,
                                              size: 28,
                                            ),
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
                                  setState(() {
                                    vendor["selected"] = !vendor["selected"];
                                  });
                                },
                                icon: Icon(
                                  vendor["selected"]
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  color: vendor["selected"]
                                      ? const Color(0xFFFF4B7D)
                                      : Colors.grey[400],
                                  size: size.width * 0.07,
                                ),
                              ),
                            ],
                          ),
                        ),
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
            )
          : VendorDetailCard(
              vendor: selectedVendor!,
              onClose: () {
                setState(() {
                  selectedVendor = null;
                });
              },
            ),
    );
  }
}
