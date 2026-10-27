import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../widgets.dart';
import 'history_screen.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  Future<AttendanceSummary> _load() async =>
      AttendanceSummary.fromJson(await ApiClient.instance.get('/students/me/attendance') as Map<String, dynamic>);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: AsyncView<AttendanceSummary>(
        load: _load,
        builder: (context, summary) {
          final text = Theme.of(context).textTheme;
          void openHistory({SubjectStat? subject}) => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => HistoryScreen(subjects: summary.subjects, initialSubjectId: subject?.subjectId)));
          return [
            if (summary.warningMessage != null) WarningBanner(summary.warningMessage!),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Overall attendance'),
                  Text(summary.overall.label,
                      style: text.displaySmall?.copyWith(color: levelColor(summary.overall.level), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  AttendanceBar(summary.overall),
                  const SizedBox(height: 8),
                  Text('Present ${summary.overall.present} of ${summary.overall.total} · '
                      'minimum required ${summary.minRequired.toStringAsFixed(0)}%'),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Text('Subject-wise', style: text.titleMedium),
            const SizedBox(height: 8),
            if (summary.subjects.isEmpty) const EmptyState('No subjects yet.'),
            ...summary.subjects.map((s) => Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => openHistory(subject: s),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(s.name, style: text.titleSmall)),
                          Text(s.label, style: TextStyle(color: levelColor(s.level), fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 8),
                        AttendanceBar(s),
                        const SizedBox(height: 8),
                        Text('Present: ${s.present}   Total: ${s.total}   ·   ${levelText(s.level)}'),
                      ]),
                    ),
                  ),
                )),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: openHistory, icon: const Icon(Icons.history), label: const Text('View full attendance history')),
          ];
        },
      ),
    );
  }
}
