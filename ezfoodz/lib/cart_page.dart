import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:convert';
import 'api_config.dart';
import 'auth_service.dart';
import 'order_status_page.dart';
import 'razorpay_web_checkout.dart';

class CartPage extends StatefulWidget {
  final List items;
  final Map<int, int> qty;
  final int restaurantId;
  final String restaurantName;
  const CartPage(this.items, this.qty, this.restaurantId, this.restaurantName, {super.key});

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool loading = false;
  String? error;
  Razorpay? _razorpay;
  bool _paymentInProgress = false;
  String fulfillmentMode = "pickup";
  String? _currentRazorpayOrderId;

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _identCtrl;
  String? _selectedBuilding;

  Map<String, dynamic> _safeDecodeMap(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {}
    return {};
  }

  String _normalizeCheckoutError(Object? raw, {String fallback = 'Payment failed. Please try again.'}) {
    final source = (raw ?? '').toString().trim();
    if (source.isEmpty) {
      return fallback;
    }

    final lower = source.toLowerCase();
    if (lower.contains('cvv')) {
      return 'Incorrect CVV for this test card. Please check and try again.';
    }
    if (lower.contains('cancelled') || lower.contains('canceled') || lower.contains('cancel')) {
      return 'Payment cancelled';
    }

    var cleaned = source;
    const noisyPrefixes = ['Bad state:', 'Exception:', 'Error:'];
    for (final prefix in noisyPrefixes) {
      if (cleaned.toLowerCase().startsWith(prefix.toLowerCase())) {
        cleaned = cleaned.substring(prefix.length).trim();
      }
    }

    return cleaned.isEmpty ? fallback : cleaned;
  }

  Future<bool> _tryRecoverPaidOrder(String razorpayOrderId) async {
    if (razorpayOrderId.isEmpty) {
      return false;
    }

    try {
      final statusResponse = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/payments/status/$razorpayOrderId"),
        headers: AuthService.authHeaders(),
      );

      if (statusResponse.statusCode != 200) {
        return false;
      }

      final data = _safeDecodeMap(statusResponse.body);
      if (data['status'] == 'paid' && data['order'] is Map<String, dynamic>) {
        final order = data['order'] as Map<String, dynamic>;
        if (!mounted) return true;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => OrderStatusPage(
              orderId: order['order_id'],
              secretCode: order['secret_code'],
              restaurantName: widget.restaurantName,
            ),
          ),
          (route) => route.isFirst,
        );
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
    _nameCtrl = TextEditingController(text: AuthService.username ?? '');
    _phoneCtrl = TextEditingController(text: AuthService.phone ?? '');
    _identCtrl = TextEditingController(text: AuthService.identification ?? '');
    _selectedBuilding = (AuthService.hostel != null && AuthService.hostel!.isNotEmpty) 
        ? AuthService.hostel 
        : null;
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _identCtrl.dispose();
    super.dispose();
  }

  List get cartItems => widget.items.where((i) => (widget.qty[i['id']] ?? 0) > 0).toList();

  double get total {
    double t = 0;
    for (var i in cartItems) {
      t += (widget.qty[i['id']] ?? 0) * (i['price'] as num);
    }
    if (fulfillmentMode == "delivery") {
      t += 20;
    }
    return t;
  }

  Future<void> placeOrder() async {
    if (_paymentInProgress) return;
    
    if (fulfillmentMode == "delivery") {
      if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty || _selectedBuilding == null) {
        setState(() => error = "Please fill in your name, phone and select a building for delivery.");
        return;
      }
      String calcGender = "Neutral";
      final b = _selectedBuilding!.toUpperCase();
      if (b.startsWith("LH")) {
        calcGender = "Female";
      } else if (b.startsWith("GH")) {
        calcGender = "Male";
      }
      
      setState(() { loading = true; error = null; });
      final res = await AuthService.updateDeliveryDetails(
        newUsername: _nameCtrl.text.trim(),
        newPhone: _phoneCtrl.text.trim(),
        newHostel: _selectedBuilding!,
        newGender: calcGender,
        newIdentification: _identCtrl.text.trim(),
      );
      if (!res["success"]) {
        setState(() {
          loading = false;
          error = res["error"];
        });
        return;
      }
    } else {
       setState(() { loading = true; error = null; });
    }

    final orderItems = cartItems.map<Map<String, dynamic>>((i) => {
      "item_id": i['id'],
      "quantity": widget.qty[i['id']],
    }).toList();

    try {
      final r = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/payments/create-order"),
        headers: AuthService.authHeaders(),
        body: jsonEncode({
          "restaurant_id": widget.restaurantId,
          "items": orderItems,
          "fulfillment_mode": fulfillmentMode,
        }),
      );

      if (r.statusCode == 200) {
        final data = _safeDecodeMap(r.body);
        _currentRazorpayOrderId = data['razorpay_order_id'];
        final options = {
          'key': data['key_id'],
          'amount': data['amount'],
          'currency': data['currency'] ?? 'INR',
          'name': 'EZFOODZ',
          'description': 'Order at ${widget.restaurantName}',
          'order_id': data['razorpay_order_id'],
          'prefill': {
            'email': AuthService.email ?? '',
            'name': AuthService.username ?? '',
          },
          'theme': {'color': '#27AE60'},
        };

        _paymentInProgress = true;
        if (mounted) {
          setState(() => loading = false);
        }

        if (kIsWeb) {
          final result = await openRazorpayWebCheckout(options);
          if (result == null) {
            _paymentInProgress = false;
            if (mounted) {
              setState(() => error = 'Payment cancelled');
            }
            return;
          }

          await _verifyAndNavigate(
            result['razorpay_order_id'] ?? '',
            result['payment_id'] ?? '',
            result['signature'] ?? '',
          );
        } else {
          _razorpay!.open(options);
        }
      } else {
        final err = _safeDecodeMap(r.body);
        if (mounted) {
          setState(() {
            loading = false;
            error = err['detail'] ?? 'Failed to start payment';
          });
        }
      }
    } catch (e) {
      _paymentInProgress = false;
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString().contains('Connection')
              ? 'Connection failed. Is the server running?'
              : _normalizeCheckoutError(e, fallback: 'Unable to open payment. Please try again.');
        });
      }
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final orderId = (response.orderId != null && response.orderId!.isNotEmpty)
        ? response.orderId!
        : (_currentRazorpayOrderId ?? '');
    await _verifyAndNavigate(
      orderId,
      response.paymentId ?? '',
      response.signature ?? '',
    );
  }

  Future<void> _verifyAndNavigate(
    String razorpayOrderId,
    String razorpayPaymentId,
    String razorpaySignature,
  ) async {
    if (razorpayOrderId.isEmpty || razorpayPaymentId.isEmpty || razorpaySignature.isEmpty) {
      _paymentInProgress = false;
      if (mounted) {
        setState(() => error = 'Payment callback incomplete. Please try again.');
      }
      return;
    }

    try {
      final r = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/payments/verify-and-place-order"),
        headers: AuthService.authHeaders(),
        body: jsonEncode({
          'razorpay_order_id': razorpayOrderId,
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_signature': razorpaySignature,
        }),
      );

      _paymentInProgress = false;

      if (r.statusCode == 200) {
        final data = _safeDecodeMap(r.body);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => OrderStatusPage(
              orderId: data['order_id'],
              secretCode: data['secret_code'],
              restaurantName: widget.restaurantName,
            ),
          ),
          (route) => route.isFirst,
        );
      } else {
        final err = _safeDecodeMap(r.body);
        final recovered = await _tryRecoverPaidOrder(razorpayOrderId);
        if (recovered) {
          return;
        }
        if (mounted) {
          setState(() => error = _normalizeCheckoutError(err['detail'], fallback: 'Payment verification failed'));
        }
      }
    } catch (_) {
      _paymentInProgress = false;
      final recovered = await _tryRecoverPaidOrder(razorpayOrderId);
      if (recovered) {
        return;
      }
      if (mounted) {
        setState(() => error = 'Payment may have succeeded. Please retry after a few seconds.');
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _paymentInProgress = false;
    if (!mounted) return;
    setState(() {
      loading = false;
      error = _normalizeCheckoutError(response.message);
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _paymentInProgress = false;
    if (!mounted) return;
    setState(() {
      loading = false;
      error = 'External wallet selected: ${response.walletName ?? 'unknown wallet'}';
    });
  }


  List<String> get _buildingChoices {
    final List<String> list = [];
    final userCollege = AuthService.collegeName;
    if (AuthService.dynamicCollegesData.isNotEmpty && userCollege != null) {
      for (var col in AuthService.dynamicCollegesData) {
        if (col['name'] == userCollege) {
          final buildings = col['buildings'] as List;
          for (var b in buildings) {
            list.add(b['name'] as String);
          }
          break;
        }
      }
    }
    
    if (list.isEmpty) {
      if (userCollege == "SSN" || userCollege == "SSN/SNU") {
        return AuthService.ssnBuildings;
      }
      return AuthService.defaultBuildings;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Cart 🛒')),
      body: cartItems.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🛒', style: TextStyle(fontSize: 56)),
                  SizedBox(height: 14),
                  Text('Your cart is empty', style: TextStyle(color: Color(0xFF7A5C45), fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartItems.length,
                    itemBuilder: (_, i) {
                      final item = cartItems[i];
                      final q = widget.qty[item['id']] ?? 1;
                      final subtotal = q * (item['price'] as num);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFD5B8)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B35).withValues(alpha: 0.07),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1C1008))),
                                  const SizedBox(height: 4),
                                  Text('₹${item['price']} × $q', style: const TextStyle(color: Color(0xFF7A5C45), fontSize: 13)),
                                ],
                              ),
                            ),
                            Text(
                              '₹${subtotal.toStringAsFixed(0)}',
                              style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom bar
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(top: BorderSide(color: Color(0xFFFFD5B8))),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => fulfillmentMode = "pickup"),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: fulfillmentMode == "pickup" ? const Color(0xFF27AE60).withValues(alpha: 0.1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: fulfillmentMode == "pickup" ? const Color(0xFF27AE60) : const Color(0xFFEEDDD5),
                                      width: 1.5),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Self Pick Up',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: fulfillmentMode == "pickup" ? const Color(0xFF27AE60) : const Color(0xFF7A5C45),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => fulfillmentMode = "delivery"),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: fulfillmentMode == "delivery" ? const Color(0xFFFF6B35).withValues(alpha: 0.1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: fulfillmentMode == "delivery" ? const Color(0xFFFF6B35) : const Color(0xFFEEDDD5),
                                      width: 1.5),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Delivery (+₹20)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: fulfillmentMode == "delivery" ? const Color(0xFFFF6B35) : const Color(0xFF7A5C45),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (fulfillmentMode == "delivery") ...[
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFEEDDD5))),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFEEDDD5))),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFEEDDD5))),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFEEDDD5))),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _selectedBuilding != null && _buildingChoices.contains(_selectedBuilding) ? _selectedBuilding : null,
                          decoration: const InputDecoration(
                            labelText: 'Select Building',
                            hintText: 'Choose your building',
                            border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFEEDDD5))),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFEEDDD5))),
                            isDense: true,
                          ),
                          items: _buildingChoices.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                          onChanged: (val) => setState(() => _selectedBuilding = val),
                          isExpanded: true,
                          validator: (val) => val == null ? 'Please select a building' : null,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _identCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Identification (e.g. wearing red shirt)',
                            border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFEEDDD5))),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFEEDDD5))),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1C1008))),
                          Text(
                            '₹${total.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF27AE60)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(error!, style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 13)),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading ? null : placeOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF27AE60),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('Place Order', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
