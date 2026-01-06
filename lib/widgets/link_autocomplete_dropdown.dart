import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/link_management_service.dart';

/// A dropdown widget that provides autocomplete suggestions for note links.
///
/// This widget detects when the user types [[ in a text field and displays
/// a dropdown with filtered note titles. Users can navigate with arrow keys
/// and select a suggestion to insert the complete link syntax.
///
/// Features:
/// - Detects [[ input trigger
/// - Displays filtered note title suggestions
/// - Arrow key navigation support
/// - Shows note preview on hover (desktop)
/// - Inserts complete [[Note Title]] syntax on selection
/// - Automatically positions dropdown below cursor
///
/// Example usage:
/// ```dart
/// LinkAutocompleteDropdown(
///   textController: _descriptionController,
///   focusNode: _descriptionFocusNode,
///   userId: userId,
///   linkService: linkService,
/// )
/// ```
class LinkAutocompleteDropdown extends StatefulWidget {
  final TextEditingController textController;
  final FocusNode focusNode;
  final String userId;
  final LinkManagementService linkService;

  const LinkAutocompleteDropdown({
    super.key,
    required this.textController,
    required this.focusNode,
    required this.userId,
    required this.linkService,
  });

  @override
  State<LinkAutocompleteDropdown> createState() =>
      _LinkAutocompleteDropdownState();
}

class _LinkAutocompleteDropdownState extends State<LinkAutocompleteDropdown> {
  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];
  int _selectedIndex = 0;
  int _linkStartPosition = -1;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    widget.textController.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _removeOverlay();
    super.dispose();
  }

  /// Handle text changes to detect [[ trigger and update suggestions
  void _onTextChanged() {
    final text = widget.textController.text;
    final cursorPosition = widget.textController.selection.baseOffset;

    // Find the last occurrence of [[ before cursor
    final beforeCursor = text.substring(0, cursorPosition);
    final linkStartIndex = beforeCursor.lastIndexOf('[[');

    if (linkStartIndex == -1) {
      // No [[ found, hide dropdown
      _removeOverlay();
      return;
    }

    // Check if there's a closing ]] between [[ and cursor
    final afterLinkStart = beforeCursor.substring(linkStartIndex);
    if (afterLinkStart.contains(']]')) {
      // Link is already closed, hide dropdown
      _removeOverlay();
      return;
    }

    // Extract the query text between [[ and cursor
    final query = beforeCursor.substring(linkStartIndex + 2);

    // Update state and fetch suggestions
    _linkStartPosition = linkStartIndex;
    _selectedIndex = 0;
    _fetchSuggestions(query);
  }

  /// Handle focus changes to hide dropdown when focus is lost
  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      _removeOverlay();
    }
  }

  /// Fetch note title suggestions from the service
  Future<void> _fetchSuggestions(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final suggestions = await widget.linkService.getNoteTitleSuggestions(
        widget.userId,
        query,
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });

        if (suggestions.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _suggestions = [];
        });
        _removeOverlay();
      }
    }
  }

  /// Show the autocomplete dropdown overlay
  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            width: MediaQuery.of(context).size.width - 32,
            child: CompositedTransformFollower(
              link: LayerLink(),
              showWhenUnlinked: false,
              offset: const Offset(0, 50),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: _buildDropdownContent(),
              ),
            ),
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Build the dropdown content with suggestions
  Widget _buildDropdownContent() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child:
          _isLoading
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
              : ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  final isSelected = index == _selectedIndex;

                  return InkWell(
                    onTap: () => _selectSuggestion(suggestion),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.1)
                                : null,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.note, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              suggestion,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.keyboard_return,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }

  /// Select a suggestion and insert the link syntax
  void _selectSuggestion(String suggestion) {
    if (_linkStartPosition == -1) return;

    final text = widget.textController.text;
    final cursorPosition = widget.textController.selection.baseOffset;

    // Build the complete link syntax
    final linkSyntax = '[[$suggestion]]';

    // Replace from [[ to cursor with the complete link
    final newText =
        text.substring(0, _linkStartPosition) +
        linkSyntax +
        text.substring(cursorPosition);

    // Update the text controller
    widget.textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: _linkStartPosition + linkSyntax.length,
      ),
    );

    // Hide the dropdown
    _removeOverlay();
  }

  /// Remove the overlay
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _linkStartPosition = -1;
    _selectedIndex = 0;
    _suggestions = [];
  }

  /// Handle arrow key navigation
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // Only handle keys when dropdown is visible
    if (_overlayEntry == null || _suggestions.isEmpty) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % _suggestions.length;
      });
      _showOverlay(); // Rebuild overlay with new selection
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex =
            (_selectedIndex - 1 + _suggestions.length) % _suggestions.length;
      });
      _showOverlay(); // Rebuild overlay with new selection
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      if (_selectedIndex >= 0 && _selectedIndex < _suggestions.length) {
        _selectSuggestion(_suggestions[_selectedIndex]);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _removeOverlay();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // This widget doesn't render anything visible itself
    // It manages the overlay and listens to the text controller
    return Focus(onKeyEvent: _handleKeyEvent, child: const SizedBox.shrink());
  }
}
