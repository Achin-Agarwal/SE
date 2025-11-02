import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:app/providers/userid.dart';

class BookingDetailCard extends ConsumerStatefulWidget {
  final String name;
  final double rating;
  final String description;
  final String budget;
  final VoidCallback onClose;
  final String requestId;
  final String role;
  final String userStatus;
  final bool actionCompleted;
  final Function(String) onActionCompleted;

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
  });

  @override
  ConsumerState<BookingDetailCard> createState() => _VendorDetailCardState();
}

class _VendorDetailCardState extends ConsumerState<BookingDetailCard> {
  bool _loading = false;
  bool _progressLoading = true;
  List<dynamic> _progressSteps = [];

  Future<void> _fetchProgress() async {
    try {
      final response = await http.get(
        Uri.parse(
          "https://achin-se-9kiip.ondigitalocean.app/vendorrequest/${widget.requestId}/progress",
        ),
      );

      if (response.statusCode == 200) {
        setState(() {
          _progressSteps = jsonDecode(response.body);
          _progressLoading = false;
        });
      } else {
        setState(() => _progressLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to load progress")));
      }
    } catch (e) {
      setState(() => _progressLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading progress: $e")));
    }
  }

  Future<void> _updateProgress(String text, bool done) async {
    try {
      final response = await http.put(
        Uri.parse(
          "https://achin-se-9kiip.ondigitalocean.app/vendorrequest/${widget.requestId}/progress",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": text, "done": done}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _progressSteps = data['progress']);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to update progress")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error updating progress: $e")));
    }
  }

  Future<void> _handleAction(bool accept) async {
    setState(() => _loading = true);

    try {
      final userId = ref.read(userIdProvider);

      final response = await http.post(
        Uri.parse("https://achin-se-9kiip.ondigitalocean.app/user/acceptoffer"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "requestId": widget.requestId,
          "userId": userId,
          "role": widget.role.toLowerCase(),
          "accept": accept,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? "Offer accepted successfully!"
                  : "Offer rejected successfully!",
            ),
          ),
        );
        widget.onActionCompleted(widget.requestId);

        // After accept, load progress tracker
        if (accept) _fetchProgress();
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
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.userStatus.toLowerCase() == "accepted") {
      _fetchProgress();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: 1,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.all(size.width * 0.04),
        padding: EdgeInsets.all(size.width * 0.045),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[300],
                  child: const Icon(Icons.store, size: 28, color: Colors.grey),
                ),
                SizedBox(width: size.width * 0.04),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: TextStyle(
                          fontSize: size.width * 0.05,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: size.width * 0.04,
                          ),
                          SizedBox(width: 4),
                          Text(
                            widget.rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: size.width * 0.035,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            SizedBox(height: size.height * 0.015),
            Text(
              "Budget: ${widget.budget}",
              style: TextStyle(
                fontSize: size.width * 0.04,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: size.height * 0.015),
            Text(
              widget.description,
              style: TextStyle(
                fontSize: size.width * 0.037,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            SizedBox(height: size.height * 0.02),

            // Action Buttons
            if (!widget.actionCompleted &&
                widget.userStatus.toLowerCase() == "pending")
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleAction(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Rejected",
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleAction(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF4B7D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Deal",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),

            // Progress Tracker
            if (widget.userStatus.toLowerCase() == "accepted")
              _progressLoading
                  ? const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(thickness: 1.2),
                        const Text(
                          "Progress Tracker",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ..._progressSteps.map(
                          (step) => CheckboxListTile(
                            title: Text(step["text"]),
                            value: step["done"],
                            onChanged: (val) =>
                                _updateProgress(step["text"], val ?? false),
                          ),
                        ),
                      ],
                    ),
          ],
        ),
      ),
    );
  }
}
