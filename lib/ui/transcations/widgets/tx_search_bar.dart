// lib/ui/transactions/widgets/tx_search_bar.dart
import 'package:flutter/material.dart';

class TxSearchBar extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  /// Suggestions list (names from matching results)
  final List<String> suggestions;

  const TxSearchBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.suggestions = const [],
  });

  @override
  State<TxSearchBar> createState() => _TxSearchBarState();
}

class _TxSearchBarState extends State<TxSearchBar> {
  final FocusNode _focus = FocusNode();
  final LayerLink _layerLink = LayerLink();
  late TextEditingController controller;

  OverlayEntry? _dropdownEntry;
  bool open = false;

  @override
  void initState() {
    controller = TextEditingController(text: widget.value);

    _focus.addListener(() {
      if (_focus.hasFocus) {
        _updateDropdownState();
      } else {
        _hideDropdown();
      }
      setState(() {});
    });

    super.initState();
  }

  @override
  void didUpdateWidget(TxSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (controller.text != widget.value) {
      controller.text = widget.value;
    }

    _updateDropdownState();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --------------------------------------------------------
          // BEAUTIFUL WHITE M3 CARD SEARCH FIELD (Google Contacts style)
          // --------------------------------------------------------
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  blurRadius: 6,
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              focusNode: _focus,
              onChanged: (value) {
                widget.onChanged(value);
                _updateDropdownState();
              },
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
              cursorColor: Colors.black54,
              decoration: InputDecoration(
                hintText: "Search person…",
                hintStyle: const TextStyle(
                  color: Colors.black38,
                  fontSize: 14,
                ),
                prefixIcon:
                const Icon(Icons.search, color: Colors.black54, size: 22),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.black54, size: 20),
                  onPressed: () {
                    controller.clear();
                    widget.onChanged("");
                    _updateDropdownState(forceClose: true);
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // =========================================================
  // DROPDOWN LOGIC
  // =========================================================

  void _updateDropdownState({bool forceClose = false}) {
    final hasQuery = controller.text.isNotEmpty;
    final hasSuggestions = widget.suggestions.isNotEmpty;

    final shouldOpen =
        hasQuery && hasSuggestions && _focus.hasFocus && !forceClose;

    if (shouldOpen != open) {
      open = shouldOpen;
      if (open) {
        _showDropdown();
      } else {
        _hideDropdown();
      }
    }
  }

  void _showDropdown() {
    _hideDropdown(); // remove old one

    _dropdownEntry = OverlayEntry(
      builder: (_) => _buildDropdownOverlay(),
    );

    Overlay.of(context).insert(_dropdownEntry!);
  }

  void _hideDropdown() {
    _dropdownEntry?.remove();
    _dropdownEntry = null;
  }

  Widget _buildDropdownOverlay() {
    if (!open) return const SizedBox.shrink();

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();

    final size = renderBox.size;

    return Positioned(
      width: size.width,
      child: CompositedTransformFollower(
        link: _layerLink,
        offset: Offset(0, size.height + 8),
        showWhenUnlinked: false,
        child: _dropdownCard(),
      ),
    );
  }

  // =========================================================
  // SUGGESTIONS DROPDOWN UI — Material You Style
  // =========================================================
  Widget _dropdownCard() {
    return Material(
      elevation: 12,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          shrinkWrap: true,
          itemCount: widget.suggestions.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: Colors.grey.shade200),
          itemBuilder: (_, i) => _suggestionTile(widget.suggestions[i]),
        ),
      ),
    );
  }

  Widget _suggestionTile(String text) {
    final query = controller.text;

    return InkWell(
      onTap: () {
        controller.text = text;
        widget.onChanged(text);
        _hideDropdown();
        _focus.unfocus();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: RichText(
          text: _highlightText(text, query),
        ),
      ),
    );
  }

  // Highlighting the matching query
  TextSpan _highlightText(String full, String query) {
    if (query.isEmpty) {
      return TextSpan(text: full, style: _normal());
    }

    final index = full.toLowerCase().indexOf(query.toLowerCase());
    if (index < 0) {
      return TextSpan(text: full, style: _normal());
    }

    return TextSpan(
      children: [
        TextSpan(text: full.substring(0, index), style: _normal()),
        TextSpan(
          text: full.substring(index, index + query.length),
          style: _bold(),
        ),
        TextSpan(text: full.substring(index + query.length), style: _normal()),
      ],
    );
  }

  TextStyle _normal() =>
      const TextStyle(color: Color(0xFF0B1E3A), fontSize: 15);

  TextStyle _bold() => const TextStyle(
    color: Color(0xFF0B1E3A),
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  @override
  void dispose() {
    _hideDropdown();
    controller.dispose();
    _focus.dispose();
    super.dispose();
  }
}