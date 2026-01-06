import 'package:flutter/material.dart';
import 'whats_new_screen.dart';
import '../services/onboarding_service.dart';

/// Screen to display help and documentation
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Documentation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick start section
          _buildSectionHeader(
            context,
            icon: Icons.rocket_launch,
            title: 'Quick Start',
            color: Colors.blue,
          ),
          _buildHelpCard(
            context,
            title: 'Creating Your First Note',
            description:
                'Tap the + button at the bottom right to create a new note. You can add a title, description, tags, and choose a category.',
            icon: Icons.add_circle_outline,
          ),
          _buildHelpCard(
            context,
            title: 'Voice Capture',
            description:
                'Tap the red microphone button to create notes by speaking. Your speech will be transcribed automatically.',
            icon: Icons.mic,
          ),

          const SizedBox(height: 24),

          // Features section
          _buildSectionHeader(
            context,
            icon: Icons.star,
            title: 'Key Features',
            color: Colors.amber,
          ),
          _buildExpandableHelpCard(
            context,
            title: 'Linked Notes',
            summary: 'Connect related notes to build your knowledge network',
            details:
                'Use [[Note Title]] syntax to create links between notes. '
                'When you type [[, an autocomplete dropdown will appear. '
                'Linked notes appear as clickable links, and you can see backlinks '
                'at the bottom of each note showing which notes link to it.',
            icon: Icons.link,
          ),
          _buildExpandableHelpCard(
            context,
            title: 'Graph View',
            summary: 'Visualize connections between your notes',
            details:
                'Access the graph view from the home screen toolbar. '
                'Each note appears as a node, with links shown as edges. '
                'Tap a node to highlight its connections, double-tap to open the note. '
                'Use pinch-to-zoom and pan gestures to navigate.',
            icon: Icons.account_tree,
          ),
          _buildExpandableHelpCard(
            context,
            title: 'Collaboration',
            summary: 'Share notes and edit together in real-time',
            details:
                'Open a note and tap the share button to invite collaborators. '
                'You can add people by email and assign roles (viewer or editor). '
                'When multiple people edit simultaneously, you\'ll see their cursors '
                'and changes appear in real-time.',
            icon: Icons.people,
          ),
          _buildExpandableHelpCard(
            context,
            title: 'Folders',
            summary: 'Organize notes into folders and sub-folders',
            details:
                'Access folders from the home screen toolbar. '
                'Create new folders, nest them up to 5 levels deep, and assign colors. '
                'Drag and drop notes to move them between folders, or use the move dialog.',
            icon: Icons.folder,
          ),
          _buildExpandableHelpCard(
            context,
            title: 'Smart Reminders',
            summary: 'Set time-based and location-based reminders',
            details:
                'When creating or editing a note, tap the reminder button. '
                'You can set specific times, use natural language (e.g., "tomorrow at 3pm"), '
                'or set location-based reminders that trigger when you arrive at a place.',
            icon: Icons.notifications,
          ),
          _buildExpandableHelpCard(
            context,
            title: 'OCR & Image Capture',
            summary: 'Extract text from photos of documents',
            details:
                'Tap the camera button when creating a note to capture photos. '
                'Text will be automatically extracted using OCR. '
                'You can review and edit the extracted text before adding it to your note.',
            icon: Icons.camera_alt,
          ),
          _buildExpandableHelpCard(
            context,
            title: 'Templates',
            summary: 'Use pre-built templates for common note types',
            details:
                'Access templates when creating a new note. '
                'Choose from pre-built templates like meeting notes, project plans, '
                'or create your own custom templates. Templates can include variables '
                'that prompt you for input.',
            icon: Icons.description,
          ),
          _buildExpandableHelpCard(
            context,
            title: 'Daily Notes',
            summary: 'Maintain a daily journal automatically',
            details:
                'Tap the calendar icon in the toolbar to access daily notes. '
                'A note is automatically created for each day. '
                'View past daily notes in the calendar view and track your streak.',
            icon: Icons.today,
          ),
          _buildExpandableHelpCard(
            context,
            title: 'Statistics',
            summary: 'Track your note-taking habits and productivity',
            details:
                'Access statistics from the toolbar to see insights about your notes. '
                'View creation trends, most-used tags, word counts, and more. '
                'Export your statistics as an image or PDF to share.',
            icon: Icons.bar_chart,
          ),

          const SizedBox(height: 24),

          // Tips & tricks section
          _buildSectionHeader(
            context,
            icon: Icons.lightbulb,
            title: 'Tips & Tricks',
            color: Colors.orange,
          ),
          _buildHelpCard(
            context,
            title: 'Keyboard Shortcuts',
            description:
                'Use [[  to quickly create note links. The autocomplete will help you find existing notes.',
            icon: Icons.keyboard,
          ),
          _buildHelpCard(
            context,
            title: 'Search Operators',
            description:
                'Use tag:name, date:YYYY-MM-DD, or is:pinned in search to filter notes.',
            icon: Icons.search,
          ),
          _buildHelpCard(
            context,
            title: 'Pinning Notes',
            description:
                'Pin important notes to keep them at the top of your list for quick access.',
            icon: Icons.push_pin,
          ),

          const SizedBox(height: 24),

          // Action buttons
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => const WhatsNewScreen(version: '1.0.0'),
                  ),
                );
              },
              icon: const Icon(Icons.new_releases),
              label: const Text('View What\'s New'),
            ),
          ),
          const SizedBox(height: 12),

          // Reset onboarding button (for testing/re-showing tour)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final onboardingService = OnboardingService();
                await onboardingService.resetOnboarding();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Onboarding reset! Restart the app to see the tour again.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset Feature Tour'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableHelpCard(
    BuildContext context, {
    required String title,
    required String summary,
    required String details,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            summary,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                details,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
