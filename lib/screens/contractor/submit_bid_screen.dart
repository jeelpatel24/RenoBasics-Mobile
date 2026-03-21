import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/utils/app_toast.dart';
import 'package:renobasic/services/bid_service.dart';
import 'package:renobasic/services/notification_service.dart';

class SubmitBidScreen extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> project;
  final Map<String, dynamic>? privateDetails;

  const SubmitBidScreen({
    super.key,
    required this.projectId,
    required this.project,
    this.privateDetails,
  });

  @override
  State<SubmitBidScreen> createState() => _SubmitBidScreenState();
}

class _SubmitBidScreenState extends State<SubmitBidScreen> {
  final List<Map<String, dynamic>> _items = [{'description': '', 'cost': 0.0}];
  final _timelineController = TextEditingController();
  final _notesController = TextEditingController();
  bool _submitting = false;

  double get _totalCost => _items.fold(0, (sum, item) => sum + (item['cost'] as double));

  void _addItem() => setState(() => _items.add({'description': '', 'cost': 0.0}));

  void _removeItem(int index) {
    if (_items.length > 1) setState(() => _items.removeAt(index));
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final user = auth.userProfile;
    if (user == null) return;

    // Validate
    for (final item in _items) {
      if ((item['description'] as String).trim().isEmpty || (item['cost'] as double) <= 0) {
        AppToast.show(context, 'Please fill in all bid items with valid costs', isError: true);
        return;
      }
    }
    if (_timelineController.text.trim().isEmpty) {
      AppToast.show(context, 'Please provide an estimated timeline', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final homeownerUid = widget.project['homeownerUid'] as String? ?? '';
      await BidService.submitBid(
        contractorUid: user.uid,
        homeownerUid: homeownerUid,
        projectId: widget.projectId,
        contractorName: user.fullName,
        projectCategory: widget.project['categoryName'] ?? '',
        itemizedCosts: _items,
        totalCost: _totalCost,
        estimatedTimeline: _timelineController.text.trim(),
        notes: _notesController.text.trim(),
      );
      // Notify homeowner of the new bid (non-fatal)
      if (homeownerUid.isNotEmpty) {
        await NotificationService.createNotification(
          recipientUid: homeownerUid,
          type: 'bid_received',
          title: 'New Bid Received',
          message:
              '${user.fullName} submitted a bid of \$${_totalCost.toStringAsFixed(2)} for your ${widget.project['categoryName'] ?? 'project'}.',
          relatedId: widget.projectId,
        );
      }
      if (mounted) AppToast.show(context, 'Bid submitted successfully!');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppToast.show(context, 'Failed to submit bid', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Submit Bid')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.project['categoryName'] ?? 'Project', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Budget: ${widget.project['budgetLabel'] ?? ''}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Itemized costs
            const Text('Itemized Costs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Description', isDense: true),
                        onChanged: (v) => _items[index]['description'] = v,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Cost (\$)', isDense: true),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() => _items[index]['cost'] = double.tryParse(v) ?? 0.0),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.remove_circle, color: Colors.red[400]),
                      onPressed: () => _removeItem(index),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Item'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFF97316)),
            ),
            const SizedBox(height: 12),

            // Total
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)),
              child: Text('Total: \$${_totalCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF97316))),
            ),
            const SizedBox(height: 16),

            // Timeline
            TextField(
              controller: _timelineController,
              decoration: const InputDecoration(labelText: 'Estimated Timeline', hintText: 'e.g., 3–4 weeks'),
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'Any additional notes...'),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Submit Bid (\$${_totalCost.toStringAsFixed(2)})'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
