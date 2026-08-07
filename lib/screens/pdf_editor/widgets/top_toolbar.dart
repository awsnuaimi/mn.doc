import 'package:flutter/material.dart';

class TopToolbar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> actions;

  const TopToolbar({
    super.key,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}