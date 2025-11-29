import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/comments_provider.dart';

class CommentSettingsScreen extends StatefulWidget {
  const CommentSettingsScreen({super.key});

  @override
  State<CommentSettingsScreen> createState() => _CommentSettingsScreenState();
}

class _CommentSettingsScreenState extends State<CommentSettingsScreen> {
  late TextEditingController _nameController;
  late String _currentName;

  @override
  void initState() {
    super.initState();
    _currentName = context.read<CommentsProvider>().userName;
    _nameController = TextEditingController(text: _currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid name'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
      return;
    }

    final provider = context.read<CommentsProvider>();
    await provider.setUserName(newName);

    if (mounted) {
      setState(() {
        _currentName = newName;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Comment name updated successfully!'),
          backgroundColor: Colors.green.withOpacity(0.8),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      appBar: AppBar(
        title: const Text('Comment Settings'),
        backgroundColor: AppTheme.darkBlack,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info box
            Container(
              decoration: BoxDecoration(
                color: AppTheme.mediumBlack,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryRed.withOpacity(0.3),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.primaryRed,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Comment Display Name',
                          style: TextStyle(
                            color: AppTheme.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This name will be displayed next to your comments on movies and TV shows.',
                    style: TextStyle(
                      color: AppTheme.lightGray,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Name input field
            Text(
              'Display Name',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              style: TextStyle(color: AppTheme.white, fontSize: 14),
              maxLength: 30,
              decoration: InputDecoration(
                hintText: 'Enter your comment display name',
                hintStyle: TextStyle(
                  color: AppTheme.lightGray.withOpacity(0.6),
                ),
                filled: true,
                fillColor: AppTheme.mediumBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppTheme.lightGray.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppTheme.lightGray.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppTheme.primaryRed,
                    width: 2,
                  ),
                ),
                counterStyle: TextStyle(
                  color: AppTheme.lightGray,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Save Display Name',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Preview section
            Text(
              'Preview',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.mediumBlack.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.lightGray.withOpacity(0.2),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _nameController.text.isEmpty
                            ? 'Anonymous'
                            : _nameController.text,
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'just now',
                        style: TextStyle(
                          color: AppTheme.lightGray,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is how your comment will appear',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Reset to anonymous option
            Container(
              decoration: BoxDecoration(
                color: AppTheme.mediumBlack,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.person_outline,
                  color: AppTheme.primaryRed,
                ),
                title: Text(
                  'Reset to Anonymous',
                  style: TextStyle(color: AppTheme.white, fontSize: 14),
                ),
                subtitle: Text(
                  'Clear your custom name',
                  style: TextStyle(color: AppTheme.lightGray, fontSize: 12),
                ),
                onTap: () {
                  _nameController.clear();
                  setState(() {});
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
