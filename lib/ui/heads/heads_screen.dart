import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/local/database_manager.dart';
import '../../model/account_head_option.dart';
import '../../model/user_model.dart';
import '../../repository/transactions_repository.dart';
import '../../services/local_storage.dart';
import '../../viewmodel/sync/sync_viewmodel.dart';

const Color _kHeadsBlue = Color(0xFF1862A3);
const Color _kHeadsBlueDark = Color(0xFF0D4F88);
const Color _kHeadsBg = Color(0xFFF3F7FC);

class HeadsScreen extends StatefulWidget {
  const HeadsScreen({super.key});

  @override
  State<HeadsScreen> createState() => _HeadsScreenState();
}

class _HeadsScreenState extends State<HeadsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _busy = false;
  bool _canCreateHeads = true;
  String _searchQuery = '';
  List<AccountHeadOption> _heads = const [];

  TransactionsRepository get _repo =>
      TransactionsRepository(DatabaseManager.instance.db);

  @override
  void initState() {
    super.initState();
    _loadHeadCreationAccess();
    _loadHeads();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadHeadCreationAccess() async {
    final user = await LocalStorageService.loadLastUsedUser();
    if (!mounted) return;
    setState(() => _canCreateHeads = _canCreateHeadsFor(user));
  }

  bool _canCreateHeadsFor(UserModel? user) {
    final roles = (user?.roleCodes ?? const <String>[])
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (roles.contains('VIEW') ||
        roles.contains('VIEWER') ||
        roles.contains('READONLY') ||
        roles.contains('READ_ONLY')) {
      return false;
    }
    return true;
  }

  Future<void> _loadHeads() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final rows = await _repo.getAllAccountHeads();
      if (!mounted) return;
      setState(() => _heads = rows);
    } catch (e) {
      _showMessage('Failed to load heads: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? const Color(0xFFB3261E) : _kHeadsBlue,
        content: Text(text),
      ),
    );
  }

  bool _matchesSearch(AccountHeadOption row) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return row.accHeadName.toLowerCase().contains(q) ||
        row.accHeadId.toString().contains(q);
  }

  String _headInitials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final word = words.first;
      return word.length >= 2
          ? word.substring(0, 2).toUpperCase()
          : word.toUpperCase();
    }
    return (words.first[0] + words.last[0]).toUpperCase();
  }

  Future<void> _openEditor({AccountHeadOption? existing}) async {
    if (!_canCreateHeads) {
      _showReadOnlyHeadsMessage();
      return;
    }

    SyncViewModel? syncVm;
    try {
      syncVm = context.read<SyncViewModel>();
    } catch (_) {
      syncVm = null;
    }

    _nameController.text = existing?.accHeadName ?? '';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 12),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A0F172A),
                      blurRadius: 34,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 52,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD7E7F8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_kHeadsBlue, _kHeadsBlueDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.account_tree_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  existing == null ? 'Add Head' : 'Edit Head',
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  existing == null
                                      ? 'Create a clean category for accounts and transactions.'
                                      : 'Update the head name across your setup.',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.35,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _nameController,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => Navigator.pop(context, true),
                        decoration: InputDecoration(
                          labelText: 'Head Name',
                          hintText: 'Customer, Supplier, Cash',
                          prefixIcon: const Icon(
                            Icons.badge_outlined,
                            color: _kHeadsBlue,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF7FAFE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE7F8),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE7F8),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: _kHeadsBlue,
                              width: 1.4,
                            ),
                          ),
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                side: const BorderSide(
                                  color: Color(0xFFD7E7F8),
                                ),
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _nameController.text.trim().isEmpty
                                  ? null
                                  : () => Navigator.pop(context, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: _kHeadsBlue,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                existing == null ? 'Add Head' : 'Save Changes',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    if (saved != true) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Head name cannot be empty.', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      if (existing == null) {
        await _repo.createAccountHead(accHeadName: name);
        _showMessage('Head created.');
      } else {
        await _repo.updateAccountHead(
          accHeadId: existing.accHeadId,
          accHeadName: name,
        );
        _showMessage('Head updated.');
      }
      if (syncVm != null) {
        unawaited(syncVm.triggerSmartSync(immediate: true, force: true));
      }
      await _loadHeads();
    } catch (e) {
      _showMessage('Failed to save head: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteHead(AccountHeadOption row) async {
    if (!_canCreateHeads) {
      _showReadOnlyHeadsMessage();
      return;
    }

    SyncViewModel? syncVm;
    try {
      syncVm = context.read<SyncViewModel>();
    } catch (_) {
      syncVm = null;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFB3261E),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Delete Head',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Delete '${row.accHeadName}' from your list?",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: Color(0xFFD7E7F8)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB3261E),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await _repo.deleteAccountHead(accHeadId: row.accHeadId);
      _showMessage('Head deleted.');
      if (syncVm != null) {
        unawaited(syncVm.triggerSmartSync(immediate: true, force: true));
      }
      await _loadHeads();
    } catch (e) {
      _showMessage('Failed to delete head: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _heads.where(_matchesSearch).toList(growable: false);

    return Scaffold(
      backgroundColor: _kHeadsBg,
      floatingActionButton: !_canCreateHeads
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : () => _openEditor(),
              backgroundColor: _kHeadsBlue,
              foregroundColor: Colors.white,
              elevation: 8,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Head',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
      body: Stack(
        children: [
          const _HeadsBackdrop(),
          SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kHeadsBlue, _kHeadsBlueDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x261862A3),
                        blurRadius: 24,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.account_tree_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Heads',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Organize account categories with a cleaner structure.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${rows.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              'Total',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search by head name or ID',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _kHeadsBlue,
                      ),
                      suffixIcon: _searchQuery.trim().isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: _kHeadsBlue,
                              ),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: Color(0xFFDCE7F8),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: Color(0xFFDCE7F8),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: _kHeadsBlue,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _busy && _heads.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          color: _kHeadsBlue,
                          onRefresh: _loadHeads,
                          child: rows.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    32,
                                    14,
                                    120,
                                  ),
                                  children: [
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 340,
                                      ),
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              28,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFDCE7F8),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 74,
                                                height: 74,
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          Color(0xFFE7F1FD),
                                                          Color(0xFFD8E9FB),
                                                        ],
                                                        begin:
                                                            Alignment.topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(24),
                                                ),
                                                child: const Icon(
                                                  Icons.account_tree_outlined,
                                                  size: 34,
                                                  color: _kHeadsBlue,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                _searchQuery.trim().isEmpty
                                                    ? 'No heads yet'
                                                    : 'No matching head',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                _searchQuery.trim().isEmpty
                                                    ? 'Create the first head to keep accounts and transactions neatly grouped.'
                                                    : 'Try another keyword or clear the search to view all heads.',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  height: 1.45,
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    4,
                                    14,
                                    100,
                                  ),
                                  itemCount: rows.length,
                                  separatorBuilder: (_, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final row = rows[index];
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: const Color(0xFFDCE7F8),
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x0F0F172A),
                                            blurRadius: 18,
                                            offset: Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          14,
                                          14,
                                          12,
                                          14,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                gradient:
                                                    const LinearGradient(
                                                      colors: [
                                                        _kHeadsBlue,
                                                        _kHeadsBlueDark,
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment
                                                          .bottomRight,
                                                    ),
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  _headInitials(
                                                    row.accHeadName,
                                                  ),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.6,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    row.accHeadName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 15.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (_canCreateHeads)
                                              PopupMenuButton<String>(
                                                enabled: !_busy,
                                                surfaceTintColor: Colors.white,
                                                icon: const Icon(
                                                  Icons.more_vert_rounded,
                                                  color: Color(0xFF475569),
                                                ),
                                                onSelected: (action) {
                                                  if (action == 'edit') {
                                                    _openEditor(existing: row);
                                                  } else if (action ==
                                                      'delete') {
                                                    _deleteHead(row);
                                                  }
                                                },
                                                itemBuilder: (_) => const [
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.edit_outlined,
                                                          color: _kHeadsBlue,
                                                        ),
                                                        SizedBox(width: 10),
                                                        Text('Edit'),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.delete_outline,
                                                          color: Color(
                                                            0xFFB3261E,
                                                          ),
                                                        ),
                                                        SizedBox(width: 10),
                                                        Text('Delete'),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReadOnlyHeadsMessage() {
    _showMessage('Viewer role has read-only access to heads', error: true);
  }
}

class _HeadsBackdrop extends StatelessWidget {
  const _HeadsBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -20,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x331862A3), Color(0x001862A3)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 120,
            left: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x1F1862A3), Color(0x001862A3)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
