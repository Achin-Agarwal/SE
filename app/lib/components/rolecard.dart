import 'package:flutter/material.dart';

class RoleCard extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const RoleCard({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size.width * 0.9,
        padding: EdgeInsets.symmetric(
          vertical: size.height * 0.015,
          horizontal: size.width * 0.04,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.pink[50],
              child: Icon(
                icon ?? Icons.work_outline,
                color: Colors.pink,
                size: 26,
              ),
            ),
            SizedBox(width: size.width * 0.05),
            Text(
              label,
              style: TextStyle(
                fontSize: size.width * 0.055,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
