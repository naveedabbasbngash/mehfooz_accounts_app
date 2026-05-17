import 'package:flutter/material.dart';

const _kTxBrandBlue = Color(0xFF1862A3);

class TxSearchBar extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final List<String> suggestions;
  final VoidCallback? onFocus;     // NEW — close details panel

  const TxSearchBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.suggestions = const [],
    this.onFocus,
  });

  @override
  Widget build(BuildContext context) {
    return _TxAutoSearch(
      value: value,
      onChanged: onChanged,
      suggestions: suggestions,
      onFocus: onFocus,         // pass down
    );
  }
}

class _TxAutoSearch extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final List<String> suggestions;
  final VoidCallback? onFocus;   // NEW

  const _TxAutoSearch({
    required this.value,
    required this.onChanged,
    required this.suggestions,
    this.onFocus,
  });

  @override
  State<_TxAutoSearch> createState() => _TxAutoSearchState();
}

class _TxAutoSearchState extends State<_TxAutoSearch> {
  late TextEditingController controller;

  @override
  void initState() {
    controller = TextEditingController(text: widget.value);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _TxAutoSearch oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Do NOT override user typing
    if (controller.text != widget.value &&
        !controller.selection.isValid) {
      controller.text = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue input) {
        final query = input.text.trim();
        if (query.isEmpty) return const Iterable<String>.empty();

        return widget.suggestions.where(
              (s) => s.toLowerCase().contains(query.toLowerCase()),
        );
      },

      displayStringForOption: (option) => option,

      fieldViewBuilder: (context, textController, focusNode, onSubmit) {
        controller = textController;

        return TextField(
          controller: controller,
          focusNode: focusNode,
          onTap: () {
            if (widget.onFocus != null) widget.onFocus!();   // ← CLOSE PANEL
          },
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: "Search person…",
            hintStyle: const TextStyle(
              color: Color(0xFF7B91A8),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(Icons.search_rounded, color: _kTxBrandBlue),
            suffixIcon: controller.text.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      controller.clear();
                      widget.onChanged('');
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF6C7D90),
                    ),
                  ),
            filled: true,
            fillColor: const Color(0xFFF8FBFF),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(
                color: _kTxBrandBlue.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(color: _kTxBrandBlue, width: 1.2),
            ),
          ),
        );
      },

      optionsViewBuilder: (context, onSelected, options) {
        final query = controller.text;

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            elevation: 8,
            borderRadius: BorderRadius.circular(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _kTxBrandBlue.withValues(alpha: 0.12),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x141862A3),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: options.length,
                  itemBuilder: (ctx, i) {
                    final option = options.elementAt(i);

                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: RichText(
                          text: _highlight(option, query),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },

      onSelected: (option) {
        controller.text = option;
        widget.onChanged(option);
      },
    );
  }

  // ---------------------------------------------------
  // 🔥 Bold highlight logic
  // ---------------------------------------------------
  TextSpan _highlight(String text, String query) {
    if (query.isEmpty) {
      return const TextSpan(
        text: "",
        style: TextStyle(fontSize: 15, color: Color(0xFF0B1E3A)),
      );
    }

    final lower = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final start = lower.indexOf(lowerQuery);

    if (start < 0) {
      return TextSpan(
        text: text,
        style: const TextStyle(fontSize: 15, color: Color(0xFF0B1E3A)),
      );
    }

    return TextSpan(
      children: [
        TextSpan(
          text: text.substring(0, start),
          style: const TextStyle(fontSize: 15, color: Color(0xFF0B1E3A)),
        ),
        TextSpan(
          text: text.substring(start, start + query.length),
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF0B1E3A),
            fontWeight: FontWeight.bold,
          ),
        ),
        TextSpan(
          text: text.substring(start + query.length),
          style: const TextStyle(fontSize: 15, color: Color(0xFF0B1E3A)),
        ),
      ],
    );
  }
}
