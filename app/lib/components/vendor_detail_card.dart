import 'package:flutter/material.dart';

class VendorDetailCard extends StatelessWidget {
  final String name;
  final double rating;
  final String description;
  final String budget;
  final VoidCallback onClose;

  const VendorDetailCard({
    super.key,
    required this.name,
    required this.rating,
    required this.description,
    required this.budget,
    required this.onClose,
  });

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
            // Header row with avatar + name + actions
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
                        name,
                        style: TextStyle(
                          fontSize: size.width * 0.05,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star,
                              color: Colors.amber, size: size.width * 0.04),
                          SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
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
                  onPressed: onClose,
                ),
              ],
            ),

            SizedBox(height: size.height * 0.015),
            Text(
              "Budget: $budget",
              style: TextStyle(
                fontSize: size.width * 0.04,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),

            SizedBox(height: size.height * 0.015),
            Text(
              description,
              style: TextStyle(
                fontSize: size.width * 0.037,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),

            SizedBox(height: size.height * 0.02),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
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
                    onPressed: () {},
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
