import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_service.dart';
import 'delivery_partner_login_page.dart';
import 'restaurants_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool loading = false;
  String? error;

  void go() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => RestaurantsPage()),
      (_) => false,
    );
  }

  Future<void> doGoogleLogin() async {
    setState(() { loading = true; error = null; });
    try {
      UserCredential userCred;
      if (kIsWeb) {
        final provider = GoogleAuthProvider()..addScope('email');
        userCred = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final GoogleSignIn gsi = GoogleSignIn(scopes: ['email']);
        final GoogleSignInAccount? gAccount = await gsi.signIn();
        if (gAccount == null) {
          setState(() => loading = false);
          return;
        }
        final GoogleSignInAuthentication gAuth = await gAccount.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: gAuth.accessToken,
          idToken: gAuth.idToken,
        );
        userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCred.user;
      if (user == null || user.email == null) {
        if (!mounted) return;
        setState(() {
          loading = false;
          error = 'Google sign-in failed. Please try again.';
        });
        return;
      }

      final result = await AuthService.googleAuth(
        user.email!,
        user.uid,
        user.displayName ?? '',
      );
      
      if (!result["success"]) {
        if (!mounted) return;
        setState(() {
          loading = false;
          error = result["error"];
        });
        return;
      }

      if (!mounted) return;
      setState(() => loading = false);
      go();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString().contains("network") ? 'Network Error' : 'Google sign-in failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF6B35), Color(0xFFFFF8F0)],
            stops: [0.0, 0.45],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Text('🍽️', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 10),
                  const Text(
                    'EZFOODZ',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Campus Food Ordering',
                    style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 36),

                  Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                          blurRadius: 40,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Welcome back!',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1C1008)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sign in to order delicious food',
                          style: TextStyle(color: Color(0xFF7A5C45), fontSize: 13),
                        ),
                        const SizedBox(height: 24),

                        if (kIsWeb || !(defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux))
                          OutlinedButton(
                            onPressed: loading ? null : doGoogleLogin,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1C1008),
                              side: const BorderSide(color: Color(0xFFFFD5B8), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                loading 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Image.network(
                                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                      width: 20, height: 20,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24, color: Color(0xFFFF6B35)),
                                    ),
                                const SizedBox(width: 10),
                                Text(loading ? 'Signing in...' : 'Continue with Google', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              ],
                            ),
                          ),

                        if (error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFFCCCC)),
                            ),
                            child: Text(error!, style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 13), textAlign: TextAlign.center),
                          ),
                        ],

                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DeliveryPartnerLoginPage()),
                          ),
                          icon: const Icon(Icons.local_shipping_outlined, size: 18),
                          label: const Text('Delivery Partner Login'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
