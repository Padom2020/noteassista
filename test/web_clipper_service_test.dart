import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/services/web_clipper_service.dart';

void main() {
  group('Web Clipper Service Tests', () {
    late WebClipperService service;

    setUp(() {
      service = WebClipperService();
    });

    group('Data Models', () {
      test('WebClipResult contains expected fields', () {
        final result = WebClipResult(
          title: 'Test Article',
          content: 'Article content',
          sourceUrl: 'https://example.com',
          featuredImageUrl: 'https://example.com/image.jpg',
          clippedAt: DateTime(2024, 1, 1),
          suggestedTags: ['tech', 'programming'],
        );

        expect(result.title, equals('Test Article'));
        expect(result.content, equals('Article content'));
        expect(result.sourceUrl, equals('https://example.com'));
        expect(
          result.featuredImageUrl,
          equals('https://example.com/image.jpg'),
        );
        expect(result.suggestedTags, equals(['tech', 'programming']));
      });

      test('WebClipResult toString provides useful information', () {
        final result = WebClipResult(
          title: 'My Article',
          content: 'Content here',
          sourceUrl: 'https://test.com',
          clippedAt: DateTime.now(),
          suggestedTags: ['tag1', 'tag2'],
        );

        final str = result.toString();
        expect(str, contains('WebClipResult'));
        expect(str, contains('My Article'));
        expect(str, contains('https://test.com'));
        expect(str, contains('tag1'));
      });

      test('WebClipResult with null featured image', () {
        final result = WebClipResult(
          title: 'Article',
          content: 'Content',
          sourceUrl: 'https://example.com',
          featuredImageUrl: null,
          clippedAt: DateTime.now(),
          suggestedTags: [],
        );

        expect(result.featuredImageUrl, isNull);
        expect(result.suggestedTags, isEmpty);
      });
    });

    group('HTML to Markdown Conversion', () {
      test('preserves basic formatting', () {
        const html = '''
          <h1>Main Title</h1>
          <p>This is a <strong>bold</strong> and <em>italic</em> text.</p>
          <ul>
            <li>Item 1</li>
            <li>Item 2</li>
          </ul>
        ''';

        final markdown = service.htmlToMarkdown(html);

        expect(markdown, contains('# Main Title'));
        expect(markdown, contains('**bold**'));
        expect(markdown, contains('*italic*'));
        expect(markdown, contains('- Item 1'));
        expect(markdown, contains('- Item 2'));
      });

      test('handles links correctly', () {
        const html =
            '<p>Check out <a href="https://example.com">this link</a></p>';
        final markdown = service.htmlToMarkdown(html);
        expect(markdown, contains('[this link](https://example.com)'));
      });

      test('handles code blocks', () {
        const html = '<pre><code>function test() { return true; }</code></pre>';
        final markdown = service.htmlToMarkdown(html);
        expect(markdown, contains('```'));
        expect(markdown, contains('function test()'));
      });

      test('handles inline code', () {
        const html = '<p>Use the <code>print()</code> function</p>';
        final markdown = service.htmlToMarkdown(html);
        expect(markdown, contains('`print()`'));
      });

      test('handles blockquotes', () {
        const html = '<blockquote>This is a quote</blockquote>';
        final markdown = service.htmlToMarkdown(html);
        expect(markdown, contains('> This is a quote'));
      });

      test('handles ordered lists', () {
        const html = '''
          <ol>
            <li>First item</li>
            <li>Second item</li>
            <li>Third item</li>
          </ol>
        ''';

        final markdown = service.htmlToMarkdown(html);
        expect(markdown, contains('1. First item'));
        expect(markdown, contains('2. Second item'));
        expect(markdown, contains('3. Third item'));
      });

      test('handles nested formatting', () {
        const html =
            '<p>This is <strong>bold with <em>italic</em> inside</strong></p>';
        final markdown = service.htmlToMarkdown(html);
        expect(markdown, contains('**bold'));
        expect(markdown, contains('inside**'));
      });

      test('handles multiple heading levels', () {
        const html = '''
          <h1>Heading 1</h1>
          <h2>Heading 2</h2>
          <h3>Heading 3</h3>
          <h4>Heading 4</h4>
          <h5>Heading 5</h5>
          <h6>Heading 6</h6>
        ''';

        final markdown = service.htmlToMarkdown(html);
        expect(markdown, contains('# Heading 1'));
        expect(markdown, contains('## Heading 2'));
        expect(markdown, contains('### Heading 3'));
        expect(markdown, contains('#### Heading 4'));
        expect(markdown, contains('##### Heading 5'));
        expect(markdown, contains('###### Heading 6'));
      });

      test('handles br tags', () {
        const html = '<p>Line 1<br>Line 2</p>';
        final markdown = service.htmlToMarkdown(html);
        expect(markdown, contains('Line 1'));
        expect(markdown, contains('Line 2'));
      });

      test('handles empty HTML', () {
        const html = '<html><body></body></html>';
        final markdown = service.htmlToMarkdown(html);
        expect(markdown.trim(), isEmpty);
      });

      test('handles malformed HTML gracefully', () {
        const html = '<p>Unclosed paragraph<strong>Bold text';
        expect(() => service.htmlToMarkdown(html), returnsNormally);
      });

      test('handles nested lists', () {
        const html = '''
          <ul>
            <li>Item 1
              <ul>
                <li>Nested 1</li>
                <li>Nested 2</li>
              </ul>
            </li>
            <li>Item 2</li>
          </ul>
        ''';

        final markdown = service.htmlToMarkdown(html);
        expect(markdown, contains('- Item 1'));
        expect(markdown, contains('- Item 2'));
      });

      test('handles mixed content types', () {
        const html = '''
          <h2>Title</h2>
          <p>Paragraph with <strong>bold</strong> and <a href="http://test.com">link</a>.</p>
          <ul>
            <li>List item</li>
          </ul>
          <blockquote>Quote</blockquote>
          <pre><code>code block</code></pre>
        ''';

        final markdown = service.htmlToMarkdown(html);
        expect(markdown, contains('## Title'));
        expect(markdown, contains('**bold**'));
        expect(markdown, contains('[link](http://test.com)'));
        expect(markdown, contains('- List item'));
        expect(markdown, contains('> Quote'));
        expect(markdown, contains('```'));
      });
    });

    group('Main Content Extraction', () {
      test('removes unwanted elements', () {
        const html = '''
          <html>
            <head><title>Test</title></head>
            <body>
              <nav>Navigation</nav>
              <script>alert('test');</script>
              <article>
                <h1>Article Title</h1>
                <p>Article content here.</p>
              </article>
              <footer>Footer content</footer>
            </body>
          </html>
        ''';

        final content = service.extractMainContent(html);
        expect(content, contains('Article Title'));
        expect(content, contains('Article content here'));
        expect(content, isNot(contains('Navigation')));
        expect(content, isNot(contains('Footer content')));
        expect(content, isNot(contains('alert')));
      });

      test('prioritizes article tags', () {
        const html = '''
          <html>
            <body>
              <div>Some random div content</div>
              <article>
                <h1>Important Article</h1>
                <p>This is the main content.</p>
              </article>
            </body>
          </html>
        ''';

        final content = service.extractMainContent(html);
        expect(content, contains('Important Article'));
        expect(content, contains('This is the main content'));
      });

      test('handles empty HTML gracefully', () {
        const html = '<html><body></body></html>';
        final content = service.extractMainContent(html);
        expect(content, isEmpty);
      });

      test('removes style and script tags', () {
        const html = '''
          <html>
            <head>
              <style>body { color: red; }</style>
            </head>
            <body>
              <script>console.log('test');</script>
              <article>
                <p>Clean content</p>
              </article>
            </body>
          </html>
        ''';

        final content = service.extractMainContent(html);
        expect(content, contains('Clean content'));
        expect(content, isNot(contains('color: red')));
        expect(content, isNot(contains('console.log')));
      });

      test('removes navigation elements', () {
        const html = '''
          <html>
            <body>
              <nav><a href="/">Home</a></nav>
              <header><h1>Site Header</h1></header>
              <main>
                <article>
                  <h2>Article Title</h2>
                  <p>Article content</p>
                </article>
              </main>
              <aside>Sidebar content</aside>
              <footer>Copyright 2024</footer>
            </body>
          </html>
        ''';

        final content = service.extractMainContent(html);
        expect(content, contains('Article Title'));
        expect(content, contains('Article content'));
        expect(content, isNot(contains('Home')));
        expect(content, isNot(contains('Site Header')));
        expect(content, isNot(contains('Sidebar content')));
        expect(content, isNot(contains('Copyright')));
      });

      test('handles main tag', () {
        const html = '''
          <html>
            <body>
              <main>
                <h1>Main Content</h1>
                <p>This is the main content area.</p>
              </main>
            </body>
          </html>
        ''';

        final content = service.extractMainContent(html);
        expect(content, contains('Main Content'));
        expect(content, contains('This is the main content area'));
      });

      test('preserves paragraph structure', () {
        const html = '''
          <article>
            <p>First paragraph.</p>
            <p>Second paragraph.</p>
            <p>Third paragraph.</p>
          </article>
        ''';

        final content = service.extractMainContent(html);
        expect(content, contains('First paragraph'));
        expect(content, contains('Second paragraph'));
        expect(content, contains('Third paragraph'));
      });

      test('handles lists in content', () {
        const html = '''
          <article>
            <h2>Shopping List</h2>
            <ul>
              <li>Apples</li>
              <li>Bananas</li>
              <li>Oranges</li>
            </ul>
          </article>
        ''';

        final content = service.extractMainContent(html);
        expect(content, contains('Shopping List'));
        expect(content, contains('Apples'));
        expect(content, contains('Bananas'));
        expect(content, contains('Oranges'));
      });

      test('removes advertisement classes', () {
        const html = '''
          <article>
            <p>Real content</p>
            <div class="advertisement">Ad content</div>
            <div class="ad">Another ad</div>
            <p>More real content</p>
          </article>
        ''';

        final content = service.extractMainContent(html);
        expect(content, contains('Real content'));
        expect(content, contains('More real content'));
        expect(content, isNot(contains('Ad content')));
        expect(content, isNot(contains('Another ad')));
      });

      test('handles complex nested structure', () {
        const html = '''
          <html>
            <body>
              <div class="container">
                <div class="sidebar">Sidebar</div>
                <div class="content">
                  <article>
                    <h1>Article</h1>
                    <div class="author">By John Doe</div>
                    <p>Article text</p>
                  </article>
                </div>
              </div>
            </body>
          </html>
        ''';

        final content = service.extractMainContent(html);
        expect(content, contains('Article'));
        expect(content, contains('Article text'));
      });
    });

    group('Edge Cases', () {
      test('handles null or empty content', () {
        const html = '';
        expect(() => service.htmlToMarkdown(html), returnsNormally);
        expect(() => service.extractMainContent(html), returnsNormally);
      });

      test('handles HTML with only whitespace', () {
        const html = '   \n\n   ';
        final markdown = service.htmlToMarkdown(html);
        expect(markdown.trim(), isEmpty);
      });

      test('handles special characters in content', () {
        const html = '<p>Special chars: &lt; &gt; &amp; &quot; &#39;</p>';
        final markdown = service.htmlToMarkdown(html);
        expect(markdown, contains('Special chars'));
      });

      test('handles very long content', () {
        final longText = 'A' * 10000;
        final html = '<article><p>$longText</p></article>';

        expect(() => service.extractMainContent(html), returnsNormally);
        final content = service.extractMainContent(html);
        expect(content.length, greaterThan(9000));
      });

      test('handles deeply nested elements', () {
        const html = '''
          <div><div><div><div><div>
            <article>
              <p>Deeply nested content</p>
            </article>
          </div></div></div></div></div>
        ''';

        final content = service.extractMainContent(html);
        expect(content, contains('Deeply nested content'));
      });

      test('handles HTML entities', () {
        const html = '<p>Price: &pound;100 &euro;200 &yen;300</p>';
        expect(() => service.htmlToMarkdown(html), returnsNormally);
      });

      test('handles comments in HTML', () {
        const html = '''
          <article>
            <!-- This is a comment -->
            <p>Visible content</p>
            <!-- Another comment -->
          </article>
        ''';

        final content = service.extractMainContent(html);
        expect(content, contains('Visible content'));
        expect(content, isNot(contains('This is a comment')));
      });

      test('handles iframe tags', () {
        const html = '''
          <article>
            <p>Before iframe</p>
            <iframe src="https://example.com"></iframe>
            <p>After iframe</p>
          </article>
        ''';

        final content = service.extractMainContent(html);
        expect(content, contains('Before iframe'));
        expect(content, contains('After iframe'));
        // iframe tags are removed by _removeUnwantedElements, so the word 'iframe' shouldn't appear
        // However, the test should check that the iframe element itself is removed, not the word
        expect(content, isNot(contains('<iframe')));
      });

      test('handles noscript tags', () {
        const html = '''
          <article>
            <p>Main content</p>
            <noscript>Please enable JavaScript</noscript>
          </article>
        ''';

        final content = service.extractMainContent(html);
        expect(content, contains('Main content'));
        expect(content, isNot(contains('Please enable JavaScript')));
      });
    });

    group('Complex Scenarios', () {
      test('handles blog post structure', () {
        const html = '''
          <html>
            <body>
              <header>
                <nav>Navigation</nav>
              </header>
              <main>
                <article>
                  <h1>Blog Post Title</h1>
                  <div class="meta">Posted on Jan 1, 2024</div>
                  <p>Introduction paragraph.</p>
                  <h2>Section 1</h2>
                  <p>Section 1 content.</p>
                  <h2>Section 2</h2>
                  <p>Section 2 content.</p>
                  <h2>Conclusion</h2>
                  <p>Conclusion paragraph.</p>
                </article>
              </main>
              <aside class="social-share">Share this</aside>
              <footer>Footer</footer>
            </body>
          </html>
        ''';

        final content = service.extractMainContent(html);
        expect(content, contains('Blog Post Title'));
        expect(content, contains('Introduction paragraph'));
        expect(content, contains('Section 1'));
        expect(content, contains('Section 2'));
        expect(content, contains('Conclusion'));
        expect(content, isNot(contains('Navigation')));
        expect(content, isNot(contains('Share this')));
      });

      test('handles news article structure', () {
        const html = '''
          <article>
            <h1>Breaking News</h1>
            <div class="byline">By Reporter Name</div>
            <time>2024-01-01</time>
            <p class="lead">Lead paragraph with key information.</p>
            <p>Additional details in second paragraph.</p>
            <blockquote>Quote from source</blockquote>
            <p>More context and analysis.</p>
          </article>
        ''';

        final markdown = service.htmlToMarkdown(html);
        expect(markdown, contains('# Breaking News'));
        expect(markdown, contains('Lead paragraph'));
        expect(markdown, contains('Additional details'));
        expect(markdown, contains('> Quote from source'));
        expect(markdown, contains('More context'));
      });

      test('handles recipe structure', () {
        const html = '''
          <article>
            <h1>Chocolate Cake Recipe</h1>
            <h2>Ingredients</h2>
            <ul>
              <li>2 cups flour</li>
              <li>1 cup sugar</li>
              <li>3 eggs</li>
            </ul>
            <h2>Instructions</h2>
            <ol>
              <li>Mix dry ingredients</li>
              <li>Add wet ingredients</li>
              <li>Bake at 350°F</li>
            </ol>
          </article>
        ''';

        final markdown = service.htmlToMarkdown(html);
        expect(markdown, contains('# Chocolate Cake Recipe'));
        expect(markdown, contains('## Ingredients'));
        expect(markdown, contains('- 2 cups flour'));
        expect(markdown, contains('## Instructions'));
        expect(markdown, contains('1. Mix dry ingredients'));
      });

      test('handles technical documentation', () {
        const html = '''
          <article>
            <h1>API Documentation</h1>
            <p>This API endpoint returns user data.</p>
            <h2>Request</h2>
            <pre><code>GET /api/users/:id</code></pre>
            <h2>Response</h2>
            <pre><code>{ "id": 1, "name": "John" }</code></pre>
          </article>
        ''';

        final markdown = service.htmlToMarkdown(html);
        expect(markdown, contains('# API Documentation'));
        expect(markdown, contains('## Request'));
        expect(markdown, contains('```'));
        expect(markdown, contains('GET /api/users/:id'));
      });
    });

    group('Markdown Formatting Edge Cases', () {
      test('handles empty paragraphs', () {
        const html = '<p></p><p>Content</p><p></p>';
        final markdown = service.htmlToMarkdown(html);
        expect(markdown, contains('Content'));
      });

      test('handles paragraphs with only whitespace', () {
        const html = '<p>   </p><p>Real content</p>';
        final markdown = service.htmlToMarkdown(html);
        expect(markdown, contains('Real content'));
      });

      test('handles links without href', () {
        const html = '<p><a>Link without href</a></p>';
        expect(() => service.htmlToMarkdown(html), returnsNormally);
      });

      test('handles images (should be ignored or handled)', () {
        const html = '<p>Text <img src="image.jpg" alt="Image"> more text</p>';
        expect(() => service.htmlToMarkdown(html), returnsNormally);
      });

      test('handles tables (basic support)', () {
        const html = '''
          <table>
            <tr><td>Cell 1</td><td>Cell 2</td></tr>
            <tr><td>Cell 3</td><td>Cell 4</td></tr>
          </table>
        ''';

        expect(() => service.htmlToMarkdown(html), returnsNormally);
      });
    });
  });
}
