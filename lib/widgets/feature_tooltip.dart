import 'package:flutter/material.dart';
import '../services/onboarding_service.dart';

/// A widget that shows a tooltip on first use
class FeatureTooltip extends StatefulWidget {
  final String tooltipId;
  final String message;
  final Widget child;
  final TooltipDirection direction;

  const FeatureTooltip({
    super.key,
    required this.tooltipId,
    required this.message,
    required this.child,
    this.direction = TooltipDirection.bottom,
  });

  @override
  State<FeatureTooltip> createState() => _FeatureTooltipState();
}

class _FeatureTooltipState extends State<FeatureTooltip> {
  bool _showTooltip = false;
  final OnboardingService _onboardingService = OnboardingService();
  OverlayEntry? _overlayEntry;
  final GlobalKey _childKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkAndShowTooltip();
  }

  Future<void> _checkAndShowTooltip() async {
    final hasSeenTooltip = await _onboardingService.hasSeenTooltip(
      widget.tooltipId,
    );
    if (!hasSeenTooltip && mounted) {
      // Delay to ensure widget is built
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        _showOverlayTooltip();
      }
    }
  }

  void _showOverlayTooltip() {
    final RenderBox? renderBox =
        _childKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildTooltipOverlay(position, size),
    );

    Overlay.of(context).insert(_overlayEntry!);

    setState(() {
      _showTooltip = true;
    });

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      _dismissTooltip();
    });
  }

  Future<void> _dismissTooltip() async {
    if (_showTooltip && _overlayEntry != null && mounted) {
      try {
        await _onboardingService.markTooltipAsSeen(widget.tooltipId);
        if (_overlayEntry != null) {
          _overlayEntry?.remove();
          _overlayEntry = null;
        }
        if (mounted) {
          setState(() {
            _showTooltip = false;
          });
        }
      } catch (e) {
        // Silently handle if overlay is already removed
        _overlayEntry = null;
      }
    }
  }

  @override
  void dispose() {
    try {
      _overlayEntry?.remove();
    } catch (e) {
      // Silently handle if overlay is already removed
    }
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(key: _childKey, child: widget.child);
  }

  Widget _buildTooltipOverlay(Offset position, Size size) {
    double left = position.dx;
    double top = position.dy;

    // Adjust position based on direction
    switch (widget.direction) {
      case TooltipDirection.top:
        top = position.dy - 80;
        break;
      case TooltipDirection.bottom:
        top = position.dy + size.height + 8;
        break;
      case TooltipDirection.left:
        left = position.dx - 200;
        top = position.dy;
        break;
      case TooltipDirection.right:
        left = position.dx + size.width + 8;
        top = position.dy;
        break;
    }

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _dismissTooltip,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 250),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _dismissTooltip,
                  child: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum TooltipDirection { top, bottom, left, right }
