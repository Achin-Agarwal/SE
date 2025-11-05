import 'package:flutter/material.dart';

class BackNavigationWrapper extends StatelessWidget {
  final bool canGoBack;
  final VoidCallback? onBack;
  final Widget child;

  const BackNavigationWrapper({
    super.key,
    required this.child,
    this.canGoBack = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (canGoBack && onBack != null) {
          onBack!();
        } else {
          Navigator.of(context).maybePop();
        }
      },
      child: child,
    );
  }
}
