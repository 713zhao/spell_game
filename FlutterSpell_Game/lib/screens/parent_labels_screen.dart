import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../design_system/design_system.dart';
import '../providers/game_provider.dart';
import '../widgets/app_bottom_nav.dart';

class _Node {
  final String label;
  final Map<String, _Node> children = {};
  Map<String, dynamic>? tag;
  _Node(this.label);
}

/// Parent Mode: find labels (tags) and assign/unassign them to this child's
/// account. Labels are hierarchical, split on `::`.
class ParentLabelsScreen extends StatefulWidget {
  const ParentLabelsScreen({super.key});

  @override
  State<ParentLabelsScreen> createState() => _ParentLabelsScreenState();
}

class _ParentLabelsScreenState extends State<ParentLabelsScreen> {
  static const _filterKey = 'tagAssignmentFilter';
  final _filterController = TextEditingController();
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _assigned = [];
  final Set<int> _selectedAvailable = {};
  final Set<int> _selectedAssigned = {};
  // Expanded groups, keyed by side + full path, so they survive rebuilds.
  final Set<String> _expanded = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _filterController.text = prefs.getString(_filterKey) ?? '';
    } catch (_) {}
    await _load();
  }

  String _name(Map<String, dynamic> t) =>
      (t['tag'] ?? t['name'] ?? '').toString();

  Future<void> _load() async {
    final api = context.read<GameProvider>().apiClient;
    try {
      final all = await api.getAvailableTags();
      final assigned = await api.getUserTags();
      if (!mounted) return;
      setState(() {
        _all = all;
        _assigned = assigned;
        _selectedAvailable.clear();
        _selectedAssigned.clear();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load labels: $e';
      });
    }
  }

  List<Map<String, dynamic>> get _available {
    final assignedIds = _assigned.map((t) => t['id']).toSet();
    final f = _filterController.text.trim().toUpperCase();
    return _all
        .where(
          (t) =>
              !assignedIds.contains(t['id']) &&
              (f.isEmpty || _name(t).toUpperCase().contains(f)),
        )
        .toList();
  }

  /// Moves the selected labels between the two lists right away, then syncs
  /// with the server (reloading to the true state if the call fails).
  Future<void> _move({required bool assign}) async {
    final api = context.read<GameProvider>().apiClient;
    final ids = (assign ? _selectedAvailable : _selectedAssigned).toList();
    if (ids.isEmpty) return;
    setState(() {
      if (assign) {
        _assigned = [..._assigned, ..._all.where((t) => ids.contains(t['id']))];
      } else {
        _assigned = _assigned.where((t) => !ids.contains(t['id'])).toList();
      }
      _selectedAvailable.clear();
      _selectedAssigned.clear();
    });
    try {
      await (assign ? api.assignTags(ids) : api.unassignTags(ids));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      await _load();
    }
  }

  List<_Node> _tree(List<Map<String, dynamic>> tags) {
    final roots = <String, _Node>{};
    for (final t in tags) {
      var level = roots;
      final parts = _name(t).split('::');
      for (var i = 0; i < parts.length; i++) {
        final node = level.putIfAbsent(parts[i], () => _Node(parts[i]));
        if (i == parts.length - 1) node.tag = t;
        level = node.children;
      }
    }
    return roots.values.toList();
  }

  Widget _buildNodes(
    List<_Node> nodes,
    Set<int> selected,
    bool isAssigned, {
    String parentPath = '',
    bool expanded = false,
  }) {
    return Column(
      children: [
        for (final n in nodes)
          if (n.children.isEmpty && n.tag != null)
            _tile(n.tag!, n.label, selected, isAssigned)
          else
            ExpansionTile(
              key: ValueKey('$isAssigned|$parentPath${n.label}'),
              initiallyExpanded:
                  expanded ||
                  _expanded.contains('$isAssigned|$parentPath${n.label}'),
              onExpansionChanged: (open) {
                final k = '$isAssigned|$parentPath${n.label}';
                open ? _expanded.add(k) : _expanded.remove(k);
              },
              leading: const Icon(Icons.folder, color: Colors.blueGrey),
              title: Text(
                n.label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              childrenPadding: const EdgeInsets.only(left: 16),
              children: [
                if (n.tag != null)
                  _tile(n.tag!, '(this label)', selected, isAssigned),
                _buildNodes(
                  n.children.values.toList(),
                  selected,
                  isAssigned,
                  expanded: expanded,
                  parentPath: '$parentPath${n.label}::',
                ),
              ],
            ),
      ],
    );
  }

  Widget _tile(
    Map<String, dynamic> t,
    String title,
    Set<int> selected,
    bool isAssigned,
  ) {
    final id = t['id'] as int;
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: selected.contains(id),
      title: Text(title),
      onChanged: (v) =>
          setState(() => v == true ? selected.add(id) : selected.remove(id)),
    );
  }

  Widget _panel(
    String title,
    Widget tree,
    String button,
    IconData icon,
    VoidCallback? onPressed,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(child: tree),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(button),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtering = _filterController.text.trim().isNotEmpty;
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(current: '/parent-labels'),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : Padding(
                padding: EdgeInsets.all(DuolingoSpacing.md),
                child: Column(
                  children: [
                    TextField(
                      controller: _filterController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        labelText: 'Filter labels (e.g. P3 or SMSP)',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: filtering
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _filterController.clear();
                                  SharedPreferences.getInstance().then(
                                    (p) => p.setString(_filterKey, ''),
                                  );
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (v) {
                        SharedPreferences.getInstance().then(
                          (p) => p.setString(_filterKey, v.toUpperCase()),
                        );
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _panel(
                              'Available (${_available.length})',
                              _buildNodes(
                                _tree(_available),
                                _selectedAvailable,
                                false,
                                expanded: filtering,
                              ),
                              'Assign →',
                              Icons.arrow_forward,
                              _selectedAvailable.isEmpty
                                  ? null
                                  : () => _move(assign: true),
                            ),
                          ),
                          const VerticalDivider(width: 16),
                          Expanded(
                            child: _panel(
                              'Assigned (${_assigned.length})',
                              _buildNodes(
                                _tree(_assigned),
                                _selectedAssigned,
                                true,
                              ),
                              '← Unassign',
                              Icons.arrow_back,
                              _selectedAssigned.isEmpty
                                  ? null
                                  : () => _move(assign: false),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
