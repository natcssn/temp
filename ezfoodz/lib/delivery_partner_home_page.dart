import 'dart:async';

import 'package:flutter/material.dart';

import 'delivery_service.dart';
import 'delivery_partner_login_page.dart';

class DeliveryPartnerHomePage extends StatefulWidget {
  const DeliveryPartnerHomePage({super.key});

  @override
  State<DeliveryPartnerHomePage> createState() => _DeliveryPartnerHomePageState();
}

class _DeliveryPartnerHomePageState extends State<DeliveryPartnerHomePage> {
  int currentTab = 0;
  bool loading = true;
  bool actionLoading = false;
  String? error;
  List availableOrders = [];
  List activeOrders = [];
  List completedOrders = [];
  int completedDeliveries = 0;
  double totalEarnings = 0;
  Timer? pollTimer;

  @override
  void initState() {
    super.initState();
    refreshAll();
    pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => refreshAll(showLoader: false));
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshAll({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    final available = await DeliveryService.availableOrders();
    final active = await DeliveryService.activeOrders();
    final earnings = await DeliveryService.earningsSummary();

    if (!mounted) return;

    if (!available['success'] || !active['success'] || !earnings['success']) {
      final err = available['error'] ?? active['error'] ?? earnings['error'] ?? 'Failed to refresh delivery data';
      if ((err as String).toLowerCase().contains('invalid token')) {
        await DeliveryService.clearSession();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DeliveryPartnerLoginPage()),
          (_) => false,
        );
        return;
      }

      setState(() {
        loading = false;
        error = err;
      });
      return;
    }

    setState(() {
      loading = false;
      error = null;
      availableOrders = available['orders'] as List;
      activeOrders = active['orders'] as List;
      completedDeliveries = (earnings['deliveries'] as num?)?.toInt() ?? 0;
      totalEarnings = (earnings['earnings'] as num?)?.toDouble() ?? 0;
      completedOrders = (earnings['orders'] as List?) ?? const [];
    });
  }

  Future<void> _withAction(Future<Map<String, dynamic>> Function() fn, String successMessage) async {
    if (actionLoading) return;

    setState(() {
      actionLoading = true;
      error = null;
    });

    final result = await fn();
    if (!mounted) return;

    if (!result['success']) {
      setState(() {
        actionLoading = false;
        error = result['error'] ?? 'Action failed';
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    await refreshAll(showLoader: false);
    if (mounted) {
      setState(() => actionLoading = false);
    }
  }

  Future<void> logout() async {
    await DeliveryService.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DeliveryPartnerLoginPage()),
      (_) => false,
    );
  }

  String _stageText(Map<String, dynamic> order) {
    final stage = (order['delivery_stage'] ?? '').toString();
    if (stage == 'picked_up') return 'Picked Up';
    if (stage == 'assigned') return 'Assigned';
    return 'Ready for Delivery';
  }

  Widget _orderCard(Map<String, dynamic> order, {bool showAccept = false, bool showActiveActions = false}) {
    final stage = _stageText(order);
    final orderId = (order['id'] as num).toInt();
    final deliveryStage = (order['delivery_stage'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD5B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order['secret_code']?.toString() ?? '#----',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1C1008)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E8),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(stage, style: const TextStyle(color: Color(0xFFB55A2A), fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Show customer details for active orders, restaurant details for available orders
          if (showActiveActions) ...[
            // Customer details section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE8D6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customer Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFFF6B35))),
                  const SizedBox(height: 8),
                  _customerDetailRow(Icons.person_outline, 'Name', order['customer_name']?.toString() ?? 'N/A'),
                  const SizedBox(height: 6),
                  _customerDetailRow(Icons.phone_outlined, 'Phone', order['customer_phone']?.toString() ?? 'N/A'),
                  const SizedBox(height: 6),
                  _customerDetailRow(Icons.apartment_outlined, 'Hostel', (order['customer_hostel']?.toString() ?? 'N/A').toUpperCase()),
                  const SizedBox(height: 6),
                  _customerDetailRow(Icons.school_outlined, 'College', order['customer_college']?.toString() ?? 'N/A'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Also show restaurant name for reference
            Row(
              children: [
                const Icon(Icons.restaurant, size: 14, color: Color(0xFF7A5C45)),
                const SizedBox(width: 6),
                Text('From: ${order['restaurant_name']?.toString() ?? ''}', style: const TextStyle(color: Color(0xFF7A5C45), fontSize: 12)),
              ],
            ),
          ] else ...[
            // Restaurant details for available orders
            Text(order['restaurant_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1C1008))),
            if ((order['restaurant_address'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 6),
                child: Text('From: ${order['restaurant_address']}', style: const TextStyle(color: Color(0xFF7A5C45), fontSize: 12)),
              ),
            // Destination hostel & college
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE8D6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFFFF6B35)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Deliver to: ${(order['customer_hostel']?.toString() ?? 'N/A').toUpperCase()} (${order['customer_college']?.toString() ?? 'N/A'})',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1C1008)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order #$orderId', style: const TextStyle(color: Color(0xFF7A5C45), fontSize: 12)),
              Text(
                '₹${(order['total'] as num?)?.toStringAsFixed(0) ?? '0'}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF27AE60)),
              ),
            ],
          ),
          if (showAccept) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: actionLoading
                    ? null
                    : () => _withAction(
                          () => DeliveryService.acceptOrder(orderId),
                          'Order accepted',
                        ),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60), foregroundColor: Colors.white),
                child: const Text('Accept Delivery'),
              ),
            ),
          ],
          if (showActiveActions) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: deliveryStage == 'picked_up'
                  ? ElevatedButton(
                      onPressed: actionLoading
                          ? null
                          : () => _withAction(
                                () => DeliveryService.completeOrder(orderId),
                                'Delivery marked complete',
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF27AE60),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Complete Delivery', style: TextStyle(fontWeight: FontWeight.w700)),
                    )
                  : ElevatedButton(
                      onPressed: actionLoading
                          ? null
                          : () => _withAction(
                                () => DeliveryService.pickupOrder(orderId),
                                'Marked as picked up',
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Picked Up', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _customerDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFB8967A)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Color(0xFF7A5C45), fontSize: 12, fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(value, style: const TextStyle(color: Color(0xFF1C1008), fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildAvailableTab() {
    if (availableOrders.isEmpty) {
      return const Center(child: Text('No available delivery orders right now'));
    }

    return RefreshIndicator(
      onRefresh: () => refreshAll(showLoader: false),
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: availableOrders.map<Widget>((o) => _orderCard(o as Map<String, dynamic>, showAccept: true)).toList(),
      ),
    );
  }

  Widget _buildActiveTab() {
    if (activeOrders.isEmpty) {
      return const Center(child: Text('No active delivery orders yet'));
    }

    return RefreshIndicator(
      onRefresh: () => refreshAll(showLoader: false),
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: activeOrders.map<Widget>((o) => _orderCard(o as Map<String, dynamic>, showActiveActions: true)).toList(),
      ),
    );
  }

  Widget _buildEarningsTab() {
    return RefreshIndicator(
      onRefresh: () => refreshAll(showLoader: false),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Profile block
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD5B8)),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFDFC), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_pin_rounded, color: Color(0xFFFF6B35), size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Delivery Partner Profile',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1C1008)),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFFFFE8D6), height: 24, thickness: 1),
                _profileDetailRow(Icons.person_outline, 'Name', DeliveryService.name ?? 'N/A'),
                const SizedBox(height: 8),
                _profileDetailRow(Icons.email_outlined, 'Email', DeliveryService.email ?? 'N/A'),
                const SizedBox(height: 8),
                _profileDetailRow(Icons.phone_outlined, 'Phone', (DeliveryService.phone ?? '').isEmpty ? 'Not provided' : DeliveryService.phone!),
                const SizedBox(height: 8),
                _profileDetailRow(Icons.wc_outlined, 'Gender', DeliveryService.gender ?? 'N/A'),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD5B8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Completed Deliveries', style: TextStyle(color: Color(0xFF7A5C45))),
                const SizedBox(height: 8),
                Text(
                  '$completedDeliveries',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFF1C1008)),
                ),
                const SizedBox(height: 16),
                const Text('Total Earnings', style: TextStyle(color: Color(0xFF7A5C45))),
                const SizedBox(height: 8),
                Text(
                  '₹${totalEarnings.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFF27AE60)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Bank ID section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD5B8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bank Account ID', style: TextStyle(color: Color(0xFF7A5C45), fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                  'Add your bank account ID so your earnings can reach you',
                  style: TextStyle(color: Color(0xFFB8967A), fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.account_balance_outlined, color: Color(0xFFFF6B35), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (DeliveryService.bankId ?? '').isEmpty
                            ? 'Not set'
                            : DeliveryService.bankId!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: (DeliveryService.bankId ?? '').isEmpty
                              ? const Color(0xFFB8967A)
                              : const Color(0xFF1C1008),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: actionLoading ? null : _showBankIdDialog,
                      icon: const Icon(Icons.edit_outlined, color: Color(0xFFFF6B35), size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Completed Deliveries History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1C1008)),
            ),
          ),
          if (completedOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD5B8)),
              ),
              child: const Center(
                child: Text('No completed deliveries yet', style: TextStyle(color: Color(0xFFB8967A))),
              ),
            )
          else
            ...completedOrders.map<Widget>((order) {
              final dateStr = (order['delivery_completed_at'] ?? order['created_at'] ?? '').toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD5B8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          order['secret_code']?.toString() ?? '#----',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1C1008)),
                        ),
                        Text(
                          '₹${(order['delivery_fee'] ?? 20.0).toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF27AE60), fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.restaurant_menu_outlined, size: 14, color: Color(0xFF7A5C45)),
                        const SizedBox(width: 6),
                        Text(order['restaurant_name']?.toString() ?? '', style: const TextStyle(color: Color(0xFF7A5C45), fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const Divider(color: Color(0xFFFFE8D6), height: 16),
                    const Text(
                      'Customer Details',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFFFF6B35), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    _profileDetailRow(Icons.person_outline, 'Name', order['customer_name']?.toString() ?? 'N/A'),
                    const SizedBox(height: 4),
                    _profileDetailRow(Icons.phone_outlined, 'Phone', order['customer_phone']?.toString() ?? 'N/A'),
                    const SizedBox(height: 4),
                    _profileDetailRow(Icons.apartment_outlined, 'Hostel', (order['customer_hostel']?.toString() ?? 'N/A').toUpperCase()),
                    const SizedBox(height: 4),
                    _profileDetailRow(Icons.school_outlined, 'College', order['customer_college']?.toString() ?? 'N/A'),
                    if ((order['customer_identification'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _profileDetailRow(Icons.info_outline, 'ID Details', order['customer_identification']?.toString() ?? ''),
                    ],
                    const Divider(color: Color(0xFFFFE8D6), height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order ID: ${order['id']}', style: const TextStyle(color: Color(0xFFB8967A), fontSize: 11)),
                        Text(dateStr, style: const TextStyle(color: Color(0xFFB8967A), fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _profileDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFB8967A)),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(color: Color(0xFF7A5C45), fontSize: 13, fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Color(0xFF1C1008), fontSize: 14, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showBankIdDialog() {
    final controller = TextEditingController(text: DeliveryService.bankId ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Bank Account ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your bank account ID',
            prefixIcon: Icon(Icons.account_balance_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _withAction(
                () => DeliveryService.updateBankId(controller.text.trim()),
                'Bank ID updated',
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFE74C3C))),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: refreshAll, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (currentTab == 0) return _buildAvailableTab();
    if (currentTab == 1) return _buildActiveTab();
    return _buildEarningsTab();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text('Delivery Partner'),
        actions: [
          IconButton(onPressed: () => refreshAll(showLoader: false), icon: const Icon(Icons.refresh)),
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentTab,
        onTap: (value) => setState(() => currentTab = value),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping_outlined), label: 'Available'),
          BottomNavigationBarItem(icon: Icon(Icons.route_outlined), label: 'Active'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Earnings'),
        ],
      ),
    );
  }
}
