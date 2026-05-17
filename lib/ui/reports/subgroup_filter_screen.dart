import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/global_state.dart';
import '../../services/pdf/open_file_service.dart';
import '../../viewmodel/reports/ledger_filter_view_model.dart';
import '../../viewmodel/reports/reports_view_model.dart';

const Color _kTrailBlue = Color(0xFF1862A3);
const Color _kTrailBlueDark = Color(0xFF0F4E88);
const Color _kTrailBg = Color(0xFFF4F8FC);

enum _TrailDatePreset { today, yesterday, week, custom }

class TrailBalanceFilterScreen extends StatefulWidget {
  const TrailBalanceFilterScreen({super.key});

  @override
  State<TrailBalanceFilterScreen> createState() =>
      _TrailBalanceFilterScreenState();
}

class _TrailBalanceFilterScreenState extends State<TrailBalanceFilterScreen> {
  final _accountController = TextEditingController();
  final _currencyController = TextEditingController();
  final _fromDateController = TextEditingController();
  final _toDateController = TextEditingController();
  final _dateFmtHuman = DateFormat('dd MMM yyyy');
  final _dateFmtDb = DateFormat('yyyy-MM-dd');

  _TrailDatePreset _preset = _TrailDatePreset.today;
  bool _showSuggestions = false;
  bool _isGenerating = false;
  String _currencyLoadedForAccount = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LedgerFilterViewModel>().loadCurrencies();
      _applyPreset(_TrailDatePreset.today);
    });
  }

  @override
  void dispose() {
    _accountController.dispose();
    _currencyController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickerVm = context.watch<LedgerFilterViewModel>();
    final reportsVm = context.watch<ReportsViewModel>();
    final isBusy =
        _isGenerating ||
        (reportsVm.ui.loading && reportsVm.ui.activeReportKey == 'subgroup');

    return Scaffold(
      backgroundColor: _kTrailBg,
      body: Stack(
        children: [
          const _TrailBackdrop(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 16),
                  _buildHero(),
                  const SizedBox(height: 16),
                  _buildFilterCard(
                    context,
                    pickerVm,
                    reportsVm,
                    isBusy: isBusy,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(
                Icons.arrow_back_rounded,
                color: _kTrailBlue,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1862A3), Color(0xFF0E4B84)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A1862A3),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              _HeroGlyph(),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Trail Balance Filters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Build a cleaner trial balance by narrowing the export to a specific account, currency, or period.',
            style: TextStyle(
              color: Color(0xD8FFFFFF),
              fontSize: 13.3,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard(
    BuildContext context,
    LedgerFilterViewModel pickerVm,
    ReportsViewModel reportsVm, {
    required bool isBusy,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDCE7F2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1212283A),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Export Settings',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF102C49),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Company: ${GlobalState.instance.companyName}',
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF6D8195),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _sectionLabel('Account'),
          const SizedBox(height: 8),
          TextField(
            controller: _accountController,
            decoration: _inputDecoration(
              hint: 'All accounts or search one by name',
              prefix: Icons.search_rounded,
              suffix: _accountController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: () async {
                        _accountController.clear();
                        _currencyLoadedForAccount = '';
                        _currencyController.clear();
                        _showSuggestions = false;
                        await pickerVm.loadCurrencies();
                        if (!mounted) return;
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            onChanged: (value) async {
              final text = value.trim();
              if (text.isEmpty) {
                _showSuggestions = false;
                _currencyLoadedForAccount = '';
                _currencyController.clear();
                await pickerVm.loadCurrencies();
                if (!mounted) return;
                setState(() {});
                return;
              }
              if (_currencyLoadedForAccount.trim().toLowerCase() !=
                  text.toLowerCase()) {
                _currencyController.clear();
              }
              await pickerVm.searchAccounts(text);
              if (!mounted) return;
              setState(() => _showSuggestions = true);
            },
            onSubmitted: (_) => _loadCurrenciesForAccount(pickerVm),
          ),
          if (_showSuggestions && pickerVm.accountSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSuggestions(pickerVm),
          ],
          const SizedBox(height: 18),
          _sectionLabel('Currency'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(
              'trail_currency_${_currencyLoadedForAccount}_${pickerVm.currencies.length}_${_currencyController.text.trim().toLowerCase()}',
            ),
            initialValue: _selectedCurrencyValue(pickerVm),
            decoration: _inputDecoration(
              hint: 'All currencies',
              prefix: Icons.currency_exchange_rounded,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('All currencies'),
              ),
              ...pickerVm.currencies.map(
                (currency) => DropdownMenuItem<String>(
                  value: currency,
                  child: Text(currency),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() => _currencyController.text = (value ?? '').trim());
            },
          ),
          if (_accountController.text.trim().isNotEmpty &&
              pickerVm.currencies.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'No worked currencies found for this account yet.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF7C8D9D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _sectionLabel('Date Range'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _TrailDatePreset.values
                .map((preset) => _presetChip(preset))
                .toList(growable: false),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _dateField(
                  label: 'From date',
                  controller: _fromDateController,
                  enabled: _preset == _TrailDatePreset.custom,
                  onPick: () => _pickDate(_fromDateController),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dateField(
                  label: 'To date',
                  controller: _toDateController,
                  enabled: _preset == _TrailDatePreset.custom,
                  onPick: () => _pickDate(_toDateController),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isBusy
                  ? null
                  : () => _generateReport(context, pickerVm, reportsVm),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kTrailBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: isBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.picture_as_pdf_rounded, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Generate Trail Balance',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(LedgerFilterViewModel pickerVm) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8F3)),
      ),
      child: Column(
        children: pickerVm.accountSuggestions
            .take(6)
            .map(
              (name) => ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: _kTrailBlue,
                    size: 18,
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF12304F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () async {
                  _accountController.text = name;
                  _showSuggestions = false;
                  await _loadCurrenciesForAccount(pickerVm);
                },
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _presetChip(_TrailDatePreset preset) {
    final selected = _preset == preset;
    return InkWell(
      onTap: () => _applyPreset(preset),
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F3FF) : const Color(0xFFF7FAFD),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _kTrailBlue : const Color(0xFFDCE5EF),
          ),
        ),
        child: Text(
          switch (preset) {
            _TrailDatePreset.today => 'Today',
            _TrailDatePreset.yesterday => 'Yesterday',
            _TrailDatePreset.week => 'This Week',
            _TrailDatePreset.custom => 'Custom',
          },
          style: TextStyle(
            color: selected ? _kTrailBlueDark : const Color(0xFF6D8195),
            fontWeight: FontWeight.w800,
            fontSize: 12.6,
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13.2,
        fontWeight: FontWeight.w800,
        color: Color(0xFF12304F),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required VoidCallback onPick,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: enabled ? onPick : null,
      decoration: _inputDecoration(
        hint: label,
        prefix: Icons.calendar_month_rounded,
      ).copyWith(
        enabled: enabled,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FBFE),
      prefixIcon: Icon(prefix, color: _kTrailBlue),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD7E4F1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD7E4F1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _kTrailBlue, width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE5EDF6)),
      ),
    );
  }

  String? _selectedCurrencyValue(LedgerFilterViewModel pickerVm) {
    final current = _currencyController.text.trim();
    if (current.isEmpty) return '';
    final exists = pickerVm.currencies.any(
      (currency) => currency.trim().toLowerCase() == current.toLowerCase(),
    );
    return exists ? current : '';
  }

  Future<void> _loadCurrenciesForAccount(LedgerFilterViewModel pickerVm) async {
    final name = _accountController.text.trim();
    if (name.isEmpty) {
      _currencyLoadedForAccount = '';
      _currencyController.clear();
      await pickerVm.loadCurrencies();
      if (!mounted) return;
      setState(() {});
      return;
    }

    await pickerVm.loadCurrenciesForAccountName(name);
    if (!mounted) return;

    _currencyLoadedForAccount = name;
    final current = _currencyController.text.trim().toLowerCase();
    if (current.isNotEmpty &&
        !pickerVm.currencies.any((c) => c.trim().toLowerCase() == current)) {
      _currencyController.clear();
    }
    setState(() {});
  }

  void _applyPreset(_TrailDatePreset preset) {
    final now = DateTime.now();
    setState(() => _preset = preset);

    switch (preset) {
      case _TrailDatePreset.today:
        _fromDateController.text = _dateFmtHuman.format(now);
        _toDateController.text = _dateFmtHuman.format(now);
        break;
      case _TrailDatePreset.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        _fromDateController.text = _dateFmtHuman.format(yesterday);
        _toDateController.text = _dateFmtHuman.format(yesterday);
        break;
      case _TrailDatePreset.week:
        final startOfWeek = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        _fromDateController.text = _dateFmtHuman.format(startOfWeek);
        _toDateController.text = _dateFmtHuman.format(now);
        break;
      case _TrailDatePreset.custom:
        if (_fromDateController.text.trim().isEmpty ||
            _toDateController.text.trim().isEmpty) {
          final lastWeek = now.subtract(const Duration(days: 6));
          _fromDateController.text = _dateFmtHuman.format(lastWeek);
          _toDateController.text = _dateFmtHuman.format(now);
        }
        break;
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final fallback = DateTime.now();
    final initial = controller.text.trim().isEmpty
        ? fallback
        : _dateFmtHuman.parse(controller.text.trim());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _kTrailBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF12304F),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      controller.text = _dateFmtHuman.format(picked);
    });
  }

  Future<void> _generateReport(
    BuildContext context,
    LedgerFilterViewModel pickerVm,
    ReportsViewModel reportsVm,
  ) async {
    if (_isGenerating) return;

    final accountName = _accountController.text.trim();
    final currencyName = _currencyController.text.trim();

    int? accId;
    if (accountName.isNotEmpty) {
      accId = await pickerVm.resolveAccId(accountName);
      if (accId == null) {
        _toast('Select a valid account');
        return;
      }
    }

    int? accTypeId;
    if (currencyName.isNotEmpty) {
      accTypeId = await pickerVm.resolveAccTypeId(currencyName);
      if (accTypeId == null) {
        _toast('Select a valid currency');
        return;
      }
    }

    final fromHuman = _fromDateController.text.trim();
    final toHuman = _toDateController.text.trim();
    if (fromHuman.isEmpty || toHuman.isEmpty) {
      _toast('Select the date range');
      return;
    }

    final fromDate = _dateFmtDb.format(_dateFmtHuman.parse(fromHuman));
    final toDate = _dateFmtDb.format(_dateFmtHuman.parse(toHuman));

    setState(() => _isGenerating = true);
    try {
      final periodText = 'Period: $fromHuman - $toHuman';
      final filterParts = <String>[
        if (accountName.isNotEmpty) 'Account: $accountName',
        if (currencyName.isNotEmpty) 'Currency: $currencyName',
      ];
      final file = await reportsVm.generateSubgroupReport(
        accId: accId,
        accTypeId: accTypeId,
        fromDate: fromDate,
        toDate: toDate,
        title: 'Trail Balance',
        periodText: periodText,
        filterSummary: filterParts.isEmpty ? null : filterParts.join('   '),
      );

      if (!context.mounted) return;
      if (file == null) {
        _toast('No data available for the selected filters');
        return;
      }
      await OpenFileService.openPdf(context, file);
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _kTrailBlueDark,
        content: Text(message),
      ),
    );
  }
}

class _HeroGlyph extends StatelessWidget {
  const _HeroGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0x24FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: const Icon(
        Icons.account_tree_outlined,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}

class _TrailBackdrop extends StatelessWidget {
  const _TrailBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: _kTrailBg),
        Positioned(
          top: -70,
          right: -55,
          child: Container(
            width: 220,
            height: 220,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x351862A3), Color(0x001862A3)],
              ),
            ),
          ),
        ),
        Positioned(
          top: 170,
          left: -70,
          child: Container(
            width: 180,
            height: 180,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x1D1862A3), Color(0x001862A3)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
