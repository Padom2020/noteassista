import 'package:flutter/material.dart';
import '../services/onboarding_service.dart';

/// Screen to display new features and updates
class WhatsNewScreen extends StatelessWidget {
  final String version;

  const WhatsNewScreen({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('What\'s New'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.celebration,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome to NoteAssista $version',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Discover powerful new features',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Features list
                  _buildFeatureCard(
                    context,
                    icon: Icons.mic,
                    iconColor: Colors.red,
                    title: 'Voice-to-Text',
                    description:
                        'Create notes by speaking. Tap the red microphone button to start voice capture.',
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.account_tree,
                    iconColor: Colors.blue,
                    title: 'Graph View',
                    description:
                        'Visualize connections between your notes with an interactive graph.',
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.link,
                    iconColor: Colors.purple,
                    title: 'Linked Notes',
                    description:
                        'Connect notes using [[Note Title]] syntax to build your knowledge network.',
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.people,
                    iconColor: Colors.green,
                    title: 'Real-time Collaboration',
                    description:
                        'Share notes and edit together with your team in real-time.',
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.camera_alt,
                    iconColor: Colors.orange,
                    title: 'OCR & Image Capture',
                    description:
                        'Extract text from photos of documents and whiteboards.',
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.folder,
                    iconColor: Colors.teal,
                    title: 'Folders & Organization',
                    description:
                        'Organize notes into folders and sub-folders for better structure.',
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.notifications,
                    iconColor: Colors.amber,
                    title: 'Smart Reminders',
                    description:
                        'Set time-based and location-based reminders for your notes.',
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.bar_chart,
                    iconColor: Colors.indigo,
                    title: 'Statistics & Insights',
                    description:
                        'Track your note-taking habits and productivity trends.',
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.today,
                    iconColor: Colors.pink,
                    title: 'Daily Notes',
                    description:
                        'Maintain a daily journal with automatic note creation.',
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.description,
                    iconColor: Colors.cyan,
                    title: 'Templates Library',
                    description:
                        'Use pre-built templates or create your own for common note types.',
                  ),

                  const SizedBox(height: 16),

                  // Learn more section
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pro Tip',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Look for tooltips and hints throughout the app to learn more about each feature. You can always access this screen from the app menu.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final onboardingService = OnboardingService();
                    await onboardingService.updateAppVersion(version);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Get Started'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
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
}
