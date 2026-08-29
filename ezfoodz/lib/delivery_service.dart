import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

class DeliveryService {
  static String? token;
  static int? partnerId;
  static String? name;
  static String? email;
  static String? phone;
  static String? gender;
  static String? bankId;

  static Map<String, dynamic> _safeDecodeMap(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {}
    return {};
  }

  static Map<String, String> authHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<bool> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('deliveryToken');
    partnerId = prefs.getInt('deliveryPartnerId');
    name = prefs.getString('deliveryName');
    email = prefs.getString('deliveryEmail');
    phone = prefs.getString('deliveryPhone');
    gender = prefs.getString('deliveryGender');
    bankId = prefs.getString('deliveryBankId');
    return token != null;
  }

  static Future<void> _saveSession(Map<String, dynamic> data) async {
    token = data['token']?.toString();
    partnerId = data['partner_id'] is int ? data['partner_id'] as int : int.tryParse('${data['partner_id']}');
    name = data['name']?.toString() ?? '';
    email = data['email']?.toString() ?? '';
    phone = data['phone']?.toString() ?? '';
    gender = data['gender']?.toString() ?? '';
    bankId = data['bank_id']?.toString() ?? '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deliveryToken', token ?? '');
    if (partnerId != null) {
      await prefs.setInt('deliveryPartnerId', partnerId!);
    }
    await prefs.setString('deliveryName', name ?? '');
    await prefs.setString('deliveryEmail', email ?? '');
    await prefs.setString('deliveryPhone', phone ?? '');
    await prefs.setString('deliveryGender', gender ?? '');
    await prefs.setString('deliveryBankId', bankId ?? '');
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('deliveryToken');
    await prefs.remove('deliveryPartnerId');
    await prefs.remove('deliveryName');
    await prefs.remove('deliveryEmail');
    await prefs.remove('deliveryPhone');
    await prefs.remove('deliveryGender');
    await prefs.remove('deliveryBankId');

    token = null;
    partnerId = null;
    name = null;
    email = null;
    phone = null;
    gender = null;
    bankId = null;
  }

  static Future<Map<String, dynamic>> register({
    required String partnerName,
    required String partnerEmail,
    required String partnerPassword,
    required String gender,
    String partnerPhone = '',
    String partnerBankId = '',
  }) async {
    final r = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/delivery/register'),
      body: {
        'name': partnerName,
        'email': partnerEmail,
        'password': partnerPassword,
        'phone': partnerPhone,
        'gender': gender,
        'bank_id': partnerBankId,
      },
    );

    final data = _safeDecodeMap(r.body);
    if (r.statusCode == 200) {
      await _saveSession(data);
      return {'success': true};
    }

    return {'success': false, 'error': data['detail'] ?? 'Registration failed'};
  }

  static Future<Map<String, dynamic>> login({
    required String partnerEmail,
    required String partnerPassword,
  }) async {
    final r = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/delivery/login'),
      body: {
        'email': partnerEmail,
        'password': partnerPassword,
      },
    );

    final data = _safeDecodeMap(r.body);
    if (r.statusCode == 200) {
      await _saveSession(data);
      return {'success': true};
    }

    return {'success': false, 'error': data['detail'] ?? 'Login failed'};
  }

  static Future<Map<String, dynamic>> myProfile() async {
    final r = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/delivery/me'),
      headers: authHeaders(),
    );

    final data = _safeDecodeMap(r.body);
    if (r.statusCode == 200) {
      name = data['name']?.toString() ?? name;
      email = data['email']?.toString() ?? email;
      phone = data['phone']?.toString() ?? phone;
      gender = data['gender']?.toString() ?? gender;
      bankId = data['bank_id']?.toString() ?? bankId;
      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to fetch profile'};
  }

  static Future<Map<String, dynamic>> updateBankId(String newBankId) async {
    final r = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/delivery/bank-id'),
      headers: {'Authorization': 'Bearer ${token ?? ''}'},
      body: {'bank_id': newBankId},
    );

    final data = _safeDecodeMap(r.body);
    if (r.statusCode == 200) {
      bankId = newBankId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('deliveryBankId', bankId ?? '');
      return {'success': true};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to update bank ID'};
  }

  static Future<Map<String, dynamic>> availableOrders() async {
    final r = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/delivery/orders/available'),
      headers: authHeaders(),
    );

    final data = _safeDecodeMap(r.body);
    if (r.statusCode == 200) {
      return {
        'success': true,
        'orders': (data['orders'] as List?) ?? const [],
      };
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to load available orders'};
  }

  static Future<Map<String, dynamic>> activeOrders() async {
    final r = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/delivery/orders/active'),
      headers: authHeaders(),
    );

    final data = _safeDecodeMap(r.body);
    if (r.statusCode == 200) {
      return {
        'success': true,
        'orders': (data['orders'] as List?) ?? const [],
      };
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to load active orders'};
  }

  static Future<Map<String, dynamic>> acceptOrder(int orderId) async {
    final r = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/delivery/orders/$orderId/accept'),
      headers: authHeaders(),
    );

    final data = _safeDecodeMap(r.body);
    if (r.statusCode == 200) {
      return {'success': true};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to accept order'};
  }

  static Future<Map<String, dynamic>> pickupOrder(int orderId) async {
    final r = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/delivery/orders/$orderId/pickup'),
      headers: authHeaders(),
    );

    final data = _safeDecodeMap(r.body);
    if (r.statusCode == 200) {
      return {'success': true};
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to mark pickup'};
  }

  static Future<Map<String, dynamic>> completeOrder(int orderId) async {
    final r = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/delivery/orders/$orderId/complete'),
      headers: authHeaders(),
    );

    final data = _safeDecodeMap(r.body);
    if (r.statusCode == 200) {
      return {
        'success': true,
        'delivery_fee': data['delivery_fee'] ?? 0,
      };
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to complete order'};
  }

  static Future<Map<String, dynamic>> earningsSummary() async {
    final r = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/delivery/earnings/summary'),
      headers: authHeaders(),
    );

    final data = _safeDecodeMap(r.body);
    if (r.statusCode == 200) {
      return {
        'success': true,
        'deliveries': data['deliveries'] ?? 0,
        'earnings': data['earnings'] ?? 0,
        'orders': data['orders'] ?? const [],
      };
    }

    return {'success': false, 'error': data['detail'] ?? 'Failed to load earnings'};
  }
}
