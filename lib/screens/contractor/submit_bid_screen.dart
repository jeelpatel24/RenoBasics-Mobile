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
  // ── Contractor details ──────────────────────────────────────────
  final _companyNameCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();

  // ── Line items ──────────────────────────────────────────────────
  // Each item: {description: '', qty: 1, unitPrice: 0.0}
  final List<Map<String, dynamic>> _items = [
    {'description': '', 'qty': 1, 'unitPrice': 0.0},
  ];

  // ── Tax & other ─────────────────────────────────────────────────
  int _taxRate = 0; // 0, 5, 13, 15
  final _timelineCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  // ── Computed totals ─────────────────────────────────────────────
  double get _subtotal => _items.fold(0.0, (sum, item) {
        final qty = (item['qty'] as int? ?? 1);
        final price = (item['unitPrice'] as double? ?? 0.0);
        return sum + qty * price;
      });

  double get _taxAmount => _subtotal * _taxRate / 100;
  double get _totalAmount => _subtotal + _taxAmount;

  static const Color _orange = Color(0xFFF97316);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().userProfile;
      if (user != null) {
        _companyNameCtrl.text = user.companyName ?? '';
        _contactNameCtrl.text = user.contactName ?? user.fullName;
        _contactEmailCtrl.text = user.email;
        _contactPhoneCtrl.text = user.phone;
      }
    });
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _timelineCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add({'description': '', 'qty': 1, 'unitPrice': 0.0}));
  }

  void _removeItem(int index) {
    if (_items.length > 1) setState(() => _items.removeAt(index));
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final user = auth.userProfile;
    if (user == null) return;

    // Validate
    for (final item in _items) {
      final desc = (item['description'] as String).trim();
      final price = item['unitPrice'] as double? ?? 0.0;
      final qty = item['qty'] as int? ?? 0;
      if (desc.isEmpty || price <= 0 || qty <= 0) {
        AppToast.show(
          context,
          'Please fill in all line items with valid quantities and prices',
          isError: true,
        );
        return;
      }
    }
    if (_timelineCtrl.text.trim().isEmpty) {
      AppToast.show(context, 'Please provide an estimated timeline', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final homeownerUid = widget.project['homeownerUid'] as String? ?? '';

      // Build line items with subtotals
      final lineItems = _items.map<Map<String, dynamic>>((item) {
        final qty = item['qty'] as int? ?? 1;
        final unitPrice = item['unitPrice'] as double? ?? 0.0;
        return <String, dynamic>{
          'description': item['description'] as String,
          'qty': qty,
          'unitPrice': unitPrice,
          'subtotal': qty * unitPrice,
        };
      }).toList();

      // Legacy itemizedCosts for backward compat
      final legacyCosts = lineItems
          .map<Map<String, dynamic>>((item) => <String, dynamic>{
                'description': item['description'] as String,
                'cost': item['subtotal'] as double,
              })
          .toList();

      await BidService.submitBid(
        contractorUid: user.uid,
        homeownerUid: homeownerUid,
        projectId: widget.projectId,
        contractorName: user.fullName,
        projectCategory: widget.project['categoryName'] ?? '',
        companyName: _companyNameCtrl.text.trim(),
        contactName: _contactNameCtrl.text.trim(),
        contactEmail: _contactEmailCtrl.text.trim(),
        contactPhone: _contactPhoneCtrl.text.trim(),
        lineItems: lineItems,
        subtotal: _subtotal,
        taxRate: _taxRate,
        taxAmount: _taxAmount,
        totalAmount: _totalAmount,
        itemizedCosts: legacyCosts,
        totalCost: _totalAmount,
        estimatedTimeline: _timelineCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      );

      if (homeownerUid.isNotEmpty) {
        await NotificationService.createNotification(
          recipientUid: homeownerUid,
          type: 'bid_received',
          title: 'New Bid Received',
          message:
              '${user.fullName} submitted a bid of \$${_totalAmount.toStringAsFixed(2)} for your ${widget.project['categoryName'] ?? 'project'}.',
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
      appBar: AppBar(
        title: const Text('Submit Invoice Bid'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project Info Banner
            _projectBanner(),
            const SizedBox(height: 16),

            // Section 1: Contractor Details
            _sectionCard(
              icon: Icons.business_outlined,
              title: 'Contractor Details',
              children: [
                _field(_companyNameCtrl, 'Company Name'),
                const SizedBox(height: 12),
                _field(_contactNameCtrl, 'Contact Name'),
                const SizedBox(height: 12),
                _field(_contactEmailCtrl, 'Email', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _field(_contactPhoneCtrl, 'Phone Number', keyboardType: TextInputType.phone),
              ],
            ),
            const SizedBox(height: 16),

            // Section 2: Line Items
            _sectionCard(
              icon: Icons.receipt_long_outlined,
              title: 'Line Items',
              children: [
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 4, child: Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54))),
                      SizedBox(width: 8),
                      SizedBox(width: 44, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54))),
                      SizedBox(width: 8),
                      SizedBox(width: 74, child: Text('Unit Price', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54))),
                      SizedBox(width: 8),
                      SizedBox(width: 70, child: Text('Subtotal', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54))),
                      SizedBox(width: 32),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Line item rows
                ..._items.asMap().entries.map((entry) => _lineItemRow(entry.key)),
                const SizedBox(height: 8),

                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Line Item'),
                  style: TextButton.styleFrom(foregroundColor: _orange),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section 3: Invoice Summary
            _sectionCard(
              icon: Icons.summarize_outlined,
              title: 'Invoice Summary',
              children: [
                // Tax rate selector
                Row(
                  children: [
                    const Expanded(
                      child: Text('Tax Rate', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _taxRate,
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('No Tax (0%)')),
                            DropdownMenuItem(value: 5, child: Text('GST (5%)')),
                            DropdownMenuItem(value: 13, child: Text('HST (13%)')),
                            DropdownMenuItem(value: 15, child: Text('HST (15%)')),
                          ],
                          onChanged: (v) => setState(() => _taxRate = v ?? 0),
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Summary rows
                _summaryRow('Subtotal', _subtotal),
                if (_taxRate > 0) ...[
                  const SizedBox(height: 6),
                  _summaryRow('Tax ($_taxRate%)', _taxAmount, isSmall: true),
                ],
                const Divider(height: 20),
                _summaryRow('Total', _totalAmount, isTotal: true),
              ],
            ),
            const SizedBox(height: 16),

            // Section 4: Timeline & Notes
            _sectionCard(
              icon: Icons.schedule_outlined,
              title: 'Timeline & Notes',
              children: [
                _field(_timelineCtrl, 'Estimated Timeline *', hint: 'e.g., 3–4 weeks'),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: _dec('Notes (optional)', hint: 'Any additional notes...'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Submit Bid (\$${_totalAmount.toStringAsFixed(2)})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Project Banner ─────────────────────────────────────────────

  Widget _projectBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.project['projectTitle'] ?? widget.project['categoryName'] ?? 'Project',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Budget: ${widget.project['budgetLabel'] ?? ''}',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // ── Line Item Row ───────────────────────────────────────────────

  Widget _lineItemRow(int index) {
    final item = _items[index];
    final qty = item['qty'] as int? ?? 1;
    final unitPrice = item['unitPrice'] as double? ?? 0.0;
    final subtotal = qty * unitPrice;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Description
          Expanded(
            flex: 4,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Description',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) => _items[index]['description'] = v,
            ),
          ),
          const SizedBox(width: 6),
          // Qty
          SizedBox(
            width: 44,
            child: TextField(
              decoration: const InputDecoration(
                hintText: '1',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (v) => setState(() => _items[index]['qty'] = int.tryParse(v) ?? 1),
            ),
          ),
          const SizedBox(width: 6),
          // Unit Price
          SizedBox(
            width: 74,
            child: TextField(
              decoration: const InputDecoration(
                hintText: '0.00',
                isDense: true,
                prefixText: '\$',
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              onChanged: (v) => setState(() => _items[index]['unitPrice'] = double.tryParse(v) ?? 0.0),
            ),
          ),
          const SizedBox(width: 6),
          // Subtotal (read-only)
          SizedBox(
            width: 70,
            child: Text(
              '\$${subtotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          // Remove
          SizedBox(
            width: 32,
            child: IconButton(
              icon: Icon(Icons.remove_circle_outline, color: Colors.red[400], size: 20),
              onPressed: () => _removeItem(index),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary Row ─────────────────────────────────────────────────

  Widget _summaryRow(String label, double amount, {bool isTotal = false, bool isSmall = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : (isSmall ? 13 : 14),
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.black87 : Colors.black54,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 18 : (isSmall ? 13 : 14),
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? _orange : Colors.black87,
          ),
        ),
      ],
    );
  }

  // ── Section Card ────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _orange, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: _dec(label, hint: hint),
      style: const TextStyle(fontSize: 14),
    );
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _orange, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}
