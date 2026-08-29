import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';
import 'auth_service.dart';
import 'menu_page.dart';
import 'order_history_page.dart';
import 'order_status_page.dart';
import 'login.dart';

class RestaurantsPage extends StatefulWidget {
  const RestaurantsPage({super.key});

  @override
  _RestaurantsPageState createState() => _RestaurantsPageState();
}

class _RestaurantsPageState extends State<RestaurantsPage> {
  List data = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await http.get(Uri.parse("${ApiConfig.baseUrl}/restaurants"));
      if (r.statusCode == 200) {
        setState(() { data = jsonDecode(r.body)['restaurants']; loading = false; });
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  void logout() async {
    await AuthService.clearSession();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EZFOODZ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded),
            tooltip: 'Profile',
            onPressed: () => _showProfileSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Order History',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderHistoryPage())),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'Order Status',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderStatusPage())),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: logout,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : RefreshIndicator(
              onRefresh: load,
              color: const Color(0xFFFF6B35),
              child: data.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🏪', style: TextStyle(fontSize: 52)),
                          SizedBox(height: 12),
                          Text('No restaurants available', style: TextStyle(color: Color(0xFF7A5C45), fontSize: 16)),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                          child: Text(
                            '🍽️  What are you hungry for?',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1C1008),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.82,
                            ),
                            itemCount: data.length,
                            itemBuilder: (_, i) => _restaurantCard(data[i]),
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }

  void _showProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1008),
                ),
              ),
              const SizedBox(height: 20),
              _profileRow(Icons.person_outline, 'Name', AuthService.username ?? 'N/A'),
              _profileRow(Icons.email_outlined, 'Email', AuthService.email ?? 'N/A'),
              _profileRow(Icons.male_outlined, 'Gender', AuthService.gender ?? 'Not set'),
              _profileRow(Icons.apartment_outlined, 'Hostel', AuthService.hostel ?? 'Not set'),
              _profileRow(Icons.phone_outlined, 'Phone', AuthService.phone ?? 'Not set'),
              _profileRow(Icons.school_outlined, 'College', AuthService.collegeName ?? 'Not set'),
            ],
          ),
        );
      },
    );
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF6B35), size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF7A5C45)),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1C1008)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _restaurantCard(Map<String, dynamic> r) {
    final isOpen = r['is_open'] == 1 || r['is_open'] == true;
    final hasImage = r['image_url'] != null && r['image_url'].toString().isNotEmpty;

    return GestureDetector(
      onTap: isOpen
          ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => MenuPage(r['id'], r['name'])))
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOpen ? const Color(0xFFFFD5B8) : const Color(0xFFEEDDD5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withValues(alpha: isOpen ? 0.12 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Opacity(
          opacity: isOpen ? 1.0 : 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      hasImage
                          ? Image.network(
                              "${ApiConfig.baseUrl}${r['image_url']}",
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholderIcon(),
                            )
                          : _placeholderIcon(),
                      // Closed overlay
                      if (!isOpen)
                        Container(
                          color: Colors.black26,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🔴', style: TextStyle(fontSize: 22)),
                                SizedBox(height: 4),
                                Text(
                                  'CLOSED',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1C1008)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF39C12), size: 15),
                          const SizedBox(width: 3),
                          Text(
                            '${r['rating'] ?? '4.0'}',
                            style: const TextStyle(color: Color(0xFF7A5C45), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isOpen ? const Color(0xFFE8F8F0) : const Color(0xFFFFEBEB),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isOpen ? 'OPEN' : 'CLOSED',
                              style: TextStyle(
                                color: isOpen ? const Color(0xFF27AE60) : const Color(0xFFE74C3C),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      color: const Color(0xFFFFF0E6),
      child: const Center(
        child: Text('🏪', style: TextStyle(fontSize: 38)),
      ),
    );
  }
}
