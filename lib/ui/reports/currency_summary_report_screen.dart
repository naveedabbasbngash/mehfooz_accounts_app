import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:country_flags/country_flags.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../services/share/currency_summary_share_image_service.dart';
import '../../theme/app_colors.dart';
import '../../viewmodel/reports/currency_summary_report_view_model.dart';
import '../transcations/widgets/tx_search_bar.dart';

class CurrencySummaryReportScreen extends StatelessWidget {
  const CurrencySummaryReportScreen({super.key});

  static final NumberFormat _fmt = NumberFormat('#,##0.00');

  String _money(double v) {
    final safe = v.abs() < 0.005 ? 0.0 : v;
    return _fmt.format(safe);
  }

  String _currencyToCountryCode(String currency) {
    switch (currency.toUpperCase().trim()) {
      case 'PKR':
        return 'PK';
      case 'USD':
        return 'US';
      case 'AED':
        return 'AE';
      case 'SAR':
        return 'SA';
      case 'EUR':
        return 'EU';
      case 'GBP':
      case 'POUND':
        return 'GB';
      case 'INR':
      case 'IND':
        return 'IN';
      case 'AFG':
      case 'AFN':
        return 'AF';
      case 'CAD':
        return 'CA';
      case 'JPY':
        return 'JP';
      case 'RMB':
      case 'CNY':
        return 'CN';
      case 'IRR':
        return 'IR';
      case 'BHD':
        return 'BH';
      case 'OMR':
        return 'OM';
      case 'QAR':
        return 'QA';
      case 'DKK':
        return 'DK';
      case 'SEK':
        return 'SE';
      case 'NOK':
        return 'NO';
      case 'MYR':
        return 'MY';
      case 'AUD':
        return 'AU';
      case 'HKD':
        return 'HK';
      case 'SGD':
      case 'SGP':
        return 'SG';
      case 'RUB':
        return 'RU';
      default:
        return 'UN';
    }
  }

  String _countryNameForCurrency(String currency) {
    switch (currency.toUpperCase().trim()) {
      case 'PKR':
        return 'Pakistan';
      case 'USD':
        return 'United States';
      case 'AED':
        return 'United Arab Emirates';
      case 'SAR':
        return 'Saudi Arabia';
      case 'EUR':
        return 'European Union';
      case 'GBP':
      case 'POUND':
        return 'United Kingdom';
      case 'INR':
      case 'IND':
        return 'India';
      case 'AFG':
      case 'AFN':
        return 'Afghanistan';
      case 'CAD':
        return 'Canada';
      case 'JPY':
        return 'Japan';
      case 'RMB':
      case 'CNY':
        return 'China';
      case 'IRR':
        return 'Iran';
      case 'BHD':
        return 'Bahrain';
      case 'OMR':
        return 'Oman';
      case 'QAR':
        return 'Qatar';
      case 'DKK':
        return 'Denmark';
      case 'SEK':
        return 'Sweden';
      case 'NOK':
        return 'Norway';
      case 'MYR':
        return 'Malaysia';
      case 'AUD':
        return 'Australia';
      case 'HKD':
        return 'Hong Kong';
      case 'SGD':
      case 'SGP':
        return 'Singapore';
      case 'RUB':
        return 'Russia';
      default:
        return 'Unknown';
    }
  }

  bool _canExport(CurrencySummaryReportViewModel vm) {
    final base = vm.baseCurrency?.trim() ?? '';
    return base.isNotEmpty && vm.rowsForDisplay().isNotEmpty;
  }

  double _convertedTotal(CurrencySummaryReportViewModel vm) {
    return vm
        .rowsForDisplay()
        .map(
          (row) => vm.convertedToBase(
            currency: row.currency,
            amount: row.balance,
          ),
        )
        .whereType<double>()
        .fold<double>(0, (sum, v) => sum + v);
  }

  List<CurrencySummaryShareRow> _shareRows(
    CurrencySummaryReportViewModel vm,
  ) {
    return vm.rowsForDisplay().map((row) {
      final currency = row.currency.trim().isEmpty ? 'Unknown' : row.currency.trim();
      return CurrencySummaryShareRow(
        currency: currency,
        countryName: _countryNameForCurrency(currency),
        balance: row.balance,
        rate: vm.rateForCurrency(currency),
        converted: vm.convertedToBase(currency: currency, amount: row.balance),
      );
    }).toList(growable: false);
  }

  Future<void> _shareAsImage(
    BuildContext context,
    CurrencySummaryReportViewModel vm,
  ) async {
    final base = vm.baseCurrency?.trim() ?? '';
    if (base.isEmpty) return;

    final accountName = vm.search.trim().isEmpty ? 'Unknown Account' : vm.search.trim();
    final rows = _shareRows(vm);
    final total = _convertedTotal(vm);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final file = await CurrencySummaryShareImageService.instance.render(
        accountName: accountName,
        baseCurrency: base,
        rows: rows,
        total: total,
      );
      final title = 'Currency Summary • $accountName';
      await Share.shareXFiles(
        [XFile(file.path)],
        text: title,
        subject: title,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<File> _buildPdfFromImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = pw.MemoryImage(bytes);
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(10),
        build: (_) => pw.Center(
          child: pw.Image(
            image,
            fit: pw.BoxFit.contain,
          ),
        ),
      ),
    );
    final file = File(
      '${Directory.systemTemp.path}/currency_summary_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  Future<void> _exportPdf(
    BuildContext context,
    CurrencySummaryReportViewModel vm,
  ) async {
    final base = vm.baseCurrency?.trim() ?? '';
    if (base.isEmpty) return;

    final accountName = vm.search.trim().isEmpty ? 'Unknown Account' : vm.search.trim();
    final rows = _shareRows(vm);
    final total = _convertedTotal(vm);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final imageFile = await CurrencySummaryShareImageService.instance.render(
        accountName: accountName,
        baseCurrency: base,
        rows: rows,
        total: total,
      );
      final pdfFile = await _buildPdfFromImage(imageFile);
      await OpenFilex.open(pdfFile.path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e')),
        );
      }
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Widget? _buildStickyTotalBar(CurrencySummaryReportViewModel vm) {
    final base = vm.baseCurrency?.trim();
    if (base == null || base.isEmpty) {
      return null;
    }

    final rows = vm.rowsForDisplay();
    if (rows.isEmpty) {
      return null;
    }

    final convertedValues = rows
        .map(
          (row) => vm.convertedToBase(
            currency: row.currency,
            amount: row.balance,
          ),
        )
        .toList(growable: false);
    if (convertedValues.isEmpty || convertedValues.any((v) => v == null)) {
      return null;
    }

    final total = convertedValues.whereType<double>().fold<double>(
      0,
      (sum, v) => sum + v,
    );
    final totalColor = total < 0
        ? const Color(0xFFC62828)
        : const Color(0xFF2E7D32);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDCE3EE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Total "$base" Balance',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B1E3A),
                ),
              ),
            ),
            Text(
              _money(total),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: totalColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showCurrencySearchPicker(
    BuildContext context,
    List<String> currencies,
    String? selectedCurrency,
  ) async {
    String query = '';

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = currencies
                .where(
                  (c) => c.toLowerCase().contains(query.trim().toLowerCase()),
                )
                .toList(growable: false);

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  8,
                  14,
                  14 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Select Base Currency',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0B1E3A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: false,
                      onChanged: (v) {
                        setModalState(() => query = v);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search currency...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: filtered.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 28),
                                child: Text(
                                  'No currency found',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final currency = filtered[index];
                                final selected = (selectedCurrency ?? '')
                                        .toUpperCase() ==
                                    currency.toUpperCase();
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    currency,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: selected
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF09550C),
                                        )
                                      : null,
                                  onTap: () {
                                    Navigator.pop(ctx, currency);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editRateDialog(
    BuildContext context,
    CurrencySummaryReportViewModel vm,
    String currency,
  ) async {
    final currentRate = vm.rateForCurrency(currency);
    final controller = TextEditingController(
      text: currentRate == null ? '' : currentRate.toStringAsFixed(6),
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Edit Rate ($currency)'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: vm.baseCurrency == null
                  ? 'Enter rate'
                  : '1 ${vm.baseCurrency} = ? $currency',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                if (parsed != null && parsed > 0) {
                  vm.setManualRate(currency: currency, rate: parsed);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CurrencySummaryReportViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Currency Summry Report',
          style: TextStyle(
            color: Color(0xFF0B1E3A),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: _canExport(vm)
            ? [
                IconButton(
                  tooltip: 'Share Image',
                  icon: const Icon(
                    Icons.ios_share_rounded,
                    color: Color(0xFF0B1E3A),
                  ),
                  onPressed: () => _shareAsImage(context, vm),
                ),
                IconButton(
                  tooltip: 'Export PDF',
                  icon: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFC62828),
                  ),
                  onPressed: () => _exportPdf(context, vm),
                ),
              ]
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TxSearchBar(
              value: vm.search,
              suggestions: vm.suggestions,
              onChanged: (v) {
                vm.setSearch(v);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'Select account name to view balance by currency',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12.5,
              ),
            ),
          ),
          if (vm.hasSelectedAccount)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 2, bottom: 6),
                    child: Text(
                      'Base Currency',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                    onTap: vm.loadingCurrencies
                        ? null
                        : () async {
                            FocusScope.of(context).unfocus();
                          final selected = await _showCurrencySearchPicker(
                            context,
                            vm.allCurrencies,
                              vm.baseCurrency,
                            );
                            if (selected != null &&
                                selected.trim().isNotEmpty) {
                              vm.setBaseCurrency(selected);
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              vm.loadingCurrencies
                                  ? 'Loading currencies...'
                                  : (vm.baseCurrency?.trim().isNotEmpty ?? false)
                                      ? vm.baseCurrency!
                                      : 'Search and select base currency',
                              style: TextStyle(
                                fontSize: 14,
                                color: vm.loadingCurrencies
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF111827),
                                fontWeight: vm.baseCurrency == null
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF6B7280),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (vm.loadingSuggestions || vm.loadingCurrencies || vm.resolvingAccount)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (vm.baseCurrency != null && vm.loadingRates)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xFF09550C),
              ),
            ),
          if (vm.error != null && vm.error!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                vm.error!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (vm.ratesError != null && vm.ratesError!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                vm.ratesError!,
                style: const TextStyle(
                  color: Color(0xFFB45309),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Builder(
                builder: (context) {
                  final rows = vm.rowsForDisplay();
                  final hasBaseCurrency =
                      vm.baseCurrency != null &&
                      vm.baseCurrency!.trim().isNotEmpty;

                  if (vm.search.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Search an account name to load currency balances',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }

                  if (rows.isEmpty && !vm.resolvingAccount) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'No currency balance found for this account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    itemCount: rows.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      thickness: 0.8,
                      color: Color(0x1A000000),
                      indent: 48,
                    ),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final bal = row.balance;
                      final balanceColor = bal >= 0
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828);
                      final rate = vm.rateForCurrency(row.currency);
                      final converted = vm.convertedToBase(
                        currency: row.currency,
                        amount: bal,
                      );
                      final isOverridden = vm.isRateOverridden(row.currency);

                      final currency = row.currency.trim().isEmpty
                          ? 'Unknown currency'
                          : row.currency.trim();
                      final countryName = _countryNameForCurrency(currency);

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: CountryFlag.fromCountryCode(
                                _currencyToCountryCode(currency),
                                theme: const ImageTheme(
                                  width: 32,
                                  height: 32,
                                  shape: Circle(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    currency,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0B1E3A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    countryName,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasBaseCurrency)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () => _editRateDialog(
                                      context,
                                      vm,
                                      currency,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isOverridden
                                            ? const Color(0xFFFEF3C7)
                                            : const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: isOverridden
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFFD1D5DB),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.edit_outlined,
                                            size: 11,
                                            color: Color(0xFF6B7280),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Rate',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF4B5563),
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            rate == null
                                                ? '--'
                                                : rate.toStringAsFixed(4),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF374151),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (hasBaseCurrency) const SizedBox(height: 6),
                                Text(
                                  _money(bal),
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: balanceColor,
                                  ),
                                ),
                                if (hasBaseCurrency) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    converted == null
                                        ? '-- ${vm.baseCurrency}'
                                        : '${_money(converted)} ${vm.baseCurrency}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildStickyTotalBar(vm),
    );
  }
}
