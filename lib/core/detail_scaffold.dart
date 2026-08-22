import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DetailScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const DetailScaffold({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: SvgPicture.asset('assets/icons/arrow-back.svg'),
          onPressed: () => context.pop(),
        ),
      ),
      body: child,
    );
  }
}
