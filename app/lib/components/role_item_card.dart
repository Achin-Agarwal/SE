import 'package:flutter/material.dart';

class RoleItemCard extends StatelessWidget {
  final String name;
  final String description;
  final double rating;
  final String status;
  final Color statusColor;

  const RoleItemCard({
    super.key,
    required this.name,
    required this.description,
    required this.rating,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: size.height * 0.018),
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[300],
                child: Icon(Icons.store, color: Colors.grey[700], size: 22),
              ),
              SizedBox(width: size.width * 0.035),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: size.width * 0.045,
                      ),
                    ),
                    SizedBox(height: size.height * 0.005),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: size.width * 0.04,
                        ),
                        SizedBox(width: size.width * 0.01),
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
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.03,
                  vertical: size.height * 0.004,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: size.width * 0.032,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (status != 'Requested') ...[
            SizedBox(height: size.height * 0.012),
            Text(
              description,
              style: TextStyle(
                fontSize: size.width * 0.035,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
