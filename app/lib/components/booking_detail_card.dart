import 'dart:convert';
import 'package:app/providers/set.dart';
import 'package:app/utils/date_utils.dart';
import 'package:app/utils/detail_row.dart';
import 'package:app/utils/mount.dart';
import 'package:app/utils/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:app/providers/userid.dart';
import 'package:app/url.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingDetailCard extends ConsumerStatefulWidget {
  final String name;
  final double rating;
  final String description;
  final String vendorId;
  final String budget;
  final VoidCallback onClose;
  final String requestId;
  final String role;
  final String userStatus;
  final bool actionCompleted;
  final Function(String) onActionCompleted;
  final String projectName;
  final String? startDate;
  final String? endDate;
  final dynamic location;

  const BookingDetailCard({
    super.key,
    required this.name,
    required this.rating,
    required this.description,
    required this.budget,
    required this.onClose,
    required this.requestId,
    required this.role,
    required this.userStatus,
    required this.actionCompleted,
    required this.onActionCompleted,
    required this.vendorId,
    required this.projectName,
    this.startDate,
    this.endDate,
    this.location,
  });

  @override
  ConsumerState<BookingDetailCard> createState() => _BookingDetailCardState();
}

class _BookingDetailCardState extends ConsumerState<BookingDetailCard> {
  bool _loading = false;
  bool _progressLoading = true;
  bool _reviewSubmitting = false;
  bool _allStepsDone = false;
  bool _reviewSubmitted = false;
  List<dynamic> _progressSteps = [];
  double _reviewRating = 0.0;
  final TextEditingController _reviewController = TextEditingController();
  String? _token;

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    safeSetState(() => _token = prefs.getString('auth_token'));
  }

  Widget _locationRow(Map<String, dynamic>? location) {
    final coords = location?["coordinates"];
    if (coords == null || coords.length != 2)
      return detailRow("Location", "Not available");
    final longitude = coords[0];
    final latitude = coords[1];
    final url = "https://www.google.com/maps?q=$latitude,$longitude";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Location",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          Flexible(
            child: GestureDetector(
              onTap: () async {
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              child: Text(
                "${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}",
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchProgress() async {
    if (_token == null) return;
    try {
      final response = await http.get(
        Uri.parse("$url/user/vendorrequest/${widget.requestId}/progress"),
        headers: {
          "Authorization": "Bearer $_token",
          "Content-Type": "application/json",
        },
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        safeSetState(() {
          _progressSteps = data;
          _progressLoading = false;
          _allStepsDone = _progressSteps.every((step) => step["done"] == true);
        });
      } else {
        safeSetState(() => _progressLoading = false);
      }
    } catch (_) {
      safeSetState(() => _progressLoading = false);
    }
  }

  Future<void> _updateProgress(String text, bool done) async {
    if (_token == null) return;
    try {
      final response = await http.put(
        Uri.parse("$url/user/vendorrequest/${widget.requestId}/progress"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_token",
        },
        body: jsonEncode({"text": text, "done": done}),
      );
      print('Update progress response: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updatedSteps = data['progress'] ?? [];
        safeSetState(() {
          _progressSteps = updatedSteps;
          _allStepsDone = updatedSteps.every((step) => step["done"] == true);
        });
      } else {
        showSnackBar(context, "Failed to update progress");
      }
    } catch (_) {
      showSnackBar(context, "Error updating progress");
    }
  }

  Future<void> _handleAction(bool accept) async {
    if (_token == null) return;
    safeSetState(() => _loading = true);
    try {
      final userId = ref.read(userIdProvider);
      final response = await http.post(
        Uri.parse("$url/user/acceptoffer"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_token",
        },
        body: jsonEncode({
          "requestId": widget.requestId,
          "userId": userId,
          "role": widget.role.toLowerCase(),
          "accept": accept,
        }),
      );
      if (response.statusCode == 200) {
        if (accept) await _fetchProgress();
        widget.onActionCompleted(widget.requestId);
      } else {
        showSnackBar(context, "Failed to update action");
      }
    } catch (_) {
      showSnackBar(context, "Error performing action");
    } finally {
      safeSetState(() => _loading = false);
    }
  }

  Future<void> _submitReview() async {
    if (_token == null) return;
    if (_reviewRating == 0 || _reviewController.text.trim().isEmpty) {
      showSnackBar(context, "Please fill both rating and review");
      return;
    }
    safeSetState(() => _reviewSubmitting = true);
    try {
      final userId = ref.read(userIdProvider);
      final response = await http.put(
        Uri.parse("$url/user/vendorrequest/${widget.requestId}/review"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_token",
        },
        body: jsonEncode({
          "userId": userId,
          "message": _reviewController.text.trim(),
          "rating": _reviewRating,
        }),
      );
      if (response.statusCode == 200) {
        showSnackBar(
          context,
          "Review submitted successfully!",
          color: Colors.green,
        );
        _reviewController.clear();
        safeSetState(() {
          _reviewRating = 0.0;
          _reviewSubmitted = true;
        });
      } else {
        showSnackBar(context, "Failed to submit review");
      }
    } catch (_) {
      showSnackBar(context, "Error submitting review");
    } finally {
      safeSetState(() => _reviewSubmitting = false);
    }
  }

  Future<void> _checkReviewStatus() async {
    if (_token == null) return;
    try {
      final userId = ref.read(userIdProvider);
      final response = await http.get(
        Uri.parse(
          "$url/user/vendorrequest/${widget.requestId}/reviewstatus?userId=$userId",
        ),
        headers: {
          "Authorization": "Bearer $_token",
          "Content-Type": "application/json",
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        safeSetState(() => _reviewSubmitted = data["reviewSubmitted"] ?? false);
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadToken().then((_) {
      if (widget.userStatus.toLowerCase() == "accepted") _fetchProgress();
      _checkReviewStatus();
    });
    Future(() => ref.read(setIndexProvider.notifier).state = 5);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFFFF4B7D),
                    size: 50,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Your Booking is confirmed!",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "You're all set for your event.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Here are the details:",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[500]!),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.02,
                vertical: size.height * 0.015,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Vendor",
                          style: TextStyle(fontSize: size.width * 0.04),
                        ),
                        Text(
                          widget.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: size.width * 0.05,
                          ),
                        ),
                        Text(
                          '${widget.role[0].toUpperCase()}${widget.role.substring(1)}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[200],
                    child: const Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: size.height * 0.02),
            Text(
              "Booking Details",
              style: TextStyle(
                fontSize: size.width * 0.06,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: size.height * 0.015),
            detailRow("Event", widget.description),
            detailRow("Budget", "₹${widget.budget}"),
            if (widget.startDate != null && widget.endDate != null)
              Builder(
                builder: (context) {
                  final formatted = formatDateAndTime(
                    widget.startDate!,
                    widget.endDate!,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      detailRow("Date", formatted["date"]!),
                      detailRow("Time", formatted["time"]!),
                    ],
                  );
                },
              ),
            detailRow("Booking ID", widget.requestId),
            _locationRow(widget.location),
            const SizedBox(height: 16),
            if (!widget.actionCompleted &&
                widget.userStatus.toLowerCase() == "pending")
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _actionButton(
                          "Reject",
                          Colors.grey[300]!,
                          Colors.black,
                          () => _handleAction(false),
                        ),
                        _actionButton(
                          "Accept",
                          const Color(0xFFFF4B7D),
                          Colors.white,
                          () => _handleAction(true),
                        ),
                      ],
                    ),
            const SizedBox(height: 20),
            if (widget.userStatus.toLowerCase() == "accepted")
              _progressLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildProgressTimeline(),
            if (_allStepsDone && !_reviewSubmitted)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(thickness: 1.2),
                  const Text(
                    "Write A Review",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildStarRating(),
                  TextField(
                    controller: _reviewController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Write your review...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _reviewSubmitting
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitReview,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF4B7D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Submit Review",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                ],
              )
            else if (_reviewSubmitted)
              const Column(
                children: [
                  Divider(thickness: 1.2),
                  Center(
                    child: Text(
                      "Review already submitted ✅",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
    String text,
    Color bgColor,
    Color fgColor,
    VoidCallback onPressed,
  ) => ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Text(text, style: TextStyle(color: fgColor)),
  );

  Widget _buildProgressTimeline() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(thickness: 1.2),
      const Text(
        "Booking Status",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      Column(
        children: _progressSteps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isDone = step["done"] == true;
          final isLast = index == _progressSteps.length - 1;
          IconData stepIcon;
          switch (index) {
            case 0:
              stepIcon = Icons.event_available_outlined;
              break;
            case 1:
              stepIcon = Icons.directions_walk_outlined;
              break;
            case 2:
              stepIcon = Icons.celebration_outlined;
              break;
            default:
              stepIcon = Icons.radio_button_unchecked;
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFFFF4B7D)
                          : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDone ? Icons.check : stepIcon,
                      size: 28,
                      color: isDone ? Colors.white : const Color(0xFFFF4B7D),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 3,
                      height: 45,
                      color: isDone
                          ? const Color(0xFFFF4B7D)
                          : Colors.grey.shade300,
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: () => _updateProgress(step["text"], !isDone),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      step["text"],
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isDone ? Colors.black : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    ],
  );

  Widget _buildStarRating() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      5,
      (index) => IconButton(
        icon: Icon(
          index < _reviewRating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 30,
        ),
        onPressed: () =>
            safeSetState(() => _reviewRating = (index + 1).toDouble()),
      ),
    ),
  );
}
