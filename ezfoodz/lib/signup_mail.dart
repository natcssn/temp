import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'auth_service.dart';
import 'restaurants_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final ImagePicker picker = ImagePicker();

  String? selectedCollege;
  String? selectedGender;
  String? selectedHostel;
  XFile? idCardFile;
  bool loading = false;
  String? error;

  Future<void> pickIdCard() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked != null) {
      setState(() => idCardFile = picked);
    }
  }

  Future<void> doSignup() async {
    if (emailCtrl.text.isEmpty ||
        passCtrl.text.isEmpty ||
        nameCtrl.text.isEmpty ||
        selectedCollege == null ||
        selectedGender == null ||
        selectedHostel == null ||
        phoneCtrl.text.isEmpty ||
        idCardFile == null) {
      setState(() => error = "Please fill in all fields");
      return;
    }

    setState(() { loading = true; error = null; });

    final normalizedEmail = emailCtrl.text.trim().toLowerCase();
    final needsRegistration =
        AuthService.token == null || (AuthService.email ?? '').toLowerCase() != normalizedEmail;

    if (needsRegistration) {
      final result = await AuthService.register(
        emailCtrl.text.trim(),
        passCtrl.text,
        nameCtrl.text.trim(),
        selectedCollege!,
        selectedGender!,
        selectedHostel!,
        phoneCtrl.text.trim(),
      );

      if (!result["success"]) {
        if (!mounted) return;
        setState(() {
          loading = false;
          error = result["error"];
        });
        return;
      }
    }

    final uploadResult = await AuthService.uploadIdCard(idCardFile!);
    if (!uploadResult["success"]) {
      await AuthService.clearSession();
      if (!mounted) return;
      setState(() {
        loading = false;
        error = uploadResult["error"] ?? "ID card upload failed";
      });
      return;
    }

    final verifyResult = await AuthService.verifyIdCard();
    if (!verifyResult["success"]) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = verifyResult["error"] ?? 'idcard and college chosen doesnt match';
      });
      return;
    }

    if (!mounted) return;
    setState(() => loading = false);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => RestaurantsPage()),
      (_) => false,
    );
  }
  List<String> getHostelsForSelectedCollegeAndGender() {
    if (selectedCollege == null || selectedGender == null) {
      return [];
    }
    
    final List<String> list = [];
    if (AuthService.dynamicCollegesData.isNotEmpty) {
      for (var col in AuthService.dynamicCollegesData) {
        if (col['name'] == selectedCollege) {
          final buildings = col['buildings'] as List;
          for (var b in buildings) {
            final bName = b['name'] as String;
            final bGender = b['gender'] as String;
            if (bGender == selectedGender || bGender == 'Neutral') {
              list.add(bName.toLowerCase());
            }
          }
          break;
        }
      }
    }
    
    if (list.isEmpty) {
      if (selectedCollege == 'SSN/SNU') {
        return selectedGender == 'Male' ? AuthService.maleHostels : AuthService.femaleHostels;
      }
      return ['main block', 'hostel 1', 'hostel 2'];
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'Join EZFOODZ',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1C1008)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Create your account to start ordering',
                style: TextStyle(color: Color(0xFF7A5C45), fontSize: 13),
              ),
              const SizedBox(height: 32),

              Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Your name',
                        prefixIcon: Icon(Icons.person_outline_rounded, color: Color(0xFFB8967A)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'College email',
                        prefixIcon: Icon(Icons.email_outlined, color: Color(0xFFB8967A)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'Create a password',
                        prefixIcon: Icon(Icons.lock_outline_rounded, color: Color(0xFFB8967A)),
                      ),
                      onSubmitted: (_) => doSignup(),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedGender,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        hintText: 'Select gender',
                        prefixIcon: Icon(Icons.wc_outlined, color: Color(0xFFB8967A)),
                      ),
                      items: AuthService.genders
                          .map(
                            (g) => DropdownMenuItem<String>(
                              value: g,
                              child: Text(g),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        selectedGender = value;
                        selectedHostel = null; // reset hostel when gender changes
                      }),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedHostel,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: selectedGender == null
                            ? 'Select gender first'
                            : 'Select hostel',
                        prefixIcon: const Icon(Icons.apartment_outlined, color: Color(0xFFB8967A)),
                      ),
                      items: getHostelsForSelectedCollegeAndGender()
                          .map(
                            (h) => DropdownMenuItem<String>(
                              value: h,
                              child: Text(h.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: selectedGender == null
                          ? null
                          : (value) => setState(() => selectedHostel = value),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFFB8967A)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCollege,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        hintText: 'Choose college',
                        prefixIcon: Icon(Icons.school_outlined, color: Color(0xFFB8967A)),
                      ),
                      items: AuthService.colleges
                          .map(
                            (college) => DropdownMenuItem<String>(
                              value: college,
                              child: Text(
                                college,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => selectedCollege = value),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFD5B8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'ID CARD (Required)',
                            style: TextStyle(
                              color: Color(0xFF7A5C45),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: loading ? null : pickIdCard,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1C1008),
                              side: const BorderSide(color: Color(0xFFFFC8A2), width: 1.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.badge_outlined),
                            label: Text(idCardFile == null ? 'Upload ID CARD' : 'ID CARD Selected ✅'),
                          ),
                          if (idCardFile != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              idCardFile!.name,
                              style: const TextStyle(
                                color: Color(0xFF7A5C45),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: loading ? null : doSignup,
                      child: loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Create Account 🚀'),
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
                        child: Text(
                          error!,
                          style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
