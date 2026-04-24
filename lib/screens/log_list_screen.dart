import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LogListScreen extends StatelessWidget {
  const LogListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log List'),
        backgroundColor: const Color(0xFF1B1B4E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('checkin_logs')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No check-in logs yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final ts = data['createdAt'] as Timestamp?;
              final dateStr = ts != null
                  ? '${ts.toDate().toLocal()}'.split('.')[0]
                  : 'No date';

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  leading: data['photoUrl'] != null && data['photoUrl'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            data['photoUrl'],
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 40),
                          ),
                        )
                      : Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1B4E).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.store, color: Color(0xFF1B1B4E)),
                        ),
                  title: Text(
                    data['businessName'] ?? 'Unnamed',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if ((data['supplierName'] ?? '').toString().isNotEmpty)
                        Text('Supplier: ${data['supplierName']}', style: const TextStyle(fontSize: 12)),
                      if ((data['stockIssue'] ?? '').toString().isNotEmpty)
                        Text('Stock Issue: ${data['stockIssue']}', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                      Text('By: ${data['createdBy'] ?? '—'}   •   $dateStr',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF1B1B4E)),
                        onPressed: () => _showEditDialog(context, doc.id, data),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _confirmDelete(context, doc.id, data['businessName'] ?? 'this log'),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                  onTap: () => _showDetailDialog(context, data),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetailDialog(BuildContext context, Map<String, dynamic> data) {
    final ts = data['createdAt'] as Timestamp?;
    final dateStr = ts != null ? '${ts.toDate().toLocal()}'.split('.')[0] : 'No date';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(data['businessName'] ?? 'Log Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((data['photoUrl'] ?? '').toString().isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(data['photoUrl'], fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
                const SizedBox(height: 10),
              ],
              _detailRow('Note', data['note']),
              _detailRow('Created By', data['createdBy']),
              _detailRow('Supplier', data['supplierName']),
              _detailRow('Stock Issue', data['stockIssue']),
              _detailRow('Created At', dateStr),
              if (data['lat'] != null && data['lng'] != null)
                _detailRow('GPS', 'Lat: ${data['lat']},  Lng: ${data['lng']}'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value.toString()),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String docId, Map<String, dynamic> data) {
    final businessCtrl = TextEditingController(text: data['businessName'] ?? '');
    final noteCtrl = TextEditingController(text: data['note'] ?? '');
    final createdByCtrl = TextEditingController(text: data['createdBy'] ?? '');
    final stockCtrl = TextEditingController(text: data['stockIssue'] ?? '');
    final supplierCtrl = TextEditingController(text: data['supplierName'] ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Log'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _editField(businessCtrl, 'Business Name'),
                const SizedBox(height: 10),
                _editField(noteCtrl, 'Note', maxLines: 3),
                const SizedBox(height: 10),
                _editField(createdByCtrl, 'Created By'),
                const SizedBox(height: 10),
                _editField(stockCtrl, 'Stock Issue'),
                const SizedBox(height: 10),
                _editField(supplierCtrl, 'Supplier Name'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      await FirebaseFirestore.instance
                          .collection('checkin_logs')
                          .doc(docId)
                          .update({
                        'businessName': businessCtrl.text.trim(),
                        'note': noteCtrl.text.trim(),
                        'createdBy': createdByCtrl.text.trim(),
                        'stockIssue': stockCtrl.text.trim(),
                        'supplierName': supplierCtrl.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B1B4E), foregroundColor: Colors.white),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  TextField _editField(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Log'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('checkin_logs').doc(docId).delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
