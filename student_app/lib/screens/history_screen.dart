import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import '../widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.subjects, this.initialSubjectId});

  final List<SubjectStat> subjects;
  final int? initialSubjectId;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late int? _subjectId = widget.initialSubjectId;
  String? _status; // null = all
  DateTimeRange? _range;

  Future<List<SessionItem>> _load() async {
    final fmt = DateFormat('yyyy-MM-dd');
    final query = <String, String>{
      if (_subjectId != null) 'subject_id': '$_subjectId',
      if (_status != null) 'status': _status!,
      if (_range != null) 'from_date': fmt.format(_range!.start),
      if (_range != null) 'to_date': fmt.format(_range!.end),
    };
    final data = await ApiClient.instance.get('/students/me/attendance/history', query: query) as List;
    return data.map((e) => SessionItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM');
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance history')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(children: [
            DropdownButtonFormField<int?>(
              value: _subjectId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All subjects')),
                ...widget.subjects.map((s) => DropdownMenuItem<int?>(value: s.subjectId, child: Text(s.name))),
              ],
              onChanged: (v) => setState(() => _subjectId = v),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: SegmentedButton<String?>(
                  segments: const [
                    ButtonSegment(value: null, label: Text('All')),
                    ButtonSegment(value: 'PRESENT', label: Text('Present')),
                    ButtonSegment(value: 'ABSENT', label: Text('Absent')),
                  ],
                  selected: {_status},
                  onSelectionChanged: (s) => setState(() => _status = s.first),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(_range == null ? 'Any date' : '${fmt.format(_range!.start)} - ${fmt.format(_range!.end)}'),
                ),
              ),
              if (_range != null) IconButton(tooltip: 'Clear dates', onPressed: () => setState(() => _range = null), icon: const Icon(Icons.clear)),
            ]),
          ]),
        ),
        Expanded(
          child: AsyncView<List<SessionItem>>(
            key: ValueKey('$_subjectId|$_status|$_range'),
            load: _load,
            builder: (context, items) => [
              if (items.isEmpty) const EmptyState('No attendance matches these filters.', icon: Icons.search_off),
              ...items.map((s) => SessionTile(s, showDate: true)),
            ],
          ),
        ),
      ]),
    );
  }
}
