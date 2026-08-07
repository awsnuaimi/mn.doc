import 'package:flutter/material.dart';

class FloatingToolbar extends StatelessWidget {
  final Offset position;

  final VoidCallback? onEdit;
  final VoidCallback? onColor;
  final VoidCallback? onFont;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;

  const FloatingToolbar({
    super.key,
    required this.position,
    this.onEdit,
    this.onColor,
    this.onFont,
    this.onCopy,
    this.onDelete,
  });

  Widget _btn(
    IconData icon,
    VoidCallback? onPressed,
  ) {
    return IconButton(
      icon: Icon(icon, size: 20),
      splashRadius: 20,
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _btn(Icons.edit, onEdit),
              _btn(Icons.palette, onColor),
              _btn(Icons.format_size, onFont),
              _btn(Icons.copy, onCopy),
              _btn(Icons.delete, onDelete),
            ],
          ),
        ),
      ),
    );
  }
}