import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import '../widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<Home> _load() async => Home.fromJson(await ApiClient.instance.get('/students/me/home') as Map<String, dynamic>);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: AsyncView<Home>(
        load: _load,
        builder: (context, home) {
          final text = Theme.of(context).textTheme;
          final next = home.next;
          return [
            Text('Hello ${home.fullName.split(' ').first} 👋', style: text.headlineSmall),
            Text('${home.rollNo}${home.batch != null ? ' · ${home.batch}' : ''}', style: text.bodyMedium),
            const SizedBox(height: 16),
            if (home.warningMessage != null) WarningBanner(home.warningMessage!),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Overall Attendance'),
                  const SizedBox(height: 4),
                  Text(home.overall.label, style: text.displaySmall?.copyWith(color: levelColor(home.overall.level), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  AttendanceBar(home.overall),
                  const SizedBox(height: 8),
                  Text('Present ${home.overall.present} of ${home.overall.total} classes'),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            if (next != null) ...[
              Text('Next class', style: text.titleMedium),
              const SizedBox(height: 8),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(next.subjectName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${DateFormat('EEE, d MMM').format(next.date)} · ${next.timeRange}\n${next.room ?? 'Room TBA'}'),
                  isThreeLine: true,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text("Today's classes", style: text.titleMedium),
            const SizedBox(height: 8),
            if (home.todays.isEmpty) const EmptyState('No classes today.', icon: Icons.event_available),
            ...home.todays.map(SessionTile.new),
            const SizedBox(height: 16),
            Text('Recent attendance', style: text.titleMedium),
            const SizedBox(height: 8),
            if (home.recent.isEmpty) const EmptyState('No attendance recorded yet.'),
            ...home.recent.map((s) => SessionTile(s, showDate: true)),
          ];
        },
      ),
    );
  }
}
