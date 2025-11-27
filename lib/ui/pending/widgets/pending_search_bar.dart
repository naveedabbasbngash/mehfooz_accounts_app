import 'package:flutter/material.dart';

class PendingSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const PendingSearchBar({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
          hintText: "Search pending entries...",
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.deepPurple.shade100),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.deepPurple.shade100),
          ),
        ),
      ),
    );
  }
}