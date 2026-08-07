import 'package:flutter/material.dart';

class TopToolbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;

  const TopToolbar({
    super.key,
    required this.title,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}