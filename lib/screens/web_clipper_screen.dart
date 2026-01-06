import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/web_clipper_service.dart';
import '../services/supabase_service.dart';
import '../models/note_model.dart';

/// Screen for handling web page clipping from shared URLs
class WebClipperScreen extends StatefulWidget {
  final String sharedUrl;

  const WebClipperScreen({super.key, required this.sharedUrl});

  @override
  State<WebClipperScreen> createState() => _WebClipperScreenState();
}

class _WebClipperScreenState extends State<WebClipperScreen> {
  final AuthService _authService = AuthService();
  final WebClipperService _webClipperService = WebClipperService();
  final SupabaseService _supabaseService = SupabaseService.instance;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  WebClipResult? _clipResult;
  final List<String> _selectedTags = [];
  List<String> _suggestedTags = [];
  String? _featuredImageUrl;

  @override
  void initState() {
    super.initState();
    _clipWebPage();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// Clip the web page and extract content
  Future<void> _clipWebPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Clip the web page
      final result = await _webClipperService.clipWebPage(widget.sharedUrl);

      // Download featured image if available
      String? imageUrl;
      if (result.featuredImageUrl != null) {
        final user = _authService.currentUser;
        if (user != null) {
          imageUrl = await _webClipperService.downloadFeaturedImage(
            result.featuredImageUrl!,
            user.uid,
          );
        }
      }

      setState(() {
        _clipResult = result;
        _titleController.text = result.title;
        _contentController.text = result.content;
        _suggestedTags = result.suggestedTags;
        _featuredImageUrl = imageUrl;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Save the clipped content as a note
  Future<void> _saveNote() async {
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save notes')),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Create note model
      final note = NoteModel(
        id: '',
        title: _titleController.text.trim(),
        description: _contentController.text.trim(),
        timestamp: DateTime.now().toString(),
        categoryImageIndex: 0,
        isDone: false,
        isPinned: false,
        tags: _selectedTags,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        sourceUrl: widget.sharedUrl,
        imageUrls: _featuredImageUrl != null ? [_featuredImageUrl!] : [],
        wordCount: _contentController.text.trim().split(RegExp(r'\s+')).length,
      );

      // Save to Supabase
      await _supabaseService.createNote(note);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note saved successfully!')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save note: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Toggle a tag selection
  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clip Web Page'),
        actions: [
          if (!_isLoading && _clipResult != null)
            TextButton(
              onPressed: _isSaving ? null : _saveNote,
              child:
                  _isSaving
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Text(
                        'Save',
                        style: TextStyle(color: Colors.white),
                      ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingView();
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (_clipResult == null) {
      return const Center(child: Text('No content available'));
    }

    return _buildContentView();
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text('Clipping web page...', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              widget.sharedUrl,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text(
              'Failed to clip web page',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _clipWebPage,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source URL
          _buildSourceUrl(),
          const SizedBox(height: 16),

          // Featured image
          if (_featuredImageUrl != null) ...[
            _buildFeaturedImage(),
            const SizedBox(height: 16),
          ],

          // Title
          _buildTitleField(),
          const SizedBox(height: 16),

          // Suggested tags
          if (_suggestedTags.isNotEmpty) ...[
            _buildSuggestedTags(),
            const SizedBox(height: 16),
          ],

          // Selected tags
          if (_selectedTags.isNotEmpty) ...[
            _buildSelectedTags(),
            const SizedBox(height: 16),
          ],

          // Content
          _buildContentField(),
        ],
      ),
    );
  }

  Widget _buildSourceUrl() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.link, size: 20, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.sharedUrl,
              style: TextStyle(fontSize: 12, color: Colors.blue[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        _featuredImageUrl!,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            color: Colors.grey[300],
            child: const Center(child: Icon(Icons.broken_image, size: 48)),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: 'Title',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.title),
      ),
      maxLines: 2,
    );
  }

  Widget _buildSuggestedTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Suggested Tags',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _suggestedTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) => _toggleTag(tag),
                  selectedColor: Colors.blue[100],
                  checkmarkColor: Colors.blue[700],
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildSelectedTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selected Tags',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _selectedTags.map((tag) {
                return Chip(
                  label: Text(tag),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _toggleTag(tag),
                  backgroundColor: Colors.blue[100],
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildContentField() {
    return TextField(
      controller: _contentController,
      decoration: const InputDecoration(
        labelText: 'Content',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      maxLines: 15,
      minLines: 10,
    );
  }
}
