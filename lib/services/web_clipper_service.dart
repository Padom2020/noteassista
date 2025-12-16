import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:path_provider/path_provider.dart';
import '../services/cloudinary_service.dart';

/// Result of web page clipping operation
class WebClipResult {
  final String title;
  final String content;
  final String sourceUrl;
  final String? featuredImageUrl;
  final DateTime clippedAt;
  final List<String> suggestedTags;

  WebClipResult({
    required this.title,
    required this.content,
    required this.sourceUrl,
    this.featuredImageUrl,
    required this.clippedAt,
    required this.suggestedTags,
  });

  @override
  String toString() {
    return 'WebClipResult(title: $title, sourceUrl: $sourceUrl, tags: $suggestedTags)';
  }
}

/// Service for clipping web content and converting to notes
class WebClipperService {
  final CloudinaryService _cloudinaryService = CloudinaryService();

  WebClipperService();

  // User agent to identify the app when fetching web pages
  static const String _userAgent =
      'Mozilla/5.0 (compatible; NoteAssista/1.0; +https://noteassista.app)';

  // Timeout for HTTP requests
  static const Duration _requestTimeout = Duration(seconds: 30);

  /// Clip a web page and extract its content
  ///
  /// Fetches the web page, extracts the main content, converts to markdown,
  /// and suggests relevant tags based on the content.
  Future<WebClipResult> clipWebPage(String url) async {
    try {
      debugPrint('Clipping web page: $url');

      // Validate URL
      final uri = Uri.tryParse(url);
      if (uri == null ||
          (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https'))) {
        throw Exception('Invalid URL: $url');
      }

      // Fetch web page content
      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': _userAgent,
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.9',
            },
          )
          .timeout(_requestTimeout);

      // Check response status
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch web page: HTTP ${response.statusCode}',
        );
      }

      // Parse HTML
      final document = html_parser.parse(response.body);

      // Extract title
      String title = _extractTitle(document);

      // Extract main content
      String mainContent = extractMainContent(response.body);

      // Convert HTML to markdown
      String markdownContent = htmlToMarkdown(mainContent);

      // Extract featured image URL
      String? featuredImageUrl = _extractFeaturedImage(document, uri);

      // Generate suggested tags
      List<String> suggestedTags = _generateSuggestedTags(
        title,
        markdownContent,
      );

      return WebClipResult(
        title: title,
        content: markdownContent,
        sourceUrl: url,
        featuredImageUrl: featuredImageUrl,
        clippedAt: DateTime.now(),
        suggestedTags: suggestedTags,
      );
    } on TimeoutException catch (e) {
      debugPrint('Timeout clipping web page: $e');
      throw Exception(
        'Request timeout: The web page took too long to respond.',
      );
    } on FormatException catch (e) {
      debugPrint('Format error clipping web page: $e');
      throw Exception('Invalid content: Unable to parse the web page.');
    } on http.ClientException catch (e) {
      debugPrint('Network error clipping web page: $e');
      throw Exception(
        'Network error: Unable to reach the web page. Please check your internet connection.',
      );
    } catch (e) {
      debugPrint('Error clipping web page: $e');
      throw Exception('Failed to clip web page: $e');
    }
  }

  /// Extract the main content from HTML using a readability algorithm
  ///
  /// This method implements a simplified readability algorithm that:
  /// - Removes scripts, styles, and navigation elements
  /// - Identifies content-rich elements
  /// - Scores elements based on content density
  /// - Returns the highest-scoring content
  String extractMainContent(String htmlContent) {
    try {
      final document = html_parser.parse(htmlContent);

      // Remove unwanted elements
      _removeUnwantedElements(document);

      // Find the main content container
      dom.Element? mainElement = _findMainContentElement(document);

      // Fallback: try to find article or main tag
      mainElement ??=
          document.querySelector('article') ??
          document.querySelector('main') ??
          document.body;

      if (mainElement == null) {
        return '';
      }

      // Extract text content while preserving structure
      return _extractStructuredContent(mainElement);
    } catch (e) {
      debugPrint('Error extracting main content: $e');
      return '';
    }
  }

  /// Convert HTML content to Markdown format
  ///
  /// Preserves basic formatting including:
  /// - Headings (h1-h6)
  /// - Bold and italic text
  /// - Lists (ordered and unordered)
  /// - Links
  /// - Paragraphs
  String htmlToMarkdown(String htmlContent) {
    try {
      final document = html_parser.parse(htmlContent);
      final buffer = StringBuffer();

      _convertNodeToMarkdown(document.body, buffer, 0);

      return buffer.toString().trim();
    } catch (e) {
      debugPrint('Error converting HTML to markdown: $e');
      return htmlContent;
    }
  }

  /// Download and store a featured image
  ///
  /// Downloads the image from the given URL and uploads it to Cloudinary.
  /// Returns the Cloudinary secure URL.
  Future<String?> downloadFeaturedImage(String imageUrl, String userId) async {
    try {
      debugPrint('Downloading featured image: $imageUrl');

      // Validate URL
      final uri = Uri.tryParse(imageUrl);
      if (uri == null || !uri.hasScheme) {
        throw Exception('Invalid image URL: $imageUrl');
      }

      // Download image
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download image: HTTP ${response.statusCode}',
        );
      }

      // Verify it's an image
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.startsWith('image/')) {
        throw Exception('URL does not point to an image: $contentType');
      }

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getImageExtension(contentType);
      final tempPath = '${tempDir.path}/featured_$timestamp$extension';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(response.bodyBytes);

      // Upload to Cloudinary
      final fileName = 'featured_$timestamp$extension';
      final result = await _cloudinaryService.uploadImage(
        imageFile: tempFile,
        userId: userId,
        noteId: 'web_clip_$timestamp',
        fileName: fileName,
      );

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (e) {
        debugPrint('Failed to delete temp file: $e');
      }

      if (result.success && result.secureUrl != null) {
        debugPrint('Featured image uploaded: ${result.secureUrl}');
        return result.secureUrl;
      } else {
        debugPrint('Failed to upload featured image: ${result.errorMessage}');
        return null;
      }
    } catch (e) {
      debugPrint('Error downloading featured image: $e');
      // Return null instead of throwing - featured image is optional
      return null;
    }
  }

  // Private helper methods

  /// Remove unwanted elements from the document
  void _removeUnwantedElements(dom.Document document) {
    // Remove scripts, styles, and other non-content elements
    final unwantedSelectors = [
      'script',
      'style',
      'nav',
      'header',
      'footer',
      'aside',
      'iframe',
      'noscript',
      '.advertisement',
      '.ad',
      '.social-share',
      '.comments',
      '#comments',
    ];

    for (final selector in unwantedSelectors) {
      document.querySelectorAll(selector).forEach((element) {
        element.remove();
      });
    }
  }

  /// Find the main content element using a scoring algorithm
  dom.Element? _findMainContentElement(dom.Document document) {
    final candidates = document.querySelectorAll('div, article, section, main');

    if (candidates.isEmpty) {
      return null;
    }

    dom.Element? bestElement;
    double bestScore = 0.0;

    for (final element in candidates) {
      final score = _scoreElement(element);
      if (score > bestScore) {
        bestScore = score;
        bestElement = element;
      }
    }

    return bestElement;
  }

  /// Score an element based on content density and structure
  double _scoreElement(dom.Element element) {
    double score = 0.0;

    // Count paragraphs
    final paragraphs = element.querySelectorAll('p');
    score += paragraphs.length * 3.0;

    // Count text length
    final textLength = element.text.trim().length;
    score += textLength / 100.0;

    // Bonus for article-related class names
    final className = element.className.toLowerCase();
    if (className.contains('article') ||
        className.contains('content') ||
        className.contains('post') ||
        className.contains('entry')) {
      score += 10.0;
    }

    // Penalty for navigation-related class names
    if (className.contains('nav') ||
        className.contains('menu') ||
        className.contains('sidebar') ||
        className.contains('footer') ||
        className.contains('header')) {
      score -= 10.0;
    }

    // Bonus for semantic HTML5 tags
    if (element.localName == 'article' || element.localName == 'main') {
      score += 15.0;
    }

    return score;
  }

  /// Extract structured content from an element
  String _extractStructuredContent(dom.Element element) {
    final buffer = StringBuffer();

    for (final node in element.nodes) {
      if (node is dom.Element) {
        final tag = node.localName;

        // Handle different HTML elements
        if (tag == 'p' || tag == 'div') {
          final text = node.text.trim();
          if (text.isNotEmpty) {
            buffer.writeln(text);
            buffer.writeln();
          }
        } else if (tag == 'h1' ||
            tag == 'h2' ||
            tag == 'h3' ||
            tag == 'h4' ||
            tag == 'h5' ||
            tag == 'h6') {
          final text = node.text.trim();
          if (text.isNotEmpty) {
            buffer.writeln(text);
            buffer.writeln();
          }
        } else if (tag == 'ul' || tag == 'ol') {
          buffer.write(_extractStructuredContent(node));
        } else if (tag == 'li') {
          final text = node.text.trim();
          if (text.isNotEmpty) {
            buffer.writeln('• $text');
          }
        } else {
          // Recursively process child elements
          buffer.write(_extractStructuredContent(node));
        }
      } else if (node is dom.Text) {
        final text = node.text.trim();
        if (text.isNotEmpty) {
          buffer.write(text);
          buffer.write(' ');
        }
      }
    }

    return buffer.toString();
  }

  /// Convert a DOM node to Markdown recursively
  void _convertNodeToMarkdown(dom.Node? node, StringBuffer buffer, int depth) {
    if (node == null) return;

    if (node is dom.Element) {
      final tag = node.localName;

      switch (tag) {
        case 'h1':
          buffer.writeln('# ${node.text.trim()}');
          buffer.writeln();
          break;
        case 'h2':
          buffer.writeln('## ${node.text.trim()}');
          buffer.writeln();
          break;
        case 'h3':
          buffer.writeln('### ${node.text.trim()}');
          buffer.writeln();
          break;
        case 'h4':
          buffer.writeln('#### ${node.text.trim()}');
          buffer.writeln();
          break;
        case 'h5':
          buffer.writeln('##### ${node.text.trim()}');
          buffer.writeln();
          break;
        case 'h6':
          buffer.writeln('###### ${node.text.trim()}');
          buffer.writeln();
          break;
        case 'p':
          for (final child in node.nodes) {
            _convertNodeToMarkdown(child, buffer, depth);
          }
          buffer.writeln();
          buffer.writeln();
          break;
        case 'strong':
        case 'b':
          buffer.write('**${node.text.trim()}**');
          break;
        case 'em':
        case 'i':
          buffer.write('*${node.text.trim()}*');
          break;
        case 'a':
          final href = node.attributes['href'] ?? '';
          final text = node.text.trim();
          buffer.write('[$text]($href)');
          break;
        case 'ul':
          for (final child in node.children) {
            if (child.localName == 'li') {
              buffer.write('- ');
              _convertNodeToMarkdown(child, buffer, depth + 1);
              buffer.writeln();
            }
          }
          buffer.writeln();
          break;
        case 'ol':
          int index = 1;
          for (final child in node.children) {
            if (child.localName == 'li') {
              buffer.write('$index. ');
              _convertNodeToMarkdown(child, buffer, depth + 1);
              buffer.writeln();
              index++;
            }
          }
          buffer.writeln();
          break;
        case 'li':
          for (final child in node.nodes) {
            _convertNodeToMarkdown(child, buffer, depth);
          }
          break;
        case 'br':
          buffer.writeln();
          break;
        case 'code':
          buffer.write('`${node.text.trim()}`');
          break;
        case 'pre':
          buffer.writeln('```');
          buffer.writeln(node.text.trim());
          buffer.writeln('```');
          buffer.writeln();
          break;
        case 'blockquote':
          final lines = node.text.trim().split('\n');
          for (final line in lines) {
            buffer.writeln('> $line');
          }
          buffer.writeln();
          break;
        default:
          // For other elements, process children
          for (final child in node.nodes) {
            _convertNodeToMarkdown(child, buffer, depth);
          }
      }
    } else if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isNotEmpty) {
        buffer.write(text);
      }
    }
  }

  /// Extract the page title
  String _extractTitle(dom.Document document) {
    // Try Open Graph title first
    final ogTitle = document.querySelector('meta[property="og:title"]');
    if (ogTitle != null) {
      final content = ogTitle.attributes['content'];
      if (content != null && content.isNotEmpty) {
        return content;
      }
    }

    // Try Twitter title
    final twitterTitle = document.querySelector('meta[name="twitter:title"]');
    if (twitterTitle != null) {
      final content = twitterTitle.attributes['content'];
      if (content != null && content.isNotEmpty) {
        return content;
      }
    }

    // Fall back to <title> tag
    final titleElement = document.querySelector('title');
    if (titleElement != null) {
      return titleElement.text.trim();
    }

    // Last resort: use first h1
    final h1 = document.querySelector('h1');
    if (h1 != null) {
      return h1.text.trim();
    }

    return 'Untitled';
  }

  /// Extract the featured image URL
  String? _extractFeaturedImage(dom.Document document, Uri baseUri) {
    // Try Open Graph image
    final ogImage = document.querySelector('meta[property="og:image"]');
    if (ogImage != null) {
      final content = ogImage.attributes['content'];
      if (content != null && content.isNotEmpty) {
        return _resolveUrl(content, baseUri);
      }
    }

    // Try Twitter image
    final twitterImage = document.querySelector('meta[name="twitter:image"]');
    if (twitterImage != null) {
      final content = twitterImage.attributes['content'];
      if (content != null && content.isNotEmpty) {
        return _resolveUrl(content, baseUri);
      }
    }

    // Try to find the first large image in the article
    final images = document.querySelectorAll(
      'article img, main img, .content img',
    );
    for (final img in images) {
      final src = img.attributes['src'];
      if (src != null && src.isNotEmpty) {
        // Skip small images (likely icons or ads)
        final width = img.attributes['width'];
        final height = img.attributes['height'];

        if (width != null && height != null) {
          final w = int.tryParse(width) ?? 0;
          final h = int.tryParse(height) ?? 0;
          if (w < 200 || h < 200) {
            continue;
          }
        }

        return _resolveUrl(src, baseUri);
      }
    }

    return null;
  }

  /// Resolve a relative URL to an absolute URL
  String _resolveUrl(String url, Uri baseUri) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return url;
    }

    if (uri.hasScheme) {
      return url;
    }

    return baseUri.resolve(url).toString();
  }

  /// Generate suggested tags based on content
  List<String> _generateSuggestedTags(String title, String content) {
    final tags = <String>[];
    final text = '$title $content'.toLowerCase();

    // Common topic keywords
    final topicKeywords = {
      'technology': [
        'tech',
        'software',
        'programming',
        'code',
        'developer',
        'app',
      ],
      'business': ['business', 'startup', 'entrepreneur', 'company', 'market'],
      'science': ['science', 'research', 'study', 'experiment', 'discovery'],
      'health': ['health', 'medical', 'fitness', 'wellness', 'nutrition'],
      'education': ['education', 'learning', 'teaching', 'course', 'tutorial'],
      'design': ['design', 'ui', 'ux', 'interface', 'visual'],
      'finance': ['finance', 'money', 'investment', 'stock', 'crypto'],
      'travel': ['travel', 'trip', 'destination', 'tourism', 'vacation'],
    };

    for (final entry in topicKeywords.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          tags.add(entry.key);
          break;
        }
      }
    }

    // Limit to 5 tags
    return tags.take(5).toList();
  }

  /// Get file extension from content type
  String _getImageExtension(String contentType) {
    if (contentType.contains('jpeg') || contentType.contains('jpg')) {
      return '.jpg';
    } else if (contentType.contains('png')) {
      return '.png';
    } else if (contentType.contains('gif')) {
      return '.gif';
    } else if (contentType.contains('webp')) {
      return '.webp';
    }
    return '.jpg'; // Default
  }
}
