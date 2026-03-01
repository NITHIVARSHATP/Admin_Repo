import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_register_screen.dart';
import 'ae_dashboard_screen.dart';
import '../aee_dashboard/aee_home.dart';
import '../ee_dashboard/ee_home.dart';

class AeLoginScreen extends StatefulWidget {
  const AeLoginScreen({super.key});

  @override
  State<AeLoginScreen> createState() => _AeLoginScreenState();
}

class _AeLoginScreenState extends State<AeLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _selectedRole;
  bool _loading = false;

  static const List<String> _roles = [
    'AE',
    'AEE',
    'EE',
  ];

  String get _selectedRoleCode => _selectedRole ?? 'ADMIN';

  String get _selectedRoleFullName {
    switch (_selectedRoleCode) {
      case 'AE':
        return 'Assistant Engineer';
      case 'AEE':
        return 'Assistant Executive Engineer';
      case 'EE':
        return 'Executive Engineer';
      default:
        return 'Admin';
    }
  }

  String get _selectedRoleSubtitle {
    switch (_selectedRoleCode) {
      case 'AE':
        return 'Sign in to access your Assistant Engineer dashboard.';
      case 'AEE':
        return 'Sign in to access your Assistant Executive Engineer dashboard.';
      case 'EE':
        return 'Sign in to access your Executive Engineer dashboard.';
      default:
        return 'Sign in to access your admin dashboard.';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('$_selectedRoleCode Login')),
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
                        '$_selectedRoleFullName Login',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedRoleSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _usernameController,
                        enabled: !_loading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDecoration(
                          context,
                          label: 'Email/Username',
                          hint: 'ae@example.com',
                          icon: Icons.alternate_email,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        enabled: !_loading,
                        obscureText: true,
                        decoration: _fieldDecoration(
                          context,
                          label: 'Password',
                          hint: 'Enter your password',
                          icon: Icons.lock_outline,
                        ),
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
                          hint: 'Select your role',
                          icon: Icons.manage_accounts_outlined,
                        ),
                        onChanged: _loading
                            ? null
                            : (value) {
                                setState(() => _selectedRole = value);
                              },
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
                          onPressed: _loading ? null : _signIn,
                          child: const Text('Sign In'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const AdminRegisterScreen(),
                                    ),
                                  );
                                },
                          child: const Text('Not registered? Create Account'),
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

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    required String hint,
    required IconData icon,
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

  Future<void> _signIn() async {
    final email = _usernameController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _show('Enter email/username and password');
      return;
    }

    if (_selectedRole == null) {
      _show('Please select a role');
      return;
    }

    setState(() => _loading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        _show('Unable to verify account role');
        await FirebaseAuth.instance.signOut();
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final storedRole =
          (userDoc.data()?['role'] ?? '').toString().trim().toLowerCase();
      final selectedRole = _selectedRole!.trim().toLowerCase();

      if (storedRole != selectedRole) {
        _show('Selected role does not match your account.');
        await FirebaseAuth.instance.signOut();
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => _dashboardForRole(selectedRole),
        ),
      );
    } on FirebaseAuthException catch (error) {
      _show(error.message ?? error.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _dashboardForRole(String role) {
    switch (role) {
      case 'aee':
        return const AEEHome();
      case 'ee':
        return const EEHome();
      case 'ae':
      default:
        return const AeDashboardScreen();
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}