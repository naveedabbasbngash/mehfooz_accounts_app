import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../model/tx_item_ui.dart';
import '../../repository/transactions_repository.dart';
import '../../theme/app_colors.dart';

class TransactionTrashScreen extends StatefulWidget {
  final TransactionsRepository repo;
  final int companyId;

  const TransactionTrashScreen({
    super.key,
    required this.repo,
    required this.companyId,
  });

  @override
  State<TransactionTrashScreen> createState() => _TransactionTrashScreenState();
}

class _TransactionTrashScreenState extends State<TransactionTrashScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  int? _restoringVoucherNo;
  int? _deletingVoucherNo;
  bool _deletingAll = false;
  bool _bulkRestoring = false;
  bool _bulkDeleting = false;
  final Set<int> _selectedVoucherNos = <int>{};

  static final NumberFormat _amountFmt = NumberFormat('#,##0.00');
  bool get _isSelectionMode => _selectedVoucherNos.isNotEmpty;
  bool get _isBusy =>
      _restoringVoucherNo != null ||
      _deletingVoucherNo != null ||
      _deletingAll ||
      _bulkRestoring ||
      _bulkDeleting;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatAmount(TxItemUi item) {
    final amount = item.cr > 0 ? item.cr : item.dr;
    final sign = item.cr > 0 ? '+' : '-';
    return '$sign${_amountFmt.format(amount)} ${item.currency}';
  }

  void _toggleSelection(int voucherNo) {
    setState(() {
      if (_selectedVoucherNos.contains(voucherNo)) {
        _selectedVoucherNos.remove(voucherNo);
      } else {
        _selectedVoucherNos.add(voucherNo);
      }
    });
  }

  Future<void> _restoreSelected() async {
    if (_selectedVoucherNos.isEmpty || _isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore selected transactions?'),
        content: Text(
          'Restore ${_selectedVoucherNos.length} selected transaction(s) from trash?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore Selected'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _bulkRestoring = true);
    try {
      var affected = 0;
      final voucherNos = _selectedVoucherNos.toList(growable: false);
      for (final voucherNo in voucherNos) {
        final count = await widget.repo.restoreTransactionWithLinkedEntries(
          companyId: widget.companyId,
          voucherNo: voucherNo,
        );
        if (count > 0) affected++;
      }
      if (!mounted) return;
      setState(() => _selectedVoucherNos.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored $affected selected transaction(s).'),
          backgroundColor: AppColors.darkgreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore selected transactions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _bulkRestoring = false);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedVoucherNos.isEmpty || _isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected permanently?'),
        content: Text(
          'Delete ${_selectedVoucherNos.length} selected transaction(s) forever? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Selected'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _bulkDeleting = true);
    try {
      var affected = 0;
      final voucherNos = _selectedVoucherNos.toList(growable: false);
      for (final voucherNo in voucherNos) {
        final count = await widget.repo
            .purgeDeletedTransactionWithLinkedEntries(
              companyId: widget.companyId,
              voucherNo: voucherNo,
            );
        if (count > 0) affected++;
      }
      if (!mounted) return;
      setState(() => _selectedVoucherNos.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $affected selected transaction(s) forever.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete selected transactions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _bulkDeleting = false);
    }
  }

  Future<void> _restore(TxItemUi row) async {
    if (_isBusy) {
      return;
    }

    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore transaction?'),
        content: const Text(
          'The transaction will be moved back from trash and shown in the list again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (restore != true || !mounted) return;

    setState(() => _restoringVoucherNo = row.voucherNo);
    try {
      final restored = await widget.repo.restoreTransactionWithLinkedEntries(
        companyId: widget.companyId,
        voucherNo: row.voucherNo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restored > 1
                ? 'Transaction and linked cash entry restored.'
                : 'Transaction restored.',
          ),
          backgroundColor: AppColors.darkgreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore transaction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _restoringVoucherNo = null);
    }
  }

  Future<void> _deleteForever(TxItemUi row) async {
    if (_isBusy) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: const Text(
          'This action cannot be undone. The transaction will be removed forever.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingVoucherNo = row.voucherNo);
    try {
      final deleted = await widget.repo
          .purgeDeletedTransactionWithLinkedEntries(
            companyId: widget.companyId,
            voucherNo: row.voucherNo,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted > 1
                ? 'Transaction and linked cash entry deleted forever.'
                : 'Transaction deleted forever.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete transaction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingVoucherNo = null);
    }
  }

  Future<void> _deleteAll() async {
    if (_isBusy || _isSelectionMode) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all trashed transactions?'),
        content: const Text(
          'This will permanently clear all deleted transactions from trash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingAll = true);
    try {
      final deleted = await widget.repo.purgeAllDeletedTransactions(
        companyId: widget.companyId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $deleted transaction(s) from trash.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear trash: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingAll = false);
    }
  }

  Widget _buildItem(TxItemUi item) {
    final isRestoring = _restoringVoucherNo == item.voucherNo;
    final isDeleting = _deletingVoucherNo == item.voucherNo;
    final isSelected = _selectedVoucherNos.contains(item.voucherNo);
    final title = item.name.trim().isEmpty ? 'Unknown account' : item.name;
    final subtitle = item.description?.trim().isNotEmpty == true
        ? item.description!.trim()
        : 'No description';

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFFAF1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF74C69D) : const Color(0xFFE2E8F0),
          width: isSelected ? 1.2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: () => _toggleSelection(item.voucherNo),
          onTap: _isSelectionMode
              ? () => _toggleSelection(item.voucherNo)
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFBE123C),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${item.date}  •  Voucher #${item.voucherNo}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatAmount(item),
                        style: TextStyle(
                          fontSize: 12,
                          color: item.cr > 0
                              ? const Color(0xFF166534)
                              : const Color(0xFFB91C1C),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (_isSelectionMode)
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? const Color(0xFF0A6B1D)
                        : const Color(0xFF94A3B8),
                  )
                else ...[
                  PopupMenuButton<String>(
                    enabled: !(isRestoring || isDeleting || _isBusy),
                    tooltip: 'Actions',
                    onSelected: (action) {
                      if (action == 'restore') {
                        _restore(item);
                      } else if (action == 'delete') {
                        _deleteForever(item);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem<String>(
                        value: 'restore',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.restore),
                          title: Text('Restore'),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_forever_outlined,
                            color: Colors.red,
                          ),
                          title: Text('Delete Forever'),
                        ),
                      ),
                    ],
                    icon: (isRestoring || isDeleting)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.more_vert, color: Color(0xFF334155)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trimmedSearch = _search.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Transaction Trash'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Delete all',
            onPressed: (_deletingAll || _isSelectionMode) ? null : _deleteAll,
            icon: _deletingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_sweep_outlined, color: Colors.red),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF065F46)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Deleted transactions stay here. You can restore any entry anytime.',
                      style: TextStyle(
                        color: Color(0xFF065F46),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search deleted transactions',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: trimmedSearch.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),
            if (_isSelectionMode)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFFAF1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 520;
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_selectedVoucherNos.length} selected',
                                style: const TextStyle(
                                  color: Color(0xFF065F46),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _isBusy
                                    ? null
                                    : () => setState(
                                        () => _selectedVoucherNos.clear(),
                                      ),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: _isBusy ? null : _restoreSelected,
                                  style: FilledButton.styleFrom(
                                    foregroundColor: AppColors.darkgreen,
                                  ),
                                  icon: _bulkRestoring
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.restore),
                                  label: const Text('Restore'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _isBusy ? null : _deleteSelected,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  icon: _bulkDeleting
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.delete_outline),
                                  label: const Text('Delete'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Text(
                          '${_selectedVoucherNos.length} selected',
                          style: const TextStyle(
                            color: Color(0xFF065F46),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _isBusy
                              ? null
                              : () =>
                                    setState(() => _selectedVoucherNos.clear()),
                          child: const Text('Clear'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton.tonalIcon(
                          onPressed: _isBusy ? null : _restoreSelected,
                          style: FilledButton.styleFrom(
                            foregroundColor: AppColors.darkgreen,
                          ),
                          icon: _bulkRestoring
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.restore),
                          label: const Text('Restore'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton.icon(
                          onPressed: _isBusy ? null : _deleteSelected,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          icon: _bulkDeleting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            Expanded(
              child: StreamBuilder<List<TxItemUi>>(
                stream: widget.repo.watchDeletedTransactions(
                  companyId: widget.companyId,
                  name: trimmedSearch.isEmpty ? null : trimmedSearch,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final rows = snapshot.data ?? const <TxItemUi>[];
                  if (rows.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Trash is empty. Deleted transactions will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    itemCount: rows.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _buildItem(rows[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
