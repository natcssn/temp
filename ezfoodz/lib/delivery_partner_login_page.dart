import 'package:flutter/material.dart';

import 'delivery_partner_home_page.dart';
import 'delivery_service.dart';
import 'login.dart';

class DeliveryPartnerLoginPage extends StatefulWidget {
  const DeliveryPartnerLoginPage({super.key});

  @override
  State<DeliveryPartnerLoginPage> createState() => _DeliveryPartnerLoginPageState();
}

class _DeliveryPartnerLoginPageState extends State<DeliveryPartnerLoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final bankIdCtrl = TextEditingController();

  String? selectedGender;
  static const List<String> genders = ["Male", "Female"];

  bool isRegister = false;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final hasSession = await DeliveryService.loadSession();
    if (hasSession && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DeliveryPartnerHomePage()),
      );
    }
  }

  Future<void> submit() async {
    if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty || (isRegister && (nameCtrl.text.isEmpty || selectedGender == null))) {
      setState(() => error = 'Please fill all required fields');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    final result = isRegister
        ? await DeliveryService.register(
            partnerName: nameCtrl.text.trim(),
            partnerEmail: emailCtrl.text.trim(),
            partnerPassword: passCtrl.text,
            partnerPhone: phoneCtrl.text.trim(),
            gender: selectedGender!,
            partnerBankId: bankIdCtrl.text.trim(),
          )
        : await DeliveryService.login(
            partnerEmail: emailCtrl.text.trim(),
            partnerPassword: passCtrl.text,
          );

    if (!mounted) return;

    if (!result['success']) {
      setState(() {
        loading = false;
        error = result['error'] ?? 'Authentication failed';
      });
      return;
    }

    setState(() => loading = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DeliveryPartnerHomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text('Delivery Partner Login'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to User Sign In',
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (_) => false,
            );
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFD5B8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isRegister ? 'Create Delivery Partner Account' : 'Delivery Partner Sign In',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF1C1008)),
                ),
                const SizedBox(height: 14),
                if (isRegister) ...[
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline, color: Color(0xFFB8967A)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      hintText: 'Select Gender',
                      prefixIcon: Icon(Icons.male_outlined, color: Color(0xFFB8967A)),
                    ),
                    value: selectedGender,
                    items: genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) => setState(() => selectedGender = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: 'Phone number (optional)',
                      prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFFB8967A)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bankIdCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Bank Account ID (optional)',
                      prefixIcon: Icon(Icons.account_balance_outlined, color: Color(0xFFB8967A)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined, color: Color(0xFFB8967A)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline, color: Color(0xFFB8967A)),
                  ),
                  onSubmitted: (_) => submit(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFCCCC)),
                    ),
                    child: Text(error!, style: const TextStyle(color: Color(0xFFE74C3C))),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: loading ? null : submit,
                  child: loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isRegister ? 'Create Account' : 'Sign In'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: loading
                      ? null
                      : () => setState(() {
                            isRegister = !isRegister;
                            error = null;
                          }),
                  child: Text(isRegister ? 'Already have an account? Sign in' : 'New partner? Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
