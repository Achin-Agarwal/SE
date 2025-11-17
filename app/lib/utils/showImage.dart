import 'package:flutter/material.dart';

void showImagePreview(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Material(
          color: Colors.black.withOpacity(0.85),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // prevent closing on image tap
              child: Hero(
                tag: imageUrl,
                child: ZoomableImage(imageUrl: imageUrl),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ZoomableImage extends StatefulWidget {
  final String imageUrl;
  const ZoomableImage({super.key, required this.imageUrl});

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage> {
  final TransformationController _controller = TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool _isLoading = true;

  void _finishLoading() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: () {
        if (_controller.value != Matrix4.identity()) {
          _controller.value = Matrix4.identity();
        } else {
          final position = _doubleTapDetails!.localPosition;
          _controller.value = Matrix4.identity()
            ..translate(-position.dx * 1.5, -position.dy * 1.5)
            ..scale(2.5);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InteractiveViewer(
          transformationController: _controller,
          minScale: 1,
          maxScale: 4,
          panEnabled: true,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isLoading)
                const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),

              Image.network(
                widget.imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    _finishLoading();  // <- safe setState
                    return child;
                  }
                  return const SizedBox.shrink();
                },
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 100,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
