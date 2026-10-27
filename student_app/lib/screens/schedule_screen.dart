import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import '../widgets.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Schedule'),
          bottom: const TabBar(tabs: [Tab(text: 'Today'), Tab(text: 'Tomorrow'), Tab(text: 'This week')]),
        ),
        body: const TabBarView(children: [
          _SchedulePage(range: 'today', emptyText: 'No classes today.'),
          _SchedulePage(range: 'tomorrow', emptyText: 'No classes tomorrow.'),
          _SchedulePage(range: 'week', emptyText: 'No classes this week.', grouped: true),
        ]),
      ),
    );
  }
}

class _SchedulePage extends StatelessWidget {
  const _SchedulePage({required this.range, required this.emptyText, this.grouped = false});

  final String range;
  final String emptyText;
  final bool grouped;

  Future<List<SessionItem>> _load() async {
    final data = await ApiClient.instance.get('/students/me/schedule', query: {'range': range}) as List;
    return data.map((e) => SessionItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<SessionItem>>(
      load: _load,
      builder: (context, items) {
        if (items.isEmpty) return [EmptyState(emptyText, icon: Icons.event_available)];
        if (!grouped) return items.map(SessionTile.new).toList();
        final widgets = <Widget>[];
        DateTime? current;
        for (final item in items) {
          if (current != item.date) {
            current = item.date;
            widgets.add(Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(DateFormat('EEEE, d MMM').format(item.date).toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
            ));
          }
          widgets.add(SessionTile(item));
        }
        return widgets;
      },
    );
  }
}
