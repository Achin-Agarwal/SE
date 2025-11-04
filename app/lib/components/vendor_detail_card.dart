import 'dart:convert';
import 'package:app/url.dart';
import 'package:app/utils/launch_dialer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:app/providers/userid.dart';

class VendorDetailCard extends ConsumerStatefulWidget {
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
  final String? phone;

  const VendorDetailCard({
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
    this.phone,
  });

  @override
  ConsumerState<VendorDetailCard> createState() => _VendorDetailCardState();
}

class _VendorDetailCardState extends ConsumerState<VendorDetailCard> {
  bool _loading = false;

  Future<void> _handleAction(bool accept) async {
    setState(() => _loading = true);

    try {
      final userId = ref.read(userIdProvider);

      final response = await http.post(
        Uri.parse("$url/user/acceptoffer"),
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
            if (widget.phone != null && widget.phone!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: GestureDetector(
                  onTap: () => launchDialer(context, widget.phone!),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone, color: Colors.green, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        widget.phone!,
                        style: TextStyle(
                          fontSize: size.width * 0.04,
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Text(
              widget.description,
              style: TextStyle(
                fontSize: size.width * 0.037,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            SizedBox(height: size.height * 0.02),

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
          ],
        ),
      ),
    );
  }
}
