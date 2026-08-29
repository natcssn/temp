import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';
import 'auth_service.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  _OrderHistoryPageState createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  List orders = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/orders/user/history"),
        headers: AuthService.authHeaders(),
      );
      if (r.statusCode == 200) {
        setState(() { orders = jsonDecode(r.body)['orders']; loading = false; });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order History 📋')),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : orders.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('📋', style: TextStyle(fontSize: 52)),
                      SizedBox(height: 14),
                      Text('No orders yet', style: TextStyle(color: Color(0xFF7A5C45), fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(height: 6),
                      Text('Your completed orders will appear here', style: TextStyle(color: Color(0xFFB8967A), fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: load,
                  color: const Color(0xFFFF6B35),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (_, i) {
                      final order = orders[i];
                      final items = (order['items'] as List?) ?? [];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE8F4FD)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2980B9).withValues(alpha: 0.07),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  order['secret_code'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2980B9),
                                    fontFamily: 'Courier',
                                    letterSpacing: 2,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF4FB),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: const Text(
                                    '✓ COMPLETED',
                                    style: TextStyle(color: Color(0xFF2980B9), fontSize: 11, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...items.map<Widget>((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${item['item_name']} × ${item['quantity']}',
                                    style: const TextStyle(color: Color(0xFF7A5C45), fontSize: 13),
                                  ),
                                  Text(
                                    '₹${((item['price'] as num) * (item['quantity'] as num)).toStringAsFixed(0)}',
                                    style: const TextStyle(color: Color(0xFF7A5C45), fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            )),
                            const Divider(color: Color(0xFFFFD5B8), height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  order['restaurant_name'] ?? '',
                                  style: const TextStyle(color: Color(0xFFB8967A), fontSize: 12),
                                ),
                                Text(
                                  '₹${order['total']}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1C1008)),
                                ),
                              ],
                            ),
                            if (order['created_at'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  order['created_at'].toString().length >= 16
                                      ? order['created_at'].toString().substring(0, 16)
                                      : order['created_at'].toString(),
                                  style: const TextStyle(color: Color(0xFFB8967A), fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
