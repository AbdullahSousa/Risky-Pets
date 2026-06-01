import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:risky_pets/guest_id.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  String? _effectiveUserId;
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    if (_user != null) {
      setState(() {
        _effectiveUserId = _user!.uid;
        _isGuest = false;
      });
    } else {
      final guestId = await GuestId.get();
      setState(() {
        _effectiveUserId = guestId;
        _isGuest = true;
      });
    }
  }

  // ── Risk level helpers ───────────────────────────────────────────────────────

  Color _riskColor(String level) => switch (level.toUpperCase()) {
        'LOW'      => Colors.green,
        'MODERATE' => Colors.orange,
        'HIGH'     => Colors.deepOrange,
        _          => Colors.red,
      };

  IconData _riskIcon(String level) => switch (level.toUpperCase()) {
        'LOW'      => Icons.check_circle,
        'MODERATE' => Icons.warning_amber,
        'HIGH'     => Icons.error,
        _          => Icons.local_hospital,
      };

  // ── Detail bottom sheet ──────────────────────────────────────────────────────

  void _showDetail(Map<String, dynamic> data) {
    final riskLevel = (data['riskLevel'] as String? ?? 'UNKNOWN').toUpperCase();
    final color = _riskColor(riskLevel);

    // Parse health flags stored as a list of maps
    final rawFlags = data['healthFlags'] as List<dynamic>? ?? [];
    final healthFlags = rawFlags
        .whereType<Map>()
        .map((f) => {'issue': f['issue'] ?? '', 'severity': f['severity'] ?? ''})
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Risk badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    riskLevel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Image
              if ((data['imageUrl'] as String?)?.isNotEmpty == true)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    data['imageUrl'] as String,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              const Divider(),

              // ── Animal & bite risk ───────────────────────────────────────
              _detailRow(Icons.pets, 'Animal',
                  data['detectedSpecies'] as String? ?? '-'),
              _detailRow(
                Icons.warning_amber,
                'Bite Risk',
                data['biteRiskLevel'] as String? ?? '-',
                valueColor: switch (
                    (data['biteRiskLevel'] as String? ?? '').toLowerCase()) {
                  'high'   => Colors.red,
                  'medium' => Colors.orange,
                  _        => Colors.green,
                },
              ),

              const Divider(),

              // ── User inputs ──────────────────────────────────────────────
              _detailRow(Icons.touch_app, 'Interaction',
                  (data['interactionType'] as String? ?? '-').toUpperCase()),
              _detailRow(Icons.bloodtype, 'Broke skin',
                  data['brokeSkin'] == true ? 'Yes' : 'No'),
              _detailRow(Icons.medical_services, 'Deep puncture',
                  data['deepPuncture'] == true ? 'Yes' : 'No'),
              _detailRow(Icons.water_drop, 'Lesion oozing',
                  data['lesionOozing'] == true ? 'Yes' : 'No'),
              _detailRow(Icons.warning, 'Rabies signs',
                  data['rabiesSigns'] == true ? 'Yes' : 'No'),

              // ── Health flags from Gemini ─────────────────────────────────
              if (healthFlags.isNotEmpty) ...[
                const Divider(),
                const Text(
                  'Health Flags',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                ...healthFlags.map((f) => _healthFlagRow(
                      f['issue'] as String,
                      f['severity'] as String,
                    )),
              ],

              const Divider(),

              // ── Gemini assessment text ───────────────────────────────────
              if ((data['answer'] as String?)?.isNotEmpty == true) ...[
                const Text(
                  'Assessment',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(data['answer'] as String,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
              ],

              // ── Advice box ───────────────────────────────────────────────
              if ((data['userAction'] as String?)?.isNotEmpty == true)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.medical_services, color: color, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data['userAction'] as String,
                          style: TextStyle(
                              color: color, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Note ────────────────────────────────────────────────────
              if ((data['note'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text('Note: ${data['note']}',
                    style: TextStyle(color: Colors.grey[700])),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Row helpers ──────────────────────────────────────────────────────────────

  Widget _detailRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value,
                style: TextStyle(color: valueColor),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _healthFlagRow(String issue, String severity) {
    final Color sc = switch (severity.toLowerCase()) {
      'high'   => Colors.red,
      'medium' => Colors.orange,
      _        => Colors.green,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: sc),
          const SizedBox(width: 8),
          Expanded(
              child: Text(issue, style: const TextStyle(fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: sc.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(severity,
                style: TextStyle(
                    fontSize: 11, color: sc, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[300],
        title: const Text('Scan History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _effectiveUserId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: () {
                var q = FirebaseFirestore.instance
                    .collection('scans')
                    .where('userId', isEqualTo: _effectiveUserId);
                if (_isGuest) q = q.where('isGuest', isEqualTo: true);
                return q.orderBy('timestamp', descending: true).snapshots();
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  // Friendly message for missing Firestore index
                  final err = snapshot.error.toString();
                  final isIndex = err.contains('index') ||
                      err.contains('FAILED_PRECONDITION');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(
                            isIndex
                                ? 'Database index not ready yet.\nPlease wait a moment and try again.'
                                : 'Failed to load history.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No scans yet.',
                            style: TextStyle(
                                fontSize: 18, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Text(
                          'Run your first assessment on the Home screen.',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final data =
                        docs[index].data() as Map<String, dynamic>;
                    final riskLevel =
                        (data['riskLevel'] as String? ?? 'UNKNOWN')
                            .toUpperCase();
                    final color = _riskColor(riskLevel);
                    final timestamp = data['timestamp'] as Timestamp?;
                    final date = timestamp != null
                        ? _formatDate(timestamp.toDate())
                        : 'Unknown date';

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showDetail(data),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Image thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: (data['imageUrl'] as String?)
                                              ?.isNotEmpty ==
                                          true
                                      ? Image.network(
                                          data['imageUrl'] as String,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.pets,
                                                    size: 30),
                                              ),
                                        )
                                      : Container(
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.pets,
                                              size: 30),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(_riskIcon(riskLevel),
                                            color: color, size: 16),
                                        const SizedBox(width: 4),
                                        Text(riskLevel,
                                            style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.bold)),
                                        const Spacer(),
                                        Text(date,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500])),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Animal · interaction
                                    Text(
                                      '${data['detectedSpecies'] ?? '-'} · '
                                      '${(data['interactionType'] as String? ?? '').toUpperCase()}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    // Short answer preview
                                    Text(
                                      data['answer'] as String? ?? '',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}