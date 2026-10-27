import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<Profile> _load() async => Profile.fromJson(await ApiClient.instance.get('/students/me') as Map<String, dynamic>);

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok == true) await ApiClient.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: AsyncView<Profile>(
        load: _load,
        builder: (context, p) {
          final initials = p.fullName.trim().split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
          return [
            const SizedBox(height: 12),
            Center(child: CircleAvatar(radius: 44, child: Text(initials, style: const TextStyle(fontSize: 28)))),
            const SizedBox(height: 12),
            Center(child: Text(p.fullName, style: Theme.of(context).textTheme.headlineSmall)),
            const SizedBox(height: 20),
            Card(
              child: Column(children: [
                ListTile(leading: const Icon(Icons.badge), title: const Text('Roll number'), subtitle: Text(p.rollNo)),
                ListTile(leading: const Icon(Icons.email), title: const Text('Email'), subtitle: Text(p.email)),
                ListTile(leading: const Icon(Icons.groups), title: const Text('Batch'), subtitle: Text(p.batch ?? 'Not assigned')),
              ]),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(onPressed: () => _confirmLogout(context), icon: const Icon(Icons.logout), label: const Text('Log out')),
          ];
        },
      ),
    );
  }
}
