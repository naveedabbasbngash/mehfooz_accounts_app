import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/reports/last_credit_view_model.dart';
import '../../services/pdf/open_file_service.dart';

class LastCreditSummaryScreen extends StatefulWidget {
  const LastCreditSummaryScreen({super.key});

  @override
  State<LastCreditSummaryScreen> createState() =>
      _LastCreditSummaryScreenState();
}

class _LastCreditSummaryScreenState extends State<LastCreditSummaryScreen> {
  String? _selectedCurrency;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    // Load currencies after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<LastCreditViewModel>();
      vm.loadCurrencies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LastCreditViewModel>();

    const softBg = Color(0xFFF7F9FC);
    const deepBlue = Color(0xFF0B1E3A);

    final currencies = vm.currencies;

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        backgroundColor: softBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: deepBlue),
        title: const Text(
          'Last Credit Summary',
          style: TextStyle(
            color: deepBlue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: vm.isLoading && currencies.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select currency to view its Credit Summary',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Currency dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              value: _selectedCurrency,
              items: currencies
                  .map(
                    (c) => DropdownMenuItem<String>(
                  value: c,
                  child: Text(c),
                ),
              )
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCurrency = val;
                });
              },
            ),
            const SizedBox(height: 24),

            // Show button
            ElevatedButton(
              onPressed: _isGenerating
                  ? null
                  : () async {
                final cur = _selectedCurrency;
                if (cur == null || cur.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a currency'),
                    ),
                  );
                  return;
                }

                setState(() => _isGenerating = true);
                try {
                  final File? file = await vm.generatePdf(
                    currencyName: cur.trim(),
                  );

                  if (file == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'No data found for this currency'),
                      ),
                    );
                    return;
                  }

                  OpenFileService.openPdf(context, file);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                    ),
                  );
                } finally {
                  if (mounted) {
                    setState(() => _isGenerating = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: deepBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isGenerating
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text(
                'Show',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            if (vm.error != null) ...[
              const SizedBox(height: 8),
              Text(
                '⚠ ${vm.error}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}