import 'package:app/utils/date_utils.dart';
import 'package:app/utils/detail_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class VendorBookingDetailCard extends ConsumerStatefulWidget {
  final String requestId;
  final String userName;
  final String userEmail;
  final String budget;
  final String description;
  final String role;
  final dynamic location;
  final String? startDateTime;
  final String? endDateTime;
  final ScrollController scrollController;
  final double? rating;
  final String? ratingMessage;

  const VendorBookingDetailCard({
    super.key,
    required this.requestId,
    required this.userName,
    required this.userEmail,
    required this.budget,
    required this.description,
    required this.role,
    this.location,
    this.startDateTime,
    this.endDateTime,
    required this.scrollController,
    this.rating,
    this.ratingMessage,
  });

  @override
  ConsumerState<VendorBookingDetailCard> createState() =>
      _VendorBookingDetailCardState();
}

class _VendorBookingDetailCardState
    extends ConsumerState<VendorBookingDetailCard> {
  Widget _locationRow(Map<String, dynamic>? location) {
    final coords = location?["coordinates"];
    if (coords == null || coords.length != 2) {
      return detailRow("Location", "Not available");
    }
    final longitude = coords[0];
    final latitude = coords[1];
    final url = "https://www.google.com/maps?q=$latitude,$longitude";
    return Column(
      children: [
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Location",
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
            ),
            GestureDetector(
              onTap: () async {
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              child: Text(
                "${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}",
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    print(widget.startDateTime);
    print(widget.endDateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Booking Confirmed 🎉",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Here are your client details:",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            detailRow("Client Name", widget.userName),
            detailRow("Client Email", widget.userEmail),
            detailRow("Role", widget.role),
            detailRow("Budget", "₹${widget.budget}"),
            if (widget.startDateTime != null)
              Builder(
                builder: (_) {
                  final dt = widget.endDateTime != null
                      ? formatDateAndTime(
                          widget.startDateTime!,
                          widget.endDateTime!,
                        )
                      : {
                          "date": DateFormat('dd/MM/yy').format(
                            DateTime.parse(widget.startDateTime!).toLocal(),
                          ),
                          "time": DateFormat('h:mm a').format(
                            DateTime.parse(widget.startDateTime!).toLocal(),
                          ),
                        };
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      detailRow("Event Date", dt['date']!),
                      detailRow("Event Time", dt['time']!),
                    ],
                  );
                },
              )
            else
              detailRow("Event Date", "—"),
            _locationRow(widget.location),
            const SizedBox(height: 16),
            const Divider(),
            if ((widget.rating ?? 0) != 0) ...[
              const SizedBox(height: 12),
              const Text(
                "Client Rating",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.star, color: Colors.amber[600]),
                  const SizedBox(width: 6),
                  Text(
                    widget.rating!.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (widget.ratingMessage != null &&
                  widget.ratingMessage!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '"${widget.ratingMessage!}"',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
