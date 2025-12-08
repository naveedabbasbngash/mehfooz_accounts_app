import 'package:flutter/material.dart';
import 'package:mehfooz_accounts_app/theme/app_colors.dart';

typedef DateRangeResult = ({String? start, String? end});

class DatePickerSheet {
  static Future<DateRangeResult?> show(BuildContext context) async {
    return await showModalBottomSheet<DateRangeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _DatePickerSheetBody(),
    );
  }
}

class _DatePickerSheetBody extends StatefulWidget {
  const _DatePickerSheetBody();

  @override
  State<_DatePickerSheetBody> createState() => _DatePickerSheetBodyState();
}

class _DatePickerSheetBodyState extends State<_DatePickerSheetBody> {
  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 22, 20, 28 + bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ──────────────────────────
            // DRAG HANDLE
            // ──────────────────────────
            Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.grey,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),

            // ──────────────────────────
            // TITLE
            // ──────────────────────────
            Text(
              "Select Date",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 18),

            // ──────────────────────────
            // SINGLE DAY PICKER
            // ──────────────────────────
            ListTile(
              leading: Icon(Icons.calendar_today, color: AppColors.primary),
              title: Text(
                "Pick a single day",
                style: TextStyle(color: AppColors.textDark),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );

                if (picked != null) {
                  final d = picked.toIso8601String().split("T")[0];
                  Navigator.pop(context, (start: d, end: d));
                }
              },
            ),

            // ──────────────────────────
            // DATE RANGE PICKER
            // ──────────────────────────
            ListTile(
              leading: Icon(Icons.date_range, color: AppColors.primary),
              title: Text(
                "Pick a date range",
                style: TextStyle(color: AppColors.textDark),
              ),
              onTap: () async {
                final now = DateTime.now();

                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  initialDateRange: DateTimeRange(
                    start: now.subtract(const Duration(days: 7)),
                    end: now,
                  ),
                );

                if (picked != null) {
                  Navigator.pop(
                    context,
                    (
                    start: picked.start.toIso8601String().split("T")[0],
                    end: picked.end.toIso8601String().split("T")[0]
                    ),
                  );
                }
              },
            ),

            // ──────────────────────────
            // CLEAR DATES
            // ──────────────────────────
            ListTile(
              leading: Icon(Icons.clear, color: AppColors.error),
              title: Text(
                "Clear dates",
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(context, (start: null, end: null));
              },
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}