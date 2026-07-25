// lib/ui/home/widgets/cash_in_hand_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import 'package:mehfooz_accounts_app/data/local/database_manager.dart';
import 'package:mehfooz_accounts_app/model/cash_in_hand_row.dart';
import 'package:mehfooz_accounts_app/repository/transactions_repository.dart';
import 'package:mehfooz_accounts_app/services/exchange_rate_service.dart';
import 'package:mehfooz_accounts_app/theme/app_colors.dart';
import '../../../services/pdf/export_summary_pdf.dart';
import '../../../viewmodel/home/home_view_model.dart';
import '../../commons/currency_flag.dart';
import '../../commons/fade_slide.dart';

const _kHomeBrandBlue = Color(0xFF1862A3);

class CashInHandCard extends StatefulWidget {
  final HomeViewModel vm;
  final bool isExpanded;
  final VoidCallback onToggle;
  final int maxVisible;

  const CashInHandCard({
    super.key,
    required this.vm,
    required this.isExpanded,
    required this.onToggle,
    this.maxVisible = 5,
  });

  @override
  State<CashInHandCard> createState() => _CashInHandCardState();
}

class _CashInHandCardState extends State<CashInHandCard> {
  final NumberFormat _fmt = NumberFormat('#,##0.00');

  List<String> _accTypeCurrencies = const [];
  bool _loadingBaseCurrencies = false;
  String? _selectedBaseCurrency;

  bool _loadingRates = false;
  String? _ratesError;
  Map<String, double> _onlineRates = const {};
  Map<String, double> _manualRates = const {};
  int _rateRequestId = 0;
  String _rowsSignature = '';

  String _norm(String value) => value.trim().toUpperCase();
  bool _isZero(double v) => v.abs() < 0.005;

  String _countryNameForCurrency(String currency) =>
      currencyCountryName(currency);

  void _clearBaseCurrency() {
    setState(() {
      _selectedBaseCurrency = null;
      _onlineRates = const {};
      _manualRates = const {};
      _ratesError = null;
      _loadingRates = false;
    });
  }

  double? _rateForCurrency(String currency) {
    final base = _selectedBaseCurrency;
    if (base == null || base.trim().isEmpty) return null;
    final c = _norm(currency);
    final b = _norm(base);
    if (c == b) return 1.0;
    final manual = _manualRates[c];
    if (manual != null && manual > 0) return manual;
    final online = _onlineRates[c];
    if (online != null && online > 0) return online;
    return null;
  }

  Future<void> _showEditRateDialog({required String currency}) async {
    final base = _selectedBaseCurrency;
    if (base == null || base.trim().isEmpty) return;

    final currentRate = _rateForCurrency(currency);
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
            decoration: InputDecoration(hintText: '1 $base = ? $currency'),
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
                  setState(() {
                    _manualRates = Map<String, double>.from(_manualRates)
                      ..[_norm(currency)] = parsed;
                  });
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

  Future<void> _ensureBaseCurrenciesLoaded() async {
    if (_loadingBaseCurrencies || _accTypeCurrencies.isNotEmpty) return;

    setState(() => _loadingBaseCurrencies = true);
    try {
      final companyId = widget.vm.selectedCompanyId ?? 1;
      final repo = TransactionsRepository(DatabaseManager.instance.db);
      final items = await repo.getCompanyCurrencies(companyId: companyId);
      if (!mounted) return;
      setState(() {
        _accTypeCurrencies = items
            .where((e) => e.trim().isNotEmpty)
            .toList(growable: false);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load base currencies')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingBaseCurrencies = false);
      }
    }
  }

  Future<void> _pickBaseCurrency(List<CashInHandRow> rows) async {
    await _ensureBaseCurrenciesLoaded();
    if (!mounted || _accTypeCurrencies.isEmpty) return;

    String query = '';
    final selected = await showModalBottomSheet<String>(
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
            final filtered = _accTypeCurrencies
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
                      onChanged: (v) => setModalState(() => query = v),
                      decoration: InputDecoration(
                        hintText: 'Search currency...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: _kHomeBrandBlue,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if ((_selectedBaseCurrency ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.clear_rounded,
                          color: Color(0xFFB91C1C),
                        ),
                        title: const Text(
                          'Clear Base Currency',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                        onTap: () => Navigator.pop(ctx, '__CLEAR__'),
                      ),
                      const Divider(height: 1),
                    ],
                    const SizedBox(height: 6),
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
                                final selected =
                                    _norm(_selectedBaseCurrency ?? '') ==
                                    _norm(currency);
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
                                  onTap: () => Navigator.pop(ctx, currency),
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

    if (!mounted || selected == null) return;

    if (selected == '__CLEAR__') {
      _clearBaseCurrency();
      return;
    }

    if (selected.trim().isEmpty) return;
    setState(() {
      _selectedBaseCurrency = selected.trim();
      _manualRates = const {};
      _onlineRates = const {};
      _ratesError = null;
    });
    await _loadRatesForRows(rows);
  }

  Future<void> _loadRatesForRows(List<CashInHandRow> rows) async {
    final base = _selectedBaseCurrency;
    if (base == null || base.trim().isEmpty || rows.isEmpty) {
      if (!mounted) return;
      setState(() {
        _onlineRates = const {};
        _ratesError = null;
        _loadingRates = false;
      });
      return;
    }

    final requestId = ++_rateRequestId;
    if (mounted) {
      setState(() {
        _loadingRates = true;
        _ratesError = null;
      });
    }

    try {
      final rates = await ExchangeRateService.instance.getRates(
        baseCurrency: base,
        targetCurrencies: rows.map((e) => e.currency).toList(growable: false),
      );
      if (!mounted || requestId != _rateRequestId) return;
      setState(() {
        _onlineRates = rates.map((k, v) => MapEntry(_norm(k), v));
        _loadingRates = false;
        _ratesError = null;
      });
    } catch (_) {
      if (!mounted || requestId != _rateRequestId) return;
      setState(() {
        _onlineRates = const {};
        _loadingRates = false;
        _ratesError = 'Live rate unavailable';
      });
    }
  }

  void _refreshRatesIfRowsChanged(List<CashInHandRow> rows) {
    final signature = rows
        .map((r) => '${r.currency}:${r.amount.toStringAsFixed(4)}')
        .join('|');
    if (signature == _rowsSignature) return;
    _rowsSignature = signature;

    if ((_selectedBaseCurrency ?? '').trim().isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadRatesForRows(rows);
      }
    });
  }

  double? _amountByRate({required String currency, required double amount}) {
    final base = _selectedBaseCurrency;
    if (base == null || base.trim().isEmpty) return null;

    final c = _norm(currency);
    final b = _norm(base);
    if (c == b) return amount;

    final rate = _rateForCurrency(currency);
    if (rate == null || rate <= 0) return null;
    return amount * rate;
  }

  Future<void> _exportCombinedPdf(BuildContext context) async {
    final vm = widget.vm;
    final companyName = vm.selectedCompanyName ?? "Mahfooz Accounts";
    final base = _selectedBaseCurrency?.trim();
    final hasBase = base != null && base.isNotEmpty;

    final jbRows = vm.cashInHandSummary
        .where((r) => !_isZero(r.amount.toDouble()))
        .map((r) {
          final currency = r.currency.trim().isEmpty
              ? 'Unknown'
              : r.currency.trim();
          final amount = r.amount.toDouble();
          return <String, dynamic>{
            'currency': currency,
            'amount': amount,
            'rate': hasBase ? _rateForCurrency(currency) : null,
            'converted': hasBase
                ? _amountByRate(currency: currency, amount: amount)
                : null,
          };
        })
        .toList(growable: false);

    final acc1Rows = vm.acc1CashSummary
        .where((r) => !_isZero(r.amount.toDouble()))
        .toList(growable: false);

    final file = await SummaryCombinedPdfService.instance.render(
      companyName: companyName,
      jbRows: jbRows,
      acc1Rows: acc1Rows,
      jbBaseCurrency: hasBase ? base : null,
    );

    await OpenFilex.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.vm.cashInHandSummary
        .where((r) => !_isZero(r.amount.toDouble()))
        .toList(growable: false);
    final hasData = rows.isNotEmpty;
    _refreshRatesIfRowsChanged(rows);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: hasData ? _buildContent(context, rows) : _emptyState(context),
    );
  }

  Column _buildContent(BuildContext context, List<CashInHandRow> rows) {
    final base = _selectedBaseCurrency?.trim();
    final hasBase = base != null && base.isNotEmpty;
    final subtitle = hasBase
        ? 'Summary by currency "$base"'
        : 'Summary by currency';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleRow(context, rows),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ),
            if (hasBase)
              InkWell(
                onTap: _clearBaseCurrency,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _kHomeBrandBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _kHomeBrandBlue.withValues(alpha: 0.24),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.restart_alt_rounded,
                        size: 13,
                        color: _kHomeBrandBlue,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Reset',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: _kHomeBrandBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (_loadingRates)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_ratesError != null && _ratesError!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _ratesError!,
              style: const TextStyle(
                color: Color(0xFFB45309),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 10),
        Divider(height: 16, color: AppColors.divider),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: Column(
            children: [
              ..._buildRows(rows),
              if (rows.length > widget.maxVisible)
                _buildExpandToggle(rows.length - widget.maxVisible),
              if ((_selectedBaseCurrency ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Divider(height: 12, color: AppColors.divider),
                _buildTotalRow(rows),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Row _titleRow(BuildContext context, List<CashInHandRow> rows) {
    return Row(
      children: [
        const Icon(Icons.money, color: _kHomeBrandBlue, size: 22),
        const SizedBox(width: 8),
        Text(
          "DR/CR Amounts",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.picture_as_pdf, color: _kHomeBrandBlue),
          tooltip: "Share PDF",
          onPressed: () => _exportCombinedPdf(context),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: _kHomeBrandBlue),
          tooltip: "Select base currency",
          onPressed: () => _pickBaseCurrency(rows),
        ),
      ],
    );
  }

  List<Widget> _buildRows(List<CashInHandRow> rows) {
    final base = _selectedBaseCurrency?.trim();
    final hasBase = base != null && base.isNotEmpty;
    final visible = widget.isExpanded
        ? rows.length
        : rows.length.clamp(0, widget.maxVisible).toInt();

    return List.generate(visible, (i) {
      final row = rows[i];
      final currency = row.currency.trim().isEmpty
          ? 'Unknown'
          : row.currency.trim();
      final countryName = _countryNameForCurrency(currency);
      final original = row.amount.toDouble();
      final calculated = _amountByRate(currency: currency, amount: original);
      final rate = _rateForCurrency(currency);
      final showCalculated = hasBase && calculated != null;
      final isPositive = original >= 0;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CurrencyFlagBadge(currency: currency, size: 26),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currency,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      countryName,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _AnimatedMoneyText(
                  value: original,
                  fmt: _fmt,
                  color: isPositive ? _kHomeBrandBlue : AppColors.error,
                ),
                if (hasBase)
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _showEditRateDialog(currency: currency),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.edit_outlined,
                            size: 11,
                            color: _kHomeBrandBlue,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            rate == null
                                ? 'Rate --'
                                : 'Rate ${rate.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _kHomeBrandBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (hasBase)
                  Text(
                    showCalculated
                        ? 'Total ${_fmt.format(calculated)}'
                        : 'Total --',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: showCalculated
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFFB45309),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTotalRow(List<CashInHandRow> rows) {
    final base = _selectedBaseCurrency?.trim();
    final hasBase = base != null && base.isNotEmpty;
    if (!hasBase) {
      return const SizedBox.shrink();
    }

    double total = 0;
    for (final row in rows) {
      final raw = row.amount.toDouble();
      final calculated = _amountByRate(currency: row.currency, amount: raw);
      if (calculated != null) {
        total += calculated;
      }
    }

    final color = total >= 0 ? _kHomeBrandBlue : AppColors.error;
    final label = 'Total ($base)';

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            _fmt.format(total),
            style: TextStyle(
              color: color,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandToggle(int hiddenCount) {
    return InkWell(
      onTap: widget.onToggle,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.isExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              size: 18,
              color: _kHomeBrandBlue,
            ),
            const SizedBox(width: 5),
            Text(
              widget.isExpanded ? "Show less" : "+ $hiddenCount more",
              style: TextStyle(
                fontSize: 13,
                color: _kHomeBrandBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return FadeSlide(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _kHomeBrandBlue.withValues(alpha: 0.08),
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kHomeBrandBlue.withValues(alpha: 0.14)),
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kHomeBrandBlue.withValues(alpha: 0.10),
                border: Border.all(
                  color: _kHomeBrandBlue.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(
                Icons.wallet_outlined,
                size: 28,
                color: _kHomeBrandBlue.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "No Summary Yet",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF102132),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "DR/CR movement and converted totals will appear here once transactions are added to this workspace.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: AppColors.cardShadow,
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
    border: Border.all(color: AppColors.divider),
  );
}

class _AnimatedMoneyText extends StatefulWidget {
  final double value;
  final NumberFormat fmt;
  final Color color;

  const _AnimatedMoneyText({
    required this.value,
    required this.fmt,
    required this.color,
  });

  @override
  State<_AnimatedMoneyText> createState() => _AnimatedMoneyTextState();
}

class _AnimatedMoneyTextState extends State<_AnimatedMoneyText> {
  late double _oldValue;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _AnimatedMoneyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _oldValue, end: widget.value),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) {
        return Text(
          widget.fmt.format(v),
          style: TextStyle(color: widget.color, fontWeight: FontWeight.bold),
        );
      },
    );
  }
}
