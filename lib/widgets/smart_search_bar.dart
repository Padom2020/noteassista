import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/smart_search_service.dart';
import '../services/auth_service.dart';
import 'search_result_card.dart';

/// Expandable smart search bar with natural language support
class SmartSearchBar extends StatefulWidget {
  const SmartSearchBar({super.key});

  @override
  State<SmartSearchBar> createState() => _SmartSearchBarState();
}

class _SmartSearchBarState extends State<SmartSearchBar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SmartSearchService _searchService = SmartSearchService();
  final AuthService _authService = AuthService();

  bool _isExpanded = false;
  bool _isSearching = false;
  List<SearchResult> _searchResults = [];
  List<String> _recentSearches = [];
  String? _errorMessage;

  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxRecentSearches = 10;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadRecentSearches();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = prefs.getStringList(_recentSearchesKey) ?? [];
      setState(() {
        _recentSearches = searches;
      });
    } catch (e) {
      // Silently fail - recent searches are not critical
    }
  }

  Future<void> _saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = List<String>.from(_recentSearches);

      // Remove if already exists
      searches.remove(query);

      // Add to beginning
      searches.insert(0, query);

      // Keep only max recent searches
      if (searches.length > _maxRecentSearches) {
        searches.removeRange(_maxRecentSearches, searches.length);
      }

      await prefs.setStringList(_recentSearchesKey, searches);

      setState(() {
        _recentSearches = searches;
      });
    } catch (e) {
      // Silently fail - recent searches are not critical
    }
  }

  Future<void> _clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
      setState(() {
        _recentSearches = [];
      });
    } catch (e) {
      // Silently fail
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _errorMessage = null;
      });
      return;
    }

    // Debounce search
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_searchController.text == query) {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final userId = _authService.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        setState(() {
          _errorMessage = 'User not authenticated';
          _isSearching = false;
        });
        return;
      }

      final results = await _searchService.searchNotes(userId, query);

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      // Save to recent searches
      await _saveRecentSearch(query);
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: ${e.toString()}';
        _isSearching = false;
        _searchResults = [];
      });
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
        _searchFocusNode.requestFocus();
      } else {
        _animationController.reverse();
        _searchController.clear();
        _searchResults = [];
        _searchFocusNode.unfocus();
      }
    });
  }

  void _selectRecentSearch(String query) {
    _searchController.text = query;
    _performSearch(query);
  }

  Widget _buildSearchOperatorHints() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          _buildOperatorChip('tag:name', 'Filter by tag'),
          _buildOperatorChip('date:YYYY-MM-DD', 'Specific date'),
          _buildOperatorChip('is:pinned', 'Pinned notes'),
          _buildOperatorChip('is:done', 'Completed notes'),
          _buildOperatorChip('today', 'Today\'s notes'),
          _buildOperatorChip('last week', 'Last week'),
        ],
      ),
    );
  }

  Widget _buildOperatorChip(String operator, String description) {
    return Tooltip(
      message: description,
      child: ActionChip(
        label: Text(operator, style: const TextStyle(fontSize: 11)),
        onPressed: () {
          final currentText = _searchController.text;
          _searchController.text = '$currentText $operator ';
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: _searchController.text.length),
          );
        },
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              TextButton(
                onPressed: _clearRecentSearches,
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children:
                _recentSearches.map((search) {
                  return InputChip(
                    label: Text(search, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _selectRecentSearch(search),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final searches = List<String>.from(_recentSearches);
                      searches.remove(search);
                      await prefs.setStringList(_recentSearchesKey, searches);
                      setState(() {
                        _recentSearches = searches;
                      });
                    },
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[700]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_searchController.text.isEmpty) {
      return Column(
        children: [_buildRecentSearches(), _buildSearchOperatorHints()],
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No results found for "${_searchController.text}"',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Try different keywords or use search operators',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return SearchResultCard(
          searchResult: _searchResults[index],
          searchQuery: _searchController.text,
          onTap: () {
            _toggleExpanded();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Material(
          elevation: _isExpanded ? 4 : 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (_isExpanded)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _toggleExpanded,
                  )
                else
                  const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Search notes...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey[400]),
                    ),
                    onTap: () {
                      if (!_isExpanded) {
                        _toggleExpanded();
                      }
                    },
                    readOnly: !_isExpanded,
                  ),
                ),
                if (_isExpanded && _searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _isExpanded ? null : _toggleExpanded,
                ),
              ],
            ),
          ),
        ),

        // Search results overlay
        if (_isExpanded)
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(child: _buildSearchResults()),
            ),
          ),
      ],
    );
  }
}
