import 'package:flutter/material.dart';

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

    void openImage(String imagePath, String heroTag) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: Hero(
                tag: heroTag,
                child: Image.network(imagePath, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
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
    print(vendor);
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: size.width * 0.09,
                  backgroundColor: Colors.grey[300],
                  child: ClipOval(
                    child: Image.network(
                      vendor["profileImage"] ?? "",
                      fit: BoxFit.cover,
                      width: size.width * 0.18,
                      height: size.width * 0.18,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person,
                        color: Colors.black54,
                        size: 28,
                      ),
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
            SizedBox(
              height:
                  (vendor["workImages"]?.length ?? 0) /
                  3 *
                  (size.width * 0.5 + 8),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: vendor["workImages"]?.length ?? 0,
                itemBuilder: (context, index) {
                  final img = vendor["workImages"][index];
                  return GestureDetector(
                    onTap: () => openImage(img, '${vendor["id"]}_$index'),
                    child: Hero(
                      tag: '${vendor["id"]}_$index',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              img,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                                  ),
                            ),
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
            ),
          ],
        ),
      ),
      // ),
    );
  }
}
