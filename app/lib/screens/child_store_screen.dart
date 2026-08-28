import 'package:flutter/material.dart';
import '../models/reward.dart';
import '../models/redemption.dart';
import '../services/api_service.dart';
import '../services/child_store_service.dart';

class ChildStoreScreen extends StatefulWidget {
  final ChildSession session;

  const ChildStoreScreen({super.key, required this.session});

  @override
  State<ChildStoreScreen> createState() => _ChildStoreScreenState();
}

class _ChildStoreScreenState extends State<ChildStoreScreen> {
  late final ChildStoreService _storeService;
  late Future<int> _balanceFuture;
  late Future<List<Reward>> _rewardsFuture;
  late Future<List<Redemption>> _myRequestsFuture;
  bool _showRequests = false;

  @override
  void initState() {
    super.initState();
    _storeService = ChildStoreService(widget.session.token);
    _reload();
  }

  void _reload() {
    setState(() {
      _balanceFuture = _storeService.fetchBalance();
      _rewardsFuture = _storeService.fetchRewards();
      _myRequestsFuture = _storeService.fetchMyRedemptions();
    });
  }

  Future<void> _requestReward(Reward reward, int balance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('בקשת פרס'),
        content: Text('לבקש את "${reward.name}" תמורת ${reward.costPoints} נקודות?\n'
            'הבקשה תישלח להורה לאישור.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('שליחת בקשה'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _storeService.requestRedemption(reward.id);
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הבקשה נשלחה! ממתינים לאישור ההורה 🎉')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
      }
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'ממתין לאישור';
      case 'APPROVED':
        return 'אושר!';
      case 'REJECTED':
        return 'נדחה';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('חנות פרסים'),
        actions: [
          IconButton(
            icon: Icon(_showRequests ? Icons.storefront : Icons.receipt_long_outlined),
            tooltip: _showRequests ? 'חזרה לחנות' : 'הבקשות שלי',
            onPressed: () => setState(() => _showRequests = !_showRequests),
          ),
        ],
      ),
      body: Column(
        children: [
          FutureBuilder<int>(
            future: _balanceFuture,
            builder: (context, snapshot) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'יש לך ${snapshot.data ?? '...'} נקודות',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: _showRequests ? _buildRequestsList() : _buildRewardsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsList() {
    return FutureBuilder<List<Reward>>(
      future: _rewardsFuture,
      builder: (context, rewardsSnapshot) {
        if (rewardsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (rewardsSnapshot.hasError) {
          return Center(child: Text('שגיאה בטעינה: ${rewardsSnapshot.error}'));
        }

        final rewards = rewardsSnapshot.data ?? [];
        if (rewards.isEmpty) {
          return const Center(child: Text('עדיין אין פרסים בחנות.'));
        }

        return FutureBuilder<int>(
          future: _balanceFuture,
          builder: (context, balanceSnapshot) {
            final balance = balanceSnapshot.data ?? 0;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rewards.length,
              itemBuilder: (context, index) {
                final reward = rewards[index];
                final canAfford = reward.costPoints <= balance;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(reward.name, style: const TextStyle(fontSize: 18)),
                    subtitle: Text('${reward.costPoints} נקודות'),
                    trailing: FilledButton(
                      onPressed: canAfford ? () => _requestReward(reward, balance) : null,
                      child: const Text('בקשה'),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsList() {
    return FutureBuilder<List<Redemption>>(
      future: _myRequestsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('שגיאה בטעינה: ${snapshot.error}'));
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return const Center(child: Text('עדיין לא ביקשת שום פרס.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final r = requests[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(r.rewardName),
                subtitle: Text('${r.pointsSpent} נקודות'),
                trailing: Chip(
                  label: Text(_statusLabel(r.status)),
                  backgroundColor: _statusColor(r.status).withValues(alpha: 0.15),
                  labelStyle: TextStyle(color: _statusColor(r.status)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
