import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  String? _selectedGender;
  String? _selectedBloodGroup;
  String? _selectedRole;

  static const List<String> _genders = [
    'Male',
    'Female',
    'Other',
  ];

  static const List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  static const List<String> _roles = [
    'AE',
    'AEE',
    'EE',
  ];

  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _aadhaarController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Registration')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Admin Account',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete the form below to create your admin account.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildSectionTitle(context, 'Personal Information'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nameController,
                        enabled: !_loading,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDecoration(
                          context,
                          label: 'Name',
                          hint: 'Enter full name',
                          icon: Icons.person_outline,
                        ),
                      ),

                      const SizedBox(height: 22),
                      _buildSectionTitle(context, 'Contact Details'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _emailController,
                        enabled: !_loading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDecoration(
                          context,
                          label: 'Email',
                          hint: 'admin@example.com',
                          icon: Icons.alternate_email,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              enabled: !_loading,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: _fieldDecoration(
                                context,
                                label: 'Phone Number',
                                hint: '10-digit mobile number',
                                icon: Icons.phone_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _dobController,
                              enabled: !_loading,
                              readOnly: true,
                              onTap: _pickDateOfBirth,
                              decoration: _fieldDecoration(
                                context,
                                label: 'Date of Birth',
                                hint: 'YYYY-MM-DD',
                                icon: Icons.cake_outlined,
                                suffixIcon: Icons.calendar_today_outlined,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),
                      _buildSectionTitle(context, 'Additional Details'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedGender,
                              items: _genders
                                  .map(
                                    (gender) => DropdownMenuItem<String>(
                                      value: gender,
                                      child: Text(gender),
                                    ),
                                  )
                                  .toList(),
                              decoration: _fieldDecoration(
                                context,
                                label: 'Gender',
                                hint: 'Select',
                                icon: Icons.wc_outlined,
                              ),
                              onChanged: _loading
                                  ? null
                                  : (value) {
                                      setState(() => _selectedGender = value);
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedBloodGroup,
                              items: _bloodGroups
                                  .map(
                                    (bloodGroup) => DropdownMenuItem<String>(
                                      value: bloodGroup,
                                      child: Text(bloodGroup),
                                    ),
                                  )
                                  .toList(),
                              decoration: _fieldDecoration(
                                context,
                                label: 'Blood Group',
                                hint: 'Select',
                                icon: Icons.bloodtype_outlined,
                              ),
                              onChanged: _loading
                                  ? null
                                  : (value) {
                                      setState(
                                        () => _selectedBloodGroup = value,
                                      );
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        items: _roles
                            .map(
                              (role) => DropdownMenuItem<String>(
                                value: role,
                                child: Text(role),
                              ),
                            )
                            .toList(),
                        decoration: _fieldDecoration(
                          context,
                          label: 'Role',
                          hint: 'Select user role',
                          icon: Icons.manage_accounts_outlined,
                        ),
                        onChanged: _loading
                            ? null
                            : (value) {
                                setState(() => _selectedRole = value);
                              },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _aadhaarController,
                        enabled: !_loading,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDecoration(
                          context,
                          label: 'Aadhaar Number',
                          hint: '12-digit Aadhaar number',
                          icon: Icons.badge_outlined,
                        ),
                      ),

                      const SizedBox(height: 22),
                      _buildSectionTitle(context, 'Security'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        enabled: !_loading,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDecoration(
                          context,
                          label: 'Password',
                          hint: 'Minimum 6 characters',
                          icon: Icons.lock_outline,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPasswordController,
                        enabled: !_loading,
                        obscureText: true,
                        decoration: _fieldDecoration(
                          context,
                          label: 'Confirm Password',
                          hint: 'Re-enter password',
                          icon: Icons.lock_reset_outlined,
                        ),
                      ),

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _loading ? null : _createAccount,
                          child: const Text('Create Account'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                },
                          child: const Text('Back to Sign In'),
                        ),
                      ),
                      if (_loading) ...[
                        const SizedBox(height: 10),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    required String hint,
    required IconData icon,
    IconData? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon != null ? Icon(suffixIcon, size: 20) : null,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
      ),
    );
  }

  Future<void> _createAccount() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final dob = _dobController.text.trim();
    final aadhaar = _aadhaarController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final phoneRegExp = RegExp(r'^\d{10}$');
    final aadhaarRegExp = RegExp(r'^\d{12}$');

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        dob.isEmpty ||
        _selectedGender == null ||
        _selectedBloodGroup == null ||
        _selectedRole == null ||
        aadhaar.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _show('Please fill all required fields');
      return;
    }

    if (!phoneRegExp.hasMatch(phone)) {
      _show('Phone number must be 10 digits');
      return;
    }

    if (!aadhaarRegExp.hasMatch(aadhaar)) {
      _show('Aadhaar number must be 12 digits');
      return;
    }

    if (password.length < 6) {
      _show('Password must be at least 6 characters');
      return;
    }

    if (password != confirmPassword) {
      _show('Password and confirm password do not match');
      return;
    }

    setState(() => _loading = true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      final uid = credential.user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': name,
          'email': email,
          'phone': phone,
          'dob': dob,
          'gender': _selectedGender,
          'bloodGroup': _selectedBloodGroup,
          'aadhaar': aadhaar,
          'role': _selectedRole?.toLowerCase(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      _show('Account created successfully. Please sign in.');
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (error) {
      _show(error.message ?? error.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initialDate = DateTime(now.year - 22, now.month, now.day);
    final firstDate = DateTime(1950);
    final lastDate = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked == null || !mounted) return;
    final month = picked.month.toString().padLeft(2, '0');
    final day = picked.day.toString().padLeft(2, '0');
    _dobController.text = '${picked.year}-$month-$day';
  }
}
