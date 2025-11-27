import 'package:flutter/material.dart';

typedef DateRangeResult = ({String? start, String? end});

class DatePickerSheet {
  static Future<DateRangeResult?> show(BuildContext context) async {
    return await showModalBottomSheet<DateRangeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
  DateTime? singleDate;
  DateTimeRange? range;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "Select Date",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0B1E3A),
              ),
            ),

            const SizedBox(height: 18),

            // SINGLE DAY PICKER BUTTON
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.deepPurple),
              title: const Text("Pick a single day"),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );

                if (picked != null) {
                  Navigator.pop(context,
                      (start: picked.toIso8601String().split("T")[0], end: picked.toIso8601String().split("T")[0]));
                }
              },
            ),

            // RANGE PICKER
            ListTile(
              leading: const Icon(Icons.date_range, color: Colors.deepPurple),
              title: const Text("Pick a date range"),
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
                  Navigator.pop(context,
                      (start: picked.start.toIso8601String().split("T")[0],
                      end: picked.end.toIso8601String().split("T")[0]));
                }
              },
            ),

            // CLEAR DATES
            ListTile(
              leading: const Icon(Icons.clear, color: Colors.red),
              title: const Text("Clear dates"),
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