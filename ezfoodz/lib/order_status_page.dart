import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'api_config.dart';
import 'auth_service.dart';
import 'restaurants_page.dart';

class OrderStatusPage extends StatefulWidget {
  final int? orderId;
  final String? secretCode;
  final String? restaurantName;

  const OrderStatusPage({super.key,
    this.orderId,
    this.secretCode,
    this.restaurantName,
  });

  @override
  _OrderStatusPageState createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> {
  List orders = [];
  bool loading = true;
  Timer? pollTimer;
  int? ackLoadingOrderId;
  int? pendingAckOrderId;
  int pendingAckSecondsLeft = 0;
  Timer? pendingAckTimer;

  @override
  void initState() {
    super.initState();
    loadOrders(showLoading: true);
    pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => loadOrders());
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    pendingAckTimer?.cancel();
    super.dispose();
  }

  Future<void> loadOrders({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() => loading = true);
    }

    try {
      final r = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/orders/user/active"),
        headers: AuthService.authHeaders(),
      );
      if (r.statusCode == 200 && mounted) {
        final decoded = jsonDecode(r.body);
        final activeOrders = decoded['orders'] is List ? decoded['orders'] : [];
        setState(() => orders = activeOrders);
      }
    } catch (_) {
      if (mounted && showLoading) {
        setState(() => orders = []);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> acknowledgeOrder(int orderId) async {
    if (ackLoadingOrderId != null) return;
    setState(() => ackLoadingOrderId = orderId);
    try {
      final r = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/orders/$orderId/acknowledge"),
        headers: AuthService.authHeaders(),
      );
      if (!mounted) return;
      if (r.statusCode == 200) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RestaurantsPage()),
          (_) => false,
        );
      } else {
        final err = jsonDecode(r.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err['detail'] ?? 'Could not acknowledge order')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error while acknowledging order')),
      );
    } finally {
      if (mounted) {
        setState(() {
          ackLoadingOrderId = null;
          pendingAckOrderId = null;
          pendingAckSecondsLeft = 0;
        });
      }
      pendingAckTimer?.cancel();
    }
  }

  void _startAcknowledgeConfirm(int orderId) {
    pendingAckTimer?.cancel();
    setState(() {
      pendingAckOrderId = orderId;
      pendingAckSecondsLeft = 5;
    });

    pendingAckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (pendingAckSecondsLeft <= 1) {
        timer.cancel();
        setState(() {
          pendingAckOrderId = null;
          pendingAckSecondsLeft = 0;
        });
        return;
      }

      setState(() => pendingAckSecondsLeft--);
    });
  }

  void _onAcknowledgePressed(int orderId) {
    if (ackLoadingOrderId != null) return;

    if (pendingAckOrderId != orderId || pendingAckSecondsLeft <= 0) {
      _startAcknowledgeConfirm(orderId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap again within 5 seconds to confirm order received')),
      );
      return;
    }

    acknowledgeOrder(orderId);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ready': return const Color(0xFF27AE60);
      case 'given': return const Color(0xFF2980B9);
      default: return const Color(0xFFF39C12);
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'ready': return const Color(0xFFE8F8F0);
      case 'given': return const Color(0xFFEAF4FB);
      default: return const Color(0xFFFEF9EC);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'ready': return Icons.check_circle_rounded;
      case 'given': return Icons.done_all_rounded;
      default: return Icons.restaurant_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ready': return '✅ Ready for pickup!';
      case 'given': return '🎉 Order completed';
      default: return '👨‍🍳 Being prepared...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Status')),
      body: loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFF6B35)),
                  SizedBox(height: 16),
                  Text('Loading your orders...', style: TextStyle(color: Color(0xFF7A5C45))),
                ],
              ),
            )
          : orders.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🧾', style: TextStyle(fontSize: 52)),
                        const SizedBox(height: 12),
                        const Text(
                          'No active orders right now',
                          style: TextStyle(
                            color: Color(0xFF1C1008),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Place a new order and you can track it here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF7A5C45), fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const RestaurantsPage()),
                            (_) => false,
                          ),
                          icon: const Icon(Icons.storefront_rounded),
                          label: const Text('Browse Restaurants'),
                        ),
                      ],
                    ),
                  ),
                )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (_, i) => _orderCard(orders[i]),
            ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'preparing';
    final fulfillmentMode = order['fulfillment_mode'] ?? 'pickup';
    final deliveryStage = order['delivery_stage'] ?? 'not_required';
    
    final color = _statusColor(status);
    final bgColor = _statusBgColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Secret code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Text(
                  order['secret_code'] ?? '',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: color,
                    fontFamily: 'Courier',
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Show this code at the counter',
                  style: TextStyle(color: Color(0xFF7A5C45), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon(status), color: color, size: 22),
                const SizedBox(width: 8),
                Text(
                  _statusLabel(status),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
          ),
          if (fulfillmentMode == 'delivery') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delivery_dining, color: Color(0xFFFF6B35), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _deliveryStageLabel(deliveryStage),
                    style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Show delivery partner details if assigned
            if ((order['delivery_partner_name'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2980B9).withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.local_shipping_outlined, color: Color(0xFF2980B9), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Delivery Partner',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF2980B9)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _deliveryPartnerRow(Icons.person_outline, 'Name', order['delivery_partner_name']?.toString() ?? ''),
                    const SizedBox(height: 6),
                    _deliveryPartnerRow(Icons.phone_outlined, 'Phone', order['delivery_partner_phone']?.toString() ?? 'N/A'),
                    const SizedBox(height: 6),
                    _deliveryPartnerRow(Icons.email_outlined, 'Email', order['delivery_partner_email']?.toString() ?? 'N/A'),
                    const SizedBox(height: 6),
                    _deliveryPartnerRow(Icons.wc_outlined, 'Gender', order['delivery_partner_gender']?.toString() ?? 'N/A'),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),

          // Progress bar
          Row(
            children: [
              _statusStep('Preparing', true, status == 'preparing', color),
              Expanded(child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: (status == 'ready' || status == 'given') ? color : const Color(0xFFFFD5B8),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              _statusStep('Ready', status == 'ready' || status == 'given', status == 'ready', color),
              Expanded(child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: status == 'given' ? color : const Color(0xFFFFD5B8),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              _statusStep('Given', status == 'given', status == 'given', color),
            ],
          ),
          const SizedBox(height: 20),

          // Items
          ...((order['items'] as List?) ?? []).map<Widget>((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${item['item_name']} × ${item['quantity']}',
                  style: const TextStyle(color: Color(0xFF7A5C45), fontSize: 14),
                ),
                Text(
                  '₹${((item['price'] as num) * (item['quantity'] as num)).toStringAsFixed(0)}',
                  style: const TextStyle(color: Color(0xFF7A5C45), fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )),

          const Divider(color: Color(0xFFFFD5B8), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(order['restaurant_name'] ?? '', style: const TextStyle(color: Color(0xFFB8967A), fontSize: 13)),
              Text(
                'Total: ₹${order['total']}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1C1008)),
              ),
            ],
          ),
          if (status == 'given' && order['user_acknowledged'] != true) ...[
            const SizedBox(height: 14),
            const Text(
              'Confirm carefully: this removes the order from your active list.',
              style: TextStyle(color: Color(0xFF7A5C45), fontSize: 12),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: ackLoadingOrderId != null
                    ? null
                    : () => _onAcknowledgePressed(order['id'] as int),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pendingAckOrderId == order['id'] && pendingAckSecondsLeft > 0
                      ? const Color(0xFFF39C12)
                      : const Color(0xFF27AE60),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: ackLoadingOrderId == order['id']
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        pendingAckOrderId == order['id'] && pendingAckSecondsLeft > 0
                            ? 'Tap Again to Confirm (${pendingAckSecondsLeft}s)'
                            : 'Order Received',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusStep(String label, bool completed, bool active, Color color) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed ? color : const Color(0xFFFFD5B8),
            border: active ? Border.all(color: color, width: 3) : null,
            boxShadow: completed ? [
              BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1),
            ] : [],
          ),
          child: completed
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: completed ? color : const Color(0xFFB8967A),
          ),
        ),
      ],
    );
  }

  Widget _deliveryPartnerRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF7A9BBF)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Color(0xFF5A7A9B), fontSize: 12, fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(
            value.isEmpty ? 'N/A' : value,
            style: const TextStyle(color: Color(0xFF1C1008), fontSize: 13, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _deliveryStageLabel(String stage) {
    switch (stage) {
      case 'awaiting_assignment': return 'Waiting for delivery partner';
      case 'assigned': return 'Delivery partner assigned';
      case 'picked_up': return 'Picked up, on the way';
      case 'delivered': return 'Delivered';
      default: return 'Waiting for delivery partner';
    }
  }
}
