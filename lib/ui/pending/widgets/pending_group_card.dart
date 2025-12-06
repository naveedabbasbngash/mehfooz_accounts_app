import 'package:flutter/material.dart';
import '../../../model/pending_group_row.dart';

class PendingGroupCard extends StatefulWidget {
  final PendingGroupRow row;
  final String highlight;

  /// SELECTION SYSTEM
  final bool selectionMode;          // parent enables selection mode
  final bool isSelected;             // is this card selected?
  final VoidCallback? onSelectionToggle; // toggle selection
  final VoidCallback? onLongPressToSelect; // long press starts selection

  const PendingGroupCard({
    super.key,
    required this.row,
    this.highlight = "",
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectionToggle,
    this.onLongPressToSelect,
  });

  @override
  State<PendingGroupCard> createState() => _PendingGroupCardState();
}

class _PendingGroupCardState extends State<PendingGroupCard> {
  bool expanded = true;

  // ============================================================
  // Highlight text logic
  // ============================================================
  TextSpan _hl(String text, String query, TextStyle normal, TextStyle bold) {
    if (query.isEmpty) return TextSpan(text: text, style: normal);

    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final index = lower.indexOf(q);

    if (index == -1) return TextSpan(text: text, style: normal);

    return TextSpan(children: [
      TextSpan(text: text.substring(0, index), style: normal),
      TextSpan(text: text.substring(index, index + q.length), style: bold),
      TextSpan(text: text.substring(index + q.length), style: normal),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final highlight = widget.highlight.trim();
    final isNegative = row.balance < 0;

    return GestureDetector(
      onTap: () {
        if (widget.selectionMode && widget.onSelectionToggle != null) {
          widget.onSelectionToggle!();
        } else {
          setState(() => expanded = !expanded);
        }
      },

      onLongPress: () {
        if (widget.onLongPressToSelect != null) {
          widget.onLongPressToSelect!();
        } else if (widget.onSelectionToggle != null) {
          widget.onSelectionToggle!();
        }
      },

      child: Stack(
        children: [
          // =====================================================
          // CARD VIEW (unchanged)
          // =====================================================
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: expanded
                ? _expandedView(row, isNegative, highlight)
                : _collapsedView(row, isNegative, highlight),
          ),

          // =====================================================
          // SELECTION DOT (Gmail Style)
          // =====================================================
          if (widget.selectionMode)
            Positioned(
              top: 12,
              right: 12,
              child: _selectionDot(widget.isSelected),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // SELECTION DOT
  // ============================================================
  Widget _selectionDot(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? Colors.deepPurple : Colors.white,
        border: Border.all(
          color: selected ? Colors.deepPurple : Colors.grey.shade400,
          width: 2,
        ),
        boxShadow: selected
            ? [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ]
            : null,
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }

  // ============================================================
  // COLLAPSED VIEW (unchanged)
  // ============================================================
  Widget _collapsedView(
      PendingGroupRow row, bool isNegative, String highlight) {
    final normal = const TextStyle(color: Colors.black87, fontSize: 14);
    final bold =
    const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(text: _hl(row.beginDate, highlight, normal, bold)),
                if (row.pd?.isNotEmpty ?? false)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.deepPurple.shade100),
                    ),
                    child: RichText(
                      text: _hl(
                          "PD: ${row.pd!}",
                          highlight,
                          const TextStyle(color: Colors.deepPurple, fontSize: 11),
                          const TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 11)),
                    ),
                  ),
              ],
            ),
            const Spacer(),

            if (row.accTypeName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: RichText(
                  text: _hl(
                    row.accTypeName!,
                    highlight,
                    const TextStyle(
                        color: Colors.deepPurple, fontSize: 13, fontWeight: FontWeight.w700),
                    const TextStyle(
                        color: Colors.deepPurple, fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
              ),

            const SizedBox(width: 12),

            RichText(
              text: _hl(
                row.balance.toString(),
                highlight,
                TextStyle(
                  color: isNegative ? Colors.red : Colors.green.shade700,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
                TextStyle(
                  color: isNegative ? Colors.red : Colors.deepPurple,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            const Text("S: ",
                style:
                TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            Expanded(
              child: RichText(
                text: _hl(row.sender ?? "—", highlight, normal, bold),
              ),
            ),
            const SizedBox(width: 16),
            const Text("R: ",
                style:
                TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            Expanded(
              child: RichText(
                text: _hl(row.receiver ?? "—", highlight, normal, bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // EXPANDED VIEW (unchanged)
  // ============================================================
  Widget _expandedView(
      PendingGroupRow row, bool isNegative, String highlight) {
    final normal = const TextStyle(color: Colors.black87, fontSize: 14);
    final bold =
    const TextStyle(color: Colors.deepPurple, fontSize: 14, fontWeight: FontWeight.bold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date + balances
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: _hl(
                    row.beginDate,
                    highlight,
                    const TextStyle(
                        color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 14),
                    bold,
                  ),
                ),

                if (row.pd?.isNotEmpty ?? false)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.deepPurple.shade200),
                    ),
                    child: RichText(
                      text: _hl(
                        "PD: ${row.pd!}",
                        highlight,
                        const TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                        const TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const Spacer(),

            if (row.accTypeName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: RichText(
                  text: _hl(
                    row.accTypeName!,
                    highlight,
                    const TextStyle(
                        color: Colors.deepPurple, fontSize: 13, fontWeight: FontWeight.w700),
                    const TextStyle(
                        color: Colors.deepPurple, fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
              ),

            const SizedBox(width: 10),

            RichText(
              text: _hl(
                row.balance.toString(),
                highlight,
                TextStyle(
                    color: isNegative ? Colors.red : Colors.green.shade700,
                    fontWeight: FontWeight.w900,
                    fontSize: 20),
                TextStyle(
                    color: isNegative ? Colors.red : Colors.deepPurple,
                    fontWeight: FontWeight.w900,
                    fontSize: 20),
              ),
            ),
          ],
        ),

        if (row.msgNo?.isNotEmpty ?? false) ...[
          const SizedBox(height: 6),
          RichText(
            text: _hl(
              "Msg: ${row.msgNo}",
              highlight,
              TextStyle(color: Colors.grey.shade600),
              const TextStyle(
                  color: Colors.deepPurple, fontWeight: FontWeight.bold),
            ),
          ),
        ],

        const SizedBox(height: 16),

        _infoLine("Sender", row.sender ?? "—", highlight),
        const SizedBox(height: 8),
        _infoLine("Receiver", row.receiver ?? "—", highlight),

        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _pill("P.Amount", row.notPaidAmount.toString(), highlight),
              _pill("Paid", row.paidAmount.toString(), highlight),
              _pill("Balance", row.balance.toString(), highlight, bold: true),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Helper: info line
  // ============================================================
  Widget _infoLine(String label, String value, String highlight) {
    return Row(
      children: [
        Text(
          "$label: ",
          style: const TextStyle(
              color: Colors.deepPurple, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: RichText(
            text: _hl(
              value,
              highlight,
              const TextStyle(color: Colors.black87),
              const TextStyle(
                color: Colors.deepPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Helper: amount pill
  // ============================================================
  Widget _pill(String label, String value, String highlight,
      {bool bold = false}) {
    final normal =
    TextStyle(color: Colors.deepPurple, fontSize: bold ? 18 : 16);
    final boldStyle = TextStyle(
        color: Colors.deepPurple,
        fontSize: bold ? 18 : 16,
        fontWeight: FontWeight.bold);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 4),
          RichText(text: _hl(value, highlight, normal, boldStyle)),
        ],
      ),
    );
  }
}