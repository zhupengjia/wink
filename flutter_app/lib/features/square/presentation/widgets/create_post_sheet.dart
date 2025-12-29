import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/wink_theme.dart';

/// Bottom sheet for creating a new post
class CreatePostSheet extends StatefulWidget {
  final Future<void> Function(String content, List<String> mediaUrls) onPost;

  const CreatePostSheet({
    super.key,
    required this.onPost,
  });

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final _controller = TextEditingController();
  final _imagePicker = ImagePicker();
  final _supabase = Supabase.instance.client;

  List<XFile> _selectedImages = [];
  bool _isPosting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _imagePicker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.take(9 - _selectedImages.length));
      });
    }
  }

  Future<void> _takePhoto() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image != null && _selectedImages.length < 9) {
      setState(() {
        _selectedImages.add(image);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages() async {
    final List<String> urls = [];
    final userId = _supabase.auth.currentUser?.id ?? 'anonymous';

    for (final image in _selectedImages) {
      final bytes = await image.readAsBytes();
      final ext = image.path.split('.').last;
      final path = 'posts/$userId/${DateTime.now().millisecondsSinceEpoch}_${urls.length}.$ext';

      await _supabase.storage.from('wink-storage').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: 'image/$ext'),
      );

      final url = _supabase.storage.from('wink-storage').getPublicUrl(path);
      urls.add(url);
    }

    return urls;
  }

  Future<void> _createPost() async {
    final content = _controller.text.trim();
    if (content.isEmpty && _selectedImages.isEmpty) return;

    setState(() => _isPosting = true);

    try {
      List<String> mediaUrls = [];
      if (_selectedImages.isNotEmpty) {
        mediaUrls = await _uploadImages();
      }

      await widget.onPost(content, mediaUrls);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7 + bottomPadding,
      decoration: const BoxDecoration(
        color: WinkTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: WinkTheme.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: WinkTheme.textSecondary),
                  ),
                ),
                const Text(
                  'New Post',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: WinkTheme.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: _isPosting ? null : _createPost,
                  child: _isPosting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: WinkTheme.primary,
                          ),
                        )
                      : const Text(
                          'Post',
                          style: TextStyle(
                            color: WinkTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: WinkTheme.surfaceLight),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text input
                  TextField(
                    controller: _controller,
                    maxLines: null,
                    minLines: 5,
                    maxLength: 500,
                    style: const TextStyle(
                      color: WinkTheme.textPrimary,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'What\'s on your mind?',
                      hintStyle: TextStyle(color: WinkTheme.textSecondary),
                      border: InputBorder.none,
                      counterStyle: TextStyle(color: WinkTheme.textSecondary),
                    ),
                  ),

                  // Selected images
                  if (_selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildImageGrid(),
                  ],
                ],
              ),
            ),
          ),

          // Bottom actions
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + bottomPadding,
            ),
            decoration: BoxDecoration(
              color: WinkTheme.surface,
              border: Border(
                top: BorderSide(color: WinkTheme.surfaceLight),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_library_outlined),
                  color: WinkTheme.primary,
                  onPressed: _selectedImages.length < 9 ? _pickImages : null,
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined),
                  color: WinkTheme.secondary,
                  onPressed: _selectedImages.length < 9 ? _takePhoto : null,
                ),
                const Spacer(),
                Text(
                  '${_selectedImages.length}/9',
                  style: TextStyle(
                    color: WinkTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _selectedImages.length,
      itemBuilder: (context, index) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_selectedImages[index].path),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeImage(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
