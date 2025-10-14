import 'package:flutter/material.dart';
import 'package:app/components/image_popup.dart';

class VendorDetailCard extends StatelessWidget {
  final Map<String, dynamic> vendor;
  final VoidCallback onClose;

  const VendorDetailCard({
    super.key,
    required this.vendor,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final List<String> images = [
      'assets/1.png',
      'assets/2.png',
      'assets/3.png',
      'assets/4.png',
      'assets/5.png',
      'assets/6.png',
      'assets/7.png',
    ];

    void openImage(String imagePath) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Image',
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => ImagePopup(
          imagePath: imagePath,
          onClose: () => Navigator.of(context).pop(),
        ),
        transitionBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
            child: child,
          );
        },
      );
    }

    // return Container(
    //   width: double.infinity,
    //   margin: EdgeInsets.symmetric(
    //     horizontal: size.width * 0.04,
    //     vertical: size.height * 0.015,
    //   ),
    //   decoration: BoxDecoration(
    //     color: Colors.white,
    //     borderRadius: BorderRadius.circular(20),
    //     boxShadow: [
    //       BoxShadow(
    //         color: Colors.black.withOpacity(0.08),
    //         blurRadius: 12,
    //         offset: const Offset(0, 6),
    //       ),
    //     ],
    //   ),
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.045,
        vertical: size.height * 0.02,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Close Button
            Align(
              alignment: Alignment.topRight,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F8F8),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, color: Colors.black54),
                  tooltip: 'Close',
                ),
              ),
            ),

            // Vendor Info Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.pink.shade100,
                  child: Text(
                    vendor["name"][0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                SizedBox(width: size.width * 0.05),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendor["name"],
                        style: TextStyle(
                          fontSize: size.width * 0.055,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < vendor["rating"].floor()
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: Colors.amber,
                              size: size.width * 0.045,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            vendor["rating"].toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: size.width * 0.04,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: size.height * 0.02),

            // Description
            Container(
              decoration: BoxDecoration(
                color: Colors.pink.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.all(size.width * 0.04),
              child: Text(
                vendor["description"],
                style: TextStyle(
                  fontSize: size.width * 0.038,
                  color: Colors.grey[800],
                  height: 1.4,
                ),
              ),
            ),

            SizedBox(height: size.height * 0.03),

            // Previous Work Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Previous Work",
                  style: TextStyle(
                    fontSize: size.width * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Icon(
                  Icons.photo_library_rounded,
                  color: Colors.pink.shade300,
                  size: size.width * 0.055,
                ),
              ],
            ),
            const SizedBox(height: 10),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final img = images[index];
                return GestureDetector(
                  onTap: () => openImage(img),
                  child: Hero(
                    tag: img,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(img, fit: BoxFit.cover),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.05),
                                  Colors.black.withOpacity(0.15),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      // ),
    );
  }
}
