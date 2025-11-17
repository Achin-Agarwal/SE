import 'package:flutter/material.dart';

class IGZoomImage extends StatefulWidget {
  final String imageUrl;
  final String tag;

  const IGZoomImage({super.key, required this.imageUrl, required this.tag});

  @override
  State<IGZoomImage> createState() => _IGZoomImageState();
}

class _IGZoomImageState extends State<IGZoomImage> {
  final TransformationController _controller = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: () {
        final pos = _doubleTapDetails!.localPosition;
        final zoomed = Matrix4.identity()
          ..translate(-pos.dx * 2, -pos.dy * 2)
          ..scale(3.0);

        _controller.value = _controller.value.isIdentity()
            ? zoomed
            : Matrix4.identity();
      },
      child: Container(
        color: Colors.black,
        child: Center(
          child: Hero(
            tag: widget.tag,
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 1,
              maxScale: 4,
              clipBehavior: Clip.none,
              child: Image.network(
                widget.imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const CircularProgressIndicator(color: Colors.white);
                },
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.person, color: Colors.white, size: 120),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
