import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';
import 'cart_page.dart';

class MenuPage extends StatefulWidget {
  final int restaurantId;
  final String restaurantName;
  const MenuPage(this.restaurantId, this.restaurantName, {super.key});

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  List items = [];
  Map<int, int> qty = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await http.get(Uri.parse("${ApiConfig.baseUrl}/menu/${widget.restaurantId}"));
      if (r.statusCode == 200) {
        setState(() { items = jsonDecode(r.body)['items']; loading = false; });
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  int get cartCount => qty.values.fold(0, (a, b) => a + b);

  String _categoryEmoji(String cat) {
    switch (cat) {
      case 'non-veg': return '🔴';
      case 'stationary': return '🔵';
      default: return '🟢';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.restaurantName)),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : items.isEmpty
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🍽️', style: TextStyle(fontSize: 52)),
                    SizedBox(height: 12),
                    Text('No items available', style: TextStyle(color: Color(0xFF7A5C45), fontSize: 16)),
                  ],
                ),
              )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final id = item['id'] as int;
                    final isAvailable = item['is_available'] == 1 || item['is_available'] == true;
                    qty.putIfAbsent(id, () => 0);

                    return Opacity(
                      opacity: isAvailable ? 1.0 : 0.5,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFD5B8)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B35).withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Category dot
                            Text(_categoryEmoji(item['category'] ?? 'veg'), style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 12),
                            // Item info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'],
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1C1008)),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      if (item['cuisine'] != null && item['cuisine'].toString().isNotEmpty)
                                        Text(
                                          item['cuisine'],
                                          style: const TextStyle(color: Color(0xFF7A5C45), fontSize: 12),
                                        ),
                                      if (!isAvailable)
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFEBEB),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('Out of Stock', style: TextStyle(color: Color(0xFFE74C3C), fontSize: 10, fontWeight: FontWeight.w700)),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Price
                            Text(
                              '₹${item['price']}',
                              style: const TextStyle(
                                color: Color(0xFFFF6B35),
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Quantity control
                            if (isAvailable)
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0E6),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFFD5B8)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () { if (qty[id]! > 0) setState(() => qty[id] = qty[id]! - 1); },
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(Icons.remove_rounded, color: Color(0xFFE74C3C), size: 18),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        '${qty[id]}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1C1008)),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => setState(() => qty[id] = qty[id]! + 1),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(Icons.add_rounded, color: Color(0xFF27AE60), size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: cartCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CartPage(items, qty, widget.restaurantId, widget.restaurantName)),
              ),
              backgroundColor: const Color(0xFFFF6B35),
              icon: const Icon(Icons.shopping_cart_rounded, color: Colors.white),
              label: Text(
                'Cart ($cartCount)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }
}
