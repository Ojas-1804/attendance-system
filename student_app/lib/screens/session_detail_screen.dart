import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import '../widgets.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.sessionId});
  final int sessionId;

  Future<SessionItem> _load() async =>
      SessionItem.fromJson(await ApiClient.instance.get('/students/me/sessions/$sessionId') as Map<String, dynamic>);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session details')),
      body: AsyncView<SessionItem>(
        load: _load,
        builder: (context, s) {
          Widget row(IconData icon, String label, String value) =>
              ListTile(leading: Icon(icon), title: Text(label), subtitle: Text(value));
          return [
            Text(s.subjectName, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: StatusChip(s.status)),
            const SizedBox(height: 12),
            Card(
              child: Column(children: [
                row(Icons.event, 'Date', DateFormat('EEEE, d MMMM y').format(s.date)),
                row(Icons.schedule, 'Time', s.timeRange),
                row(Icons.person, 'Teacher', s.teacherName),
                row(Icons.meeting_room, 'Room', s.room ?? 'To be announced'),
                row(Icons.groups, 'Batch', s.batch),
              ]),
            ),
          ];
        },
      ),
    );
  }
}
