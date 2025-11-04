import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

Future<void> launchDialer(BuildContext context, String phoneNumber) async {
  final Uri url = Uri(scheme: 'tel', path: phoneNumber);
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Could not open dialer")),
    );
  }
}