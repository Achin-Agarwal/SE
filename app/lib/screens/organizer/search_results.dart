import 'dart:convert';
import 'package:app/screens/organizer/vendor_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/providers/navigation_provider.dart';
import 'package:http/http.dart' as http;
import 'package:app/providers/userid.dart';
import 'package:app/providers/location.dart';
import 'package:app/providers/date.dart';
import 'package:app/providers/description.dart';

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

    try {
      final url =
          "https://achin-se-9kiip.ondigitalocean.app/user/vendors/${widget.selectedRole}";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          vendors = data.map((v) {
            return {
              "id": v["_id"],
              "name": v["name"],
              "role": v["role"],
              "rating": (v["rating"] ?? 0).toDouble(),
              "description": v["description"] ?? "",
              "selected": false,
              "email": v["email"],
              "location": v["location"],
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
    final location = ref.read(locationProvider);
    final eventDate = ref.read(dateProvider);
    final description = ref.read(descriptionProvider);

    if (userId == null ||
        location == null ||
        eventDate == null ||
        description == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Missing event details. Please fill them first."),
        ),
      );
      return;
    }

    final body = {
      "userId": userId,
      "vendors": selectedVendorIds,
      "role": widget.selectedRole,
      "location": location,
      // 👇 Convert DateTime object to string (backend expects text)
      "eventDate": eventDate is DateTime
          ? eventDate.toIso8601String().split("T").first
          : eventDate.toString(),
      "description": description,
    };

    setState(() => _isPosting = true);

    try {
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

        // ✅ Move to next navIndex only on success
        ref.read(navIndexProvider.notifier).state = 1;
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

                // Header
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

                // Vendor List
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
                                radius: 20,
                                backgroundColor: Colors.brown[300],
                                child: Text(
                                  vendor["name"][0],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: size.width * 0.045,
                                  ),
                                ),
                              ),
                              SizedBox(width: size.width * 0.04),

                              // Vendor info
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

                // ✅ Done button triggers POST
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
