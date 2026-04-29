import 'package:flutter/material.dart';
import 'package:easytime_online/api/change_password_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easytime_online/main/main.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String empKey;

  const ChangePasswordScreen({super.key, required this.empKey});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _oldController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _oldVerified = false;
  bool _loading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _verifyOld() async {
    final old = _oldController.text.trim();
    if (old.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your old password')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    final res = await ChangePasswordApi.verifyOldPassword(widget.empKey, old);

    setState(() {
      _loading = false;
    });

    if (res['success'] == true && res['flag'] == 'old_verified') {
      setState(() {
        _oldVerified = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Old password verified')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Verification failed')),
      );
    }
  }

  Future<void> _changePassword() async {
    final old = _oldController.text.trim();
    final nw = _newController.text.trim();
    final cf = _confirmController.text.trim();

    if (!_oldVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your old password first')),
      );
      return;
    }

    if (nw.isEmpty || cf.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter new and confirm password')),
      );
      return;
    }

    if (nw != cf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('New password and confirm password do not match')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    final res =
        await ChangePasswordApi.changePassword(widget.empKey, old, nw, cf);

    setState(() {
      _loading = false;
    });

    if (res['success'] == true && res['flag'] == 'changed') {
      // Clear saved credentials and force logout
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_password');
        await prefs.remove('user_code');
        await prefs.setBool('remember_me', false);
        await prefs.remove('user_rights_json');
        await prefs.remove('latest_announcements_json');
      } catch (_) {}

      // Navigate back to HomeScreen (login) and remove all routes
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(title: 'EasyTime Online'),
        ),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to change password')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0 + bottomInset),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _oldController,
                  obscureText: _obscureOld,
                  enabled: !_oldVerified,
                  decoration: InputDecoration(
                    labelText: 'Old Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureOld
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => _obscureOld = !_obscureOld),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_oldVerified) ...[
                  TextFormField(
                    controller: _newController,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _changePassword,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit'),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _verifyOld,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify Old Password'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
