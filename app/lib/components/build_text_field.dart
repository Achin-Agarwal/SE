import 'package:flutter/material.dart';

Widget buildTextFieldContainer({
  required IconData icon,
  required String hintText,
  required Color iconColor,
  required Color textColor,
  required Color backgroundColor,
  bool obscureText = false,
  Widget? suffixIcon,
  required TextEditingController controller,
}) {
  return Container(
    width: 300,
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(25),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(2, 2)),
      ],
    ),
    child: Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
            ),
          ),
        ),
        if (suffixIcon != null) suffixIcon,
      ],
    ),
  );
}
