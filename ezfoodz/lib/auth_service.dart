import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'api_config.dart';

/// Handles authentication state and API calls.
class AuthService {
  static List<String> colleges = [
    "SSN/SNU",
    "VITC",
    "REC",
  ];

  static const List<String> genders = ["Male", "Female", "Neutral"];
  static List<String> maleHostels = ["gh1", "gh2", "gh3", "gh4", "gh5", "gh6", "gh7", "gh8", "gh9"];
  static List<String> femaleHostels = ["lh1", "lh2", "lh3", "lh4", "lh5"];
  
  static List<String> ssnBuildings = [
    "LH1", "LH2", "LH3", "LH4", "LH5",
    "GH1", "GH2", "GH3", "GH4", "GH5", "GH6", "GH7", "GH8", "GH9",
    "CSE", "IT", "ANNEXURE", "ECE", "EEE", "CHEM", "MECH", "BIOMED"
  ];
  static List<String> defaultBuildings = ["Main Block", "Hostel 1", "Hostel 2"];

  static List<Map<String, dynamic>> dynamicCollegesData = [];

  static String? token;
  static int? userId;
  static String? username;
  static String? email;
  static String? collegeName;
  static String? gender;
  static String? hostel;
  static String? phone;
  static String? identification;
  static bool idCardVerified = false;
  static String? idCardVerificationMessage;

  static Map<String, dynamic> _safeDecodeMap(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {}
    return {};
  }

  /// Load saved session from shared preferences.
  static Future<bool> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    userId = prefs.getInt('userId');
    username = prefs.getString('username');
    email = prefs.getString('email');
    collegeName = prefs.getString('collegeName');
    gender = prefs.getString('gender');
    hostel = prefs.getString('hostel');
    phone = prefs.getString('phone');
    identification = prefs.getString('identification');
    idCardVerified = prefs.getBool('idCardVerified') ?? false;
    idCardVerificationMessage = prefs.getString('idCardVerificationMessage');
    return token != null;
  }

  /// Save session to shared preferences.
  static Future<void> saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    token = data['token'];
    userId = data['user_id'];
    username = data['username'] ?? '';
    email = data['email'] ?? '';
    collegeName = data['college_name'] ?? '';
    gender = data['gender'] ?? '';
    hostel = data['hostel'] ?? '';
    phone = data['phone'] ?? '';
    identification = data['identification'] ?? '';
    idCardVerified = data['id_card_verified'] == true;
    idCardVerificationMessage = data['id_card_verification_message'] ?? '';
    
    if (token != null) await prefs.setString('token', token!);
    if (userId != null) await prefs.setInt('userId', userId!);
    await prefs.setString('username', username!);
    await prefs.setString('email', email!);
    await prefs.setString('collegeName', collegeName ?? '');
    await prefs.setString('gender', gender ?? '');
    await prefs.setString('hostel', hostel ?? '');
    await prefs.setString('phone', phone ?? '');
    await prefs.setString('identification', identification ?? '');
    await prefs.setBool('idCardVerified', idCardVerified);
    await prefs.setString('idCardVerificationMessage', idCardVerificationMessage ?? '');
  }

  /// Clear session (logout).
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    token = null;
    userId = null;
    username = null;
    email = null;
    collegeName = null;
    gender = null;
    hostel = null;
    phone = null;
    identification = null;
    idCardVerified = false;
    idCardVerificationMessage = null;
  }

  /// Email/password login. (Still kept in case it's used elsewhere)
  static Future<Map<String, dynamic>> login(String emailAddr, String password) async {
    final r = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/auth/login"),
      body: {"email": emailAddr, "password": password},
    );
    if (r.statusCode == 200) {
      final data = _safeDecodeMap(r.body);
      await saveSession(data);
      return {"success": true};
    } else {
      final err = _safeDecodeMap(r.body);
      return {"success": false, "error": err["detail"] ?? "Login failed"};
    }
  }

  /// Google sign-in → send to backend.
  static Future<Map<String, dynamic>> googleAuth(
    String emailAddr,
    String uid,
    String displayName,
  ) async {
    final r = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/auth/google"),
      body: {
        "email": emailAddr,
        "firebase_uid": uid,
        "username": displayName,
      },
    );
    if (r.statusCode == 200) {
      final data = _safeDecodeMap(r.body);
      await saveSession(data);
      return {"success": true};
    } else {
      final err = _safeDecodeMap(r.body);
      return {"success": false, "error": err["detail"] ?? "Google auth failed"};
    }
  }

  /// Update delivery details for the first order
  static Future<Map<String, dynamic>> updateDeliveryDetails({
    required String newUsername,
    required String newPhone,
    required String newHostel,
    required String newGender,
    required String newIdentification,
  }) async {
    if (token == null) return {"success": false, "error": "Not logged in"};
    
    final r = await http.put(
      Uri.parse("${ApiConfig.baseUrl}/auth/me/delivery-details"),
      headers: authHeaders(),
      body: jsonEncode({
        "username": newUsername,
        "phone": newPhone,
        "hostel": newHostel,
        "gender": newGender,
        "identification": newIdentification,
      }),
    );
    
    if (r.statusCode == 200) {
      // update local cache
      username = newUsername;
      phone = newPhone;
      hostel = newHostel;
      gender = newGender;
      identification = newIdentification;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', newUsername);
      await prefs.setString('phone', newPhone);
      await prefs.setString('hostel', newHostel);
      await prefs.setString('gender', newGender);
      await prefs.setString('identification', newIdentification);
      
      return {"success": true};
    } else {
      final err = _safeDecodeMap(r.body);
      return {"success": false, "error": err["detail"] ?? "Failed to update details"};
    }
  }

  /// Email/password register.
  static Future<Map<String, dynamic>> register(
    String emailAddr,
    String password,
    String username,
    String collegeName,
    String gender,
    String hostel,
    String phone,
  ) async {
    final r = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/auth/register"),
      body: {
        "email": emailAddr,
        "password": password,
        "username": username,
        "college_name": collegeName,
        "gender": gender,
        "hostel": hostel,
        "phone": phone,
      },
    );
    if (r.statusCode == 200) {
      final data = _safeDecodeMap(r.body);
      await saveSession(data);
      return {"success": true};
    } else {
      final err = _safeDecodeMap(r.body);
      return {"success": false, "error": err["detail"] ?? "Registration failed"};
    }
  }

  /// Upload student ID card.
  static Future<Map<String, dynamic>> uploadIdCard(XFile file) async {
    if (token == null) return {"success": false, "error": "Not logged in"};
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("${ApiConfig.baseUrl}/auth/id-card"),
      );
      request.headers.addAll({
        "Authorization": "Bearer $token",
      });
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );
      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        return {"success": true};
      } else {
        final err = _safeDecodeMap(body);
        return {"success": false, "error": err["detail"] ?? "ID card upload failed"};
      }
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  /// Verify uploaded ID card.
  static Future<Map<String, dynamic>> verifyIdCard() async {
    if (token == null) return {"success": false, "error": "Not logged in"};
    final r = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/auth/verify-id-card"),
      headers: authHeaders(),
    );
    if (r.statusCode == 200) {
      idCardVerified = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('idCardVerified', true);
      return {"success": true};
    } else {
      final err = _safeDecodeMap(r.body);
      return {"success": false, "error": err["detail"] ?? "Verification failed"};
    }
  }

  /// Load colleges and building mappings from backend, fallback to hardcoded lists if offline.
  static Future<void> loadCollegesAndBuildings() async {
    try {
      final r = await http.get(Uri.parse("${ApiConfig.baseUrl}/auth/colleges-with-buildings"));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded['colleges'] is List) {
          final List list = decoded['colleges'];
          dynamicCollegesData = List<Map<String, dynamic>>.from(list);
          
          // Re-populate colleges list
          colleges = dynamicCollegesData.map<String>((c) => c['name'] as String).toList();
          
          // Find SSN/SNU to populate gender lists and building lists
          for (var col in dynamicCollegesData) {
            final name = col['name'] as String;
            final buildingsList = col['buildings'] as List;
            final List<String> male = [];
            final List<String> female = [];
            final List<String> all = [];
            
            for (var b in buildingsList) {
              final bName = b['name'] as String;
              final bGender = b['gender'] as String;
              all.add(bName);
              if (bGender == 'Male') {
                male.add(bName.toLowerCase());
              } else if (bGender == 'Female') {
                female.add(bName.toLowerCase());
              }
            }
            
            if (name == "SSN/SNU") {
              ssnBuildings = all;
              if (male.isNotEmpty) maleHostels = male;
              if (female.isNotEmpty) femaleHostels = female;
            }
          }
        }
      }
    } catch (_) {
      // Keep hardcoded fallbacks if offline/error
    }
  }

  /// Get auth headers for API calls.
  static Map<String, String> authHeaders() {
    return {
      "Authorization": "Bearer ${token ?? ''}",
      "Content-Type": "application/json",
    };
  }
}
