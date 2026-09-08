import 'package:flutter/material.dart';

import '../../theme/lovespace_theme.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LoveMark(size: 76),
            SizedBox(height: 24),
            CircularProgressIndicator(color: LoveSpaceColors.rose),
            SizedBox(height: 14),
            Text('正在回到我们的空间…'),
          ],
        ),
      ),
    );
  }
}

class _LoveMark extends StatelessWidget {
  const _LoveMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(size * .32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1FBE185D),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Icon(
        Icons.favorite_rounded,
        size: size * .52,
        color: LoveSpaceColors.rose,
      ),
    );
  }
}
