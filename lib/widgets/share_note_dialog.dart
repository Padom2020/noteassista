import 'package:flutter/material.dart';
import '../services/collaboration_service.dart';
import '../models/collaborator_model.dart';

/// Dialog for sharing a note with collaborators
/// Allows adding collaborators by email and managing existing collaborators
class ShareNoteDialog extends StatefulWidget {
  final String userId;
  final String noteId;
  final CollaborationService collaborationService;

  const ShareNoteDialog({
    super.key,
    required this.userId,
    required this.noteId,
    required this.collaborationService,
  });

  @override
  State<ShareNoteDialog> createState() => _ShareNoteDialogState();
}

class _ShareNoteDialogState extends State<ShareNoteDialog> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  List<CollaboratorModel> _collaborators = [];
  bool _isLoadingCollaborators = true;
  CollaboratorRole _selectedRole = CollaboratorRole.editor;

  @override
  void initState() {
    super.initState();
    _loadCollaborators();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadCollaborators() async {
    try {
      final collaborators = await widget.collaborationService
          .getCollaboratorDetails(widget.userId, widget.noteId);

      if (mounted) {
        setState(() {
          _collaborators = collaborators;
          _isLoadingCollaborators = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCollaborators = false;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading collaborators: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _addCollaborator() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();

      await widget.collaborationService.shareNote(
        widget.userId,
        widget.noteId,
        [email],
        role: _selectedRole,
      );

      if (!mounted) return;

      _emailController.clear();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collaborator added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload collaborators
      await _loadCollaborators();
    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'Error adding collaborator: $e';
      if (e.toString().contains('not found') ||
          e.toString().contains('0 rows')) {
        errorMessage =
            'User with email "${_emailController.text.trim()}" not found. They may need to sign up first.';
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeCollaborator(String collaboratorId) async {
    try {
      await widget.collaborationService.removeCollaborator(
        widget.userId,
        widget.noteId,
        collaboratorId,
      );

      if (!mounted) return;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collaborator removed'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload collaborators
      await _loadCollaborators();
    } catch (e) {
      if (!mounted) return;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing collaborator: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(Icons.share, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Share Note',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Add collaborator form
                    Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Email address',
                                    hintText: 'Enter collaborator email',
                                    prefixIcon: Icon(Icons.email),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  enabled: !_isLoading,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter an email';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _addCollaborator,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                  ),
                                  child:
                                      _isLoading
                                          ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : const Text('Add'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Role selector
                          Row(
                            children: [
                              const Text('Role: '),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SegmentedButton<CollaboratorRole>(
                                  segments: const [
                                    ButtonSegment(
                                      value: CollaboratorRole.viewer,
                                      label: Text('Viewer'),
                                      icon: Icon(Icons.visibility, size: 16),
                                    ),
                                    ButtonSegment(
                                      value: CollaboratorRole.editor,
                                      label: Text('Editor'),
                                      icon: Icon(Icons.edit, size: 16),
                                    ),
                                  ],
                                  selected: {_selectedRole},
                                  onSelectionChanged: (
                                    Set<CollaboratorRole> newSelection,
                                  ) {
                                    setState(() {
                                      _selectedRole = newSelection.first;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Collaborators list
                    const Text(
                      'Current Collaborators',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Loading indicator
                    if (_isLoadingCollaborators)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),

                    // Empty state
                    if (!_isLoadingCollaborators && _collaborators.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No collaborators yet',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Collaborators list
                    if (!_isLoadingCollaborators && _collaborators.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _collaborators.length,
                        itemBuilder: (context, index) {
                          final collaborator = _collaborators[index];
                          return _CollaboratorListItem(
                            collaborator: collaborator,
                            onRemove:
                                () => _removeCollaborator(collaborator.userId),
                          );
                        },
                      ),

                    const SizedBox(height: 16),

                    // Info text
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Collaborators can view and edit this note in real-time',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom padding
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// List item for displaying a collaborator
class _CollaboratorListItem extends StatefulWidget {
  final CollaboratorModel collaborator;
  final VoidCallback onRemove;

  const _CollaboratorListItem({
    required this.collaborator,
    required this.onRemove,
  });

  @override
  State<_CollaboratorListItem> createState() => _CollaboratorListItemState();
}

class _CollaboratorListItemState extends State<_CollaboratorListItem> {
  void _showRoleChangeMenu() {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 0, 0),
      items: [
        PopupMenuItem(
          value: CollaboratorRole.viewer,
          child: Row(
            children: [
              Icon(
                Icons.visibility,
                size: 18,
                color: _getRoleColor(CollaboratorRole.viewer),
              ),
              const SizedBox(width: 8),
              const Text('Viewer'),
            ],
          ),
        ),
        PopupMenuItem(
          value: CollaboratorRole.editor,
          child: Row(
            children: [
              Icon(
                Icons.edit,
                size: 18,
                color: _getRoleColor(CollaboratorRole.editor),
              ),
              const SizedBox(width: 8),
              const Text('Editor'),
            ],
          ),
        ),
      ],
    ).then((newRole) {
      if (newRole != null && newRole != widget.collaborator.role) {
        _changeRole(newRole);
      }
    });
  }

  Future<void> _changeRole(CollaboratorRole newRole) async {
    try {
      // Get the collaboration service from the parent widget
      final shareDialog =
          context.findAncestorStateOfType<_ShareNoteDialogState>();
      if (shareDialog != null) {
        await shareDialog.widget.collaborationService.updateCollaboratorRole(
          shareDialog.widget.userId,
          shareDialog.widget.noteId,
          widget.collaborator.userId,
          newRole,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Role updated successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Reload collaborators
          await shareDialog._loadCollaborators();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
              child: Text(
                _getInitials(widget.collaborator.displayName),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name and email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.collaborator.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.collaborator.email,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Role badge (clickable for non-owners)
            InkWell(
              onTap:
                  widget.collaborator.role != CollaboratorRole.owner
                      ? _showRoleChangeMenu
                      : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRoleColor(
                    widget.collaborator.role,
                  ).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getRoleText(widget.collaborator.role),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getRoleColor(widget.collaborator.role),
                      ),
                    ),
                    if (widget.collaborator.role != CollaboratorRole.owner) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: _getRoleColor(widget.collaborator.role),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Remove button (only show for non-owners)
            if (widget.collaborator.role != CollaboratorRole.owner)
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.red,
                  onPressed: widget.onRemove,
                  tooltip: 'Remove collaborator',
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                ),
              ),
          ],
        ),
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

  String _getRoleText(CollaboratorRole role) {
    switch (role) {
      case CollaboratorRole.owner:
        return 'Owner';
      case CollaboratorRole.editor:
        return 'Editor';
      case CollaboratorRole.viewer:
        return 'Viewer';
    }
  }

  Color _getRoleColor(CollaboratorRole role) {
    switch (role) {
      case CollaboratorRole.owner:
        return Colors.purple;
      case CollaboratorRole.editor:
        return Colors.green;
      case CollaboratorRole.viewer:
        return Colors.blue;
    }
  }
}
