import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class CustomLoadingIndicator extends StatelessWidget {
  final double? width;
  final double? height;

  const CustomLoadingIndicator({super.key, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      'assets/src/loading.json',
      width: width ?? 150,
      height: height ?? 150,
      fit: BoxFit.contain,
    );
  }
}
