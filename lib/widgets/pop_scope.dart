import 'package:flutter/material.dart';

/// Small helper wrapper around [WillPopScope] used by the app's navigation
/// to centralize pop handling. It calls [onPopInvokedWithResult] before
/// returning the `onWillPop` decision so the parent can react.
class PopScope extends StatelessWidget {
  final Widget child;
  final bool canPop;
  final void Function(bool didPop, dynamic result)? onPopInvokedWithResult;

  const PopScope({
    Key? key,
    required this.child,
    this.canPop = true,
    this.onPopInvokedWithResult,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final willPop = canPop;
        try {
          onPopInvokedWithResult?.call(willPop, null);
        } catch (_) {}
        return willPop;
      },
      child: child,
    );
  }
}
