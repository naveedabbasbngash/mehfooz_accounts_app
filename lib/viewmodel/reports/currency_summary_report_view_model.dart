import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../model/balance_currency_ui.dart';
import '../../repository/transactions_repository.dart';
import '../../services/exchange_rate_service.dart';

class CurrencySummaryReportViewModel extends ChangeNotifier {
  final TransactionsRepository repo;
  final int companyId;

  CurrencySummaryReportViewModel({
    required this.repo,
    required this.companyId,
  }) {
    _init();
  }

  String _search = '';
  bool _loadingSuggestions = false;
  bool _loadingCurrencies = false;
  bool _loadingRates = false;
  bool _resolvingAccount = false;
  bool _hasSelectedAccount = false;
  String? _error;
  String? _ratesError;
  List<String> _suggestions = [];
  List<String> _allCurrencies = [];
  List<BalanceCurrencyUi> _rows = [];
  String? _baseCurrency;
  Map<String, double> _onlineRates = {};
  Map<String, double> _manualRates = {};

  int _activeRequestId = 0;
  int _rateRequestId = 0;
  Timer? _searchDebounce;
  StreamSubscription<List<BalanceCurrencyUi>>? _balanceSub;

  String get search => _search;
  bool get loadingSuggestions => _loadingSuggestions;
  bool get loadingCurrencies => _loadingCurrencies;
  bool get loadingRates => _loadingRates;
  bool get resolvingAccount => _resolvingAccount;
  bool get hasSelectedAccount => _hasSelectedAccount;
  String? get error => _error;
  String? get ratesError => _ratesError;
  List<String> get suggestions => _suggestions;
  List<String> get allCurrencies => _allCurrencies;
  List<BalanceCurrencyUi> get rows => _rows;
  String? get baseCurrency => _baseCurrency;

  String _norm(String value) => value.trim().toUpperCase();
  bool _isZero(double v) => v.abs() < 0.005;

  Future<void> _init() async {
    await Future.wait([
      _loadSuggestions(),
      _loadCurrencies(),
    ]);
  }

  Future<void> _loadSuggestions() async {
    _loadingSuggestions = true;
    notifyListeners();

    try {
      _suggestions = await repo.getAccountNameSuggestions(companyId: companyId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingSuggestions = false;
      notifyListeners();
    }
  }

  Future<void> _loadCurrencies() async {
    _loadingCurrencies = true;
    notifyListeners();

    try {
      _allCurrencies = await repo.getCompanyCurrencies(companyId: companyId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingCurrencies = false;
      notifyListeners();
    }
  }

  void setSearch(String value) {
    _search = value.trim();
    _error = null;
    _searchDebounce?.cancel();

    _hasSelectedAccount = false;
    _resolvingAccount = false;
    notifyListeners();

    if (_search.isEmpty) {
      unawaited(_resolveAndLoad());
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 260), () {
      unawaited(_resolveAndLoad());
    });
  }

  void setBaseCurrency(String currency) {
    _baseCurrency = currency.trim().isEmpty ? null : currency.trim();
    _ratesError = null;
    unawaited(_loadRatesForRows());
    notifyListeners();
  }

  double? rateForCurrency(String currency) {
    final key = _norm(currency);
    final manual = _manualRates[key];
    if (manual != null) return manual;
    return _onlineRates[key];
  }

  bool isRateOverridden(String currency) {
    return _manualRates.containsKey(_norm(currency));
  }

  double? convertedToBase({
    required String currency,
    required double amount,
  }) {
    final base = _baseCurrency;
    if (base == null || base.trim().isEmpty) return null;

    final c = _norm(currency);
    final b = _norm(base);
    if (c == b) return amount;

    final rate = rateForCurrency(c);
    if (rate == null || rate <= 0) return null;
    return amount / rate;
  }

  void setManualRate({
    required String currency,
    required double rate,
  }) {
    if (rate <= 0) return;
    _manualRates[_norm(currency)] = rate;
    notifyListeners();
  }

  List<BalanceCurrencyUi> rowsForDisplay() {
    if (_baseCurrency == null || _baseCurrency!.isEmpty || _rows.isEmpty) {
      return _rows;
    }
    final target = _baseCurrency!.toLowerCase();
    final sorted = List<BalanceCurrencyUi>.from(_rows);
    sorted.sort((a, b) {
      final aMatch = a.currency.toLowerCase() == target;
      final bMatch = b.currency.toLowerCase() == target;
      if (aMatch && !bMatch) return -1;
      if (!aMatch && bMatch) return 1;
      return a.currency.toLowerCase().compareTo(b.currency.toLowerCase());
    });
    return sorted;
  }

  Future<void> _resolveAndLoad() async {
    final requestId = ++_activeRequestId;
    final query = _search;

    if (query.isEmpty) {
      await _balanceSub?.cancel();
      _rows = [];
      _onlineRates = {};
      _manualRates = {};
      _ratesError = null;
      _loadingRates = false;
      _resolvingAccount = false;
      _hasSelectedAccount = false;
      notifyListeners();
      return;
    }

    _resolvingAccount = true;
    notifyListeners();

    final accId = await repo.findAccIdByExactNameLoose(
      companyId: companyId,
      name: query,
    );

    if (requestId != _activeRequestId) return;

    await _balanceSub?.cancel();
    _balanceSub = null;

    if (accId == null) {
      _rows = [];
      _onlineRates = {};
      _manualRates = {};
      _ratesError = null;
      _loadingRates = false;
      _resolvingAccount = false;
      _hasSelectedAccount = false;
      _error = null;
      notifyListeners();
      return;
    }

    _hasSelectedAccount = true;

    _balanceSub = repo
        .watchBalanceByCurrencyForAccId(
          companyId: companyId,
          accId: accId,
        )
        .listen(
      (data) {
        if (requestId != _activeRequestId) return;
        _rows = data
            .where((r) => !_isZero(r.balance))
            .toList(growable: false);
        _manualRates.removeWhere(
          (key, value) =>
              !_rows.any((r) => _norm(r.currency) == key),
        );
        unawaited(_loadRatesForRows());
        _resolvingAccount = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        if (requestId != _activeRequestId) return;
        _rows = [];
        _onlineRates = {};
        _manualRates = {};
        _ratesError = null;
        _loadingRates = false;
        _resolvingAccount = false;
        _hasSelectedAccount = false;
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  Future<void> _loadRatesForRows() async {
    final base = _baseCurrency;
    if (base == null || base.trim().isEmpty || _rows.isEmpty) {
      debugPrint(
        '[FxRate][VM] skip load base="$base" rows=${_rows.length}',
      );
      _onlineRates = {};
      _ratesError = null;
      _loadingRates = false;
      notifyListeners();
      return;
    }

    final requestId = ++_rateRequestId;
    _loadingRates = true;
    _ratesError = null;
    debugPrint(
      '[FxRate][VM] load start base=$base requestId=$requestId rows=${_rows.length}',
    );
    notifyListeners();

    try {
      final rates = await ExchangeRateService.instance.getRates(
        baseCurrency: base,
        targetCurrencies: _rows.map((e) => e.currency).toList(growable: false),
      );

      if (requestId != _rateRequestId) return;
      _onlineRates = rates.map((k, v) => MapEntry(_norm(k), v));
      _loadingRates = false;
      _ratesError = null;
      debugPrint(
        '[FxRate][VM] load success requestId=$requestId mapped=${_onlineRates.length}',
      );
      notifyListeners();
    } catch (e, s) {
      if (requestId != _rateRequestId) return;
      _onlineRates = {};
      _loadingRates = false;
      _ratesError = 'Live rate unavailable';
      debugPrint('[FxRate][VM] load failed requestId=$requestId error=$e');
      debugPrintStack(stackTrace: s);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _balanceSub?.cancel();
    super.dispose();
  }
}
