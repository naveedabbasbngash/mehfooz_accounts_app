import 'package:flutter/material.dart';
import 'package:mehfooz_accounts_app/ui/pending/widgets/pending_group_card.dart';
import '../../../model/pending_group_row.dart';

class PendingGroupList extends StatelessWidget {
  final List<PendingGroupRow> rows;
  final String highlight;

  // NEW:
  final bool selectionMode;
  final Set<PendingGroupRow> selectedRows;
  final void Function(PendingGroupRow row)? onToggleSelection;
  final void Function(PendingGroupRow row)? onLongPressToSelect;

  const PendingGroupList({
    super.key,
    required this.rows,
    this.highlight = "",
    this.selectionMode = false,
    this.selectedRows = const {},
    this.onToggleSelection,
    this.onLongPressToSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text(
            "No Pending Amount found",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 60),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];

        return _AnimatedItem(
          delayMs: index * 40,
          child: PendingGroupCard(
            row: row,
            highlight: highlight,
            selectionMode: selectionMode,
            isSelected: selectedRows.contains(row),
            onSelectionToggle: onToggleSelection == null
                ? null
                : () => onToggleSelection!(row),
            onLongPressToSelect: onLongPressToSelect == null
                ? null
                : () => onLongPressToSelect!(row),
          ),
        );
      },
    );
  }
}

// same _AnimatedItem as you already had (unchanged)
class _AnimatedItem extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const _AnimatedItem({
    required this.child,
    required this.delayMs,
  });

  @override
  State<_AnimatedItem> createState() => _AnimatedItemState();
}

class _AnimatedItemState extends State<_AnimatedItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}