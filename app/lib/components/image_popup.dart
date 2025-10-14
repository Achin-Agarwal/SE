import 'package:flutter/material.dart';

class ImagePopup extends StatelessWidget {
  final String imagePath;
  final VoidCallback onClose;

  const ImagePopup({
    super.key,
    required this.imagePath,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9),
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: imagePath,
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 1,
                maxScale: 4,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
