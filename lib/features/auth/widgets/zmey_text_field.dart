import 'package:flutter/material.dart';

class ZmeyTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool disabled;
  final bool obscureText;

  const ZmeyTextField({
    super.key,
    required this.label,
    required this.controller,
    this.disabled = false,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 5,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        TextField(
          controller: controller,
          enabled: !disabled,
          obscureText: obscureText,
          decoration: InputDecoration(
            labelText: label,
            floatingLabelBehavior: FloatingLabelBehavior.never,
          ),
        ),
      ],
    );
  }
}
