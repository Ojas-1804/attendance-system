import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_client.dart';
import 'models.dart';
import 'screens/session_detail_screen.dart';

Color levelColor(String level) {
  switch (level) {
    case 'HEALTHY':
      return const Color(0xFF2E7D32); // green
    case 'WARNING':
      return const Color(0xFFF9A825); // yellow
    case 'LOW':
      return const Color(0xFFC62828); // red
    default:
      return Colors.grey;
  }
}

String levelText(String level) {
  switch (level) {
    case 'HEALTHY':
      return 'Healthy';
    case 'WARNING':
      return 'Warning';
    case 'LOW':
      return 'Low';
    default:
      return 'No data yet';
  }
}

/// Loads data, shows loading / error (with retry) states, and supports pull-to-refresh.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final List<Widget> Function(BuildContext context, T data) builder;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future = widget.load();

  Future<void> _reload() async {
    final f = widget.load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final msg = snap.error is ApiException ? snap.error.toString() : 'Something went wrong. Please try again.';
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 80),
                const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
                const SizedBox(height: 16),
                Text(msg, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Center(child: FilledButton(onPressed: _reload, child: const Text('Retry'))),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(padding: const EdgeInsets.all(16), children: widget.builder(context, snap.data as T)),
        );
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ]),
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color color;
    switch (status) {
      case 'PRESENT':
        text = 'Present ✓';
        color = const Color(0xFF2E7D32);
      case 'ABSENT':
        text = 'Absent';
        color = const Color(0xFFC62828);
      case 'CANCELLED':
        text = 'Cancelled';
        color = Colors.grey;
      case 'PENDING':
        text = 'Pending';
        color = const Color(0xFFEF6C00);
      default:
        text = 'Upcoming';
        color = Colors.blueGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class SessionTile extends StatelessWidget {
  const SessionTile(this.item, {super.key, this.showDate = false});
  final SessionItem item;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final when = showDate ? '${DateFormat('d MMM').format(item.date)} · ${item.startTime}' : item.timeRange;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionDetailScreen(sessionId: item.id))),
        title: Text(item.subjectName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$when\n${item.room ?? 'Room TBA'} · ${item.teacherName}'),
        isThreeLine: true,
        trailing: StatusChip(item.status),
      ),
    );
  }
}

class WarningBanner extends StatelessWidget {
  const WarningBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFC62828).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC62828).withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFC62828)),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ]),
      );
}

class AttendanceBar extends StatelessWidget {
  const AttendanceBar(this.stat, {super.key});
  final Stat stat;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: ((stat.percentage ?? 0) / 100).clamp(0.0, 1.0),
          minHeight: 10,
          color: levelColor(stat.level),
          backgroundColor: Colors.grey.shade300,
        ),
      );
}
