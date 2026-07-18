import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget formContent;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.formContent,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            children: [
              /// A bit of less space on top so the form
              /// looks more in center, real center looks
              /// a bit weird (human eye stuff)
              const Spacer(flex: 3),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    SvgPicture.asset(
                      'assets/images/logo-light.svg',
                      width: 128,
                      height: 128,
                    ),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(subtitle),
                    const SizedBox(height: 24),
                    formContent,
                  ],
                ),
              ),
              const Spacer(flex: 5),
            ],
          ),
        ),
      ),
    );
  }
}
