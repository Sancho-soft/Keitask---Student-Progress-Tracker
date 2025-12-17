import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final bool isPassword;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: widget.isPassword ? _obscureText : false,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        hintText: widget.hint,
        hintStyle: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[400]
              : Colors.grey[600],
        ),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF393E46)
            : const Color(0xFFF5F6F8), // Adaptive fill color
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16, // Taller input area
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Rounded corners
          borderSide: BorderSide(
            color: Colors.grey.shade300, // Lighter border
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.blue,
            width: 1.5,
          ), // Blue glow on focus
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              )
            : widget.suffixIcon,
      ),
    );
  }
}
