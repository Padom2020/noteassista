import 'package:flutter/material.dart';
import '../services/onboarding_service.dart';

/// A widget that displays a feature tour overlay with spotlight and description
class FeatureTourOverlay extends StatefulWidget {
  final String featureId;
  final String title;
  final String description;
  final GlobalKey targetKey;
  final VoidCallback? onComplete;
  final Widget child;

  const FeatureTourOverlay({
    super.key,
    required this.featureId,
    required this.title,
    required this.description,
    required this.targetKey,
    this.onComplete,
    required this.child,
  });

  @override
  State<FeatureTourOverlay> createState() => _FeatureTourOverlayState();
}

class _FeatureTourOverlayState extends State<FeatureTourOverlay> {
  bool _showOverlay = false;
  final OnboardingService _onboardingService = OnboardingService();

  @override
  void initState() {
    super.initState();
    _checkAndShowTour();
  }

  Future<void> _checkAndShowTour() async {
    final hasSeenFeature = await _onboardingService.hasSeenFeature(
      widget.featureId,
    );
    if (!hasSeenFeature && mounted) {
      // Delay to ensure widget is built
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _showOverlay = true;
        });
      }
    }
  }

  Future<void> _dismissTour() async {
    await _onboardingService.markFeatureAsSeen(widget.featureId);
    setState(() {
      _showOverlay = false;
    });
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showOverlay) Positioned.fill(child: _buildOverlay()),
      ],
    );
  }

  Widget _buildOverlay() {
    // Get the position and size of the target widget
    final RenderBox? renderBox =
        widget.targetKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) {
      return const SizedBox.shrink();
    }

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    return Material(
      color: Colors.black.withValues(alpha: 0.8),
      child: GestureDetector(
        onTap: _dismissTour,
        child: Stack(
          children: [
            // Spotlight hole
            CustomPaint(
              size: Size.infinite,
              painter: _SpotlightPainter(
                spotlightRect: Rect.fromLTWH(
                  position.dx - 8,
                  position.dy - 8,
                  size.width + 16,
                  size.height + 16,
                ),
              ),
            ),

            // Description card
            Positioned(
              left: 16,
              right: 16,
              top: position.dy + size.height + 24,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb,
                            color: Colors.amber[700],
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.description,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _dismissTour,
                          child: const Text('Got it!'),
                        ),
                      ),
                    ],
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

/// Custom painter to create a spotlight effect
class _SpotlightPainter extends CustomPainter {
  final Rect spotlightRect;

  _SpotlightPainter({required this.spotlightRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;

    // Draw the full overlay
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Cut out the spotlight area
    final spotlightPaint =
        Paint()
          ..color = Colors.transparent
          ..blendMode = BlendMode.clear;

    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlightRect, const Radius.circular(12)),
      spotlightPaint,
    );

    // Draw spotlight border
    final borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlightRect, const Radius.circular(12)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) {
    return oldDelegate.spotlightRect != spotlightRect;
  }
}
