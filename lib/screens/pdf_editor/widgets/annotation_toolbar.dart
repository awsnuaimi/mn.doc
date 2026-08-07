import 'package:flutter/material.dart';

class AnnotationToolbar extends StatelessWidget {
  final bool drawMode;
  final bool eraserMode;
  final bool shapeEditMode;

  final VoidCallback onDraw;
  final VoidCallback onErase;
  final VoidCallback onShapeEdit;
  final VoidCallback onSettings;

  const AnnotationToolbar({
    super.key,
    required this.drawMode,
    required this.eraserMode,
    required this.shapeEditMode,
    required this.onDraw,
    required this.onErase,
    required this.onShapeEdit,
    required this.onSettings,
  });

  Widget _chip({
    required IconData icon,
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 18,
          color: selected ? Colors.white : Colors.blue,
        ),
        label: Text(text),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [

          _chip(
            icon: Icons.draw,
            text: "قلم",
            selected: drawMode,
            onTap: onDraw,
          ),

          _chip(
            icon: Icons.auto_fix_off,
            text: "ممحاة",
            selected: eraserMode,
            onTap: onErase,
          ),

          _chip(
            icon: Icons.open_with,
            text: "تعديل",
            selected: shapeEditMode,
            onTap: onShapeEdit,
          ),

          IconButton(
            onPressed: onSettings,
            icon: const Icon(Icons.tune),
          ),

        ],
      ),
    );
  }
}