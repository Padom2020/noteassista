import 'package:flutter/material.dart';
import '../services/collaboration_service.dart';

/// Widget that displays a horizontal list of collaborator avatars
/// Shows who is currently viewing or editing a note
class CollaboratorAvatarList extends StatelessWidget {
  final String noteId;
  final CollaborationService collaborationService;
  final VoidCallback? onTap;

  const CollaboratorAvatarList({
    super.key,
    required this.noteId,
    required this.collaborationService,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Collaborator>>(
      stream: collaborationService.getActiveCollaborators(noteId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final collaborators = snapshot.data!;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Display up to 5 avatars
                ...collaborators.take(5).map((collaborator) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _CollaboratorAvatar(collaborator: collaborator),
                  );
                }),
                // Show count if more than 5 collaborators
                if (collaborators.length > 5)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '+${collaborators.length - 5}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Individual collaborator avatar with presence indicator
class _CollaboratorAvatar extends StatelessWidget {
  final Collaborator collaborator;

  const _CollaboratorAvatar({required this.collaborator});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${collaborator.displayName} (${_getStatusText()})',
      child: Stack(
        children: [
          // Avatar circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: collaborator.cursorColor.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(color: collaborator.cursorColor, width: 2),
            ),
            child: Center(
              child: Text(
                _getInitials(collaborator.displayName),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: collaborator.cursorColor,
                ),
              ),
            ),
          ),
          // Presence indicator dot
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _getPresenceColor(),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _getStatusText() {
    switch (collaborator.status) {
      case PresenceStatus.viewing:
        return 'viewing';
      case PresenceStatus.editing:
        return 'editing';
      case PresenceStatus.away:
        return 'away';
    }
  }

  Color _getPresenceColor() {
    switch (collaborator.status) {
      case PresenceStatus.viewing:
        return Colors.blue;
      case PresenceStatus.editing:
        return Colors.green;
      case PresenceStatus.away:
        return Colors.grey;
    }
  }
}
