import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Guest User');
    _emailController = TextEditingController(text: 'guest@sonixhub.app');
    _phoneController = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name'),
          backgroundColor: Color.fromARGB(255, 244, 67, 54),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _nameController.text);
      await prefs.setString('user_email', _emailController.text);
      await prefs.setString('user_phone', _phoneController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.white),
                const SizedBox(width: 12),
                const Text('Profile updated successfully'),
              ],
            ),
            backgroundColor: Colors.green.withOpacity(0.8),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        // Navigate back after save
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update profile'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppTheme.darkBlack,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.mediumBlack,
                  border: Border.all(color: AppTheme.primaryRed, width: 3),
                ),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Icon(Icons.person, color: AppTheme.primaryRed, size: 60),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryRed,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: AppTheme.darkBlack,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Name',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: TextStyle(color: AppTheme.white),
              decoration: InputDecoration(
                hintText: 'Enter your name',
                hintStyle: TextStyle(color: AppTheme.lightGray),
                filled: true,
                fillColor: AppTheme.mediumBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.person, color: AppTheme.lightGray),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Email',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: AppTheme.white),
              decoration: InputDecoration(
                hintText: 'Enter your email',
                hintStyle: TextStyle(color: AppTheme.lightGray),
                filled: true,
                fillColor: AppTheme.mediumBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.email, color: AppTheme.lightGray),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Phone Number',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: AppTheme.white),
              decoration: InputDecoration(
                hintText: 'Enter your phone number',
                hintStyle: TextStyle(color: AppTheme.lightGray),
                filled: true,
                fillColor: AppTheme.mediumBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.phone, color: AppTheme.lightGray),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: AppTheme.primaryRed.withOpacity(0.5),
                ),
                child: _isSaving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.white,
                          ),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
