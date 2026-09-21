import 'package:flutter/material.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/note/services/links/link_service.dart';

// Renders the floating popup UI bar with action buttons for opening, copying, or sharing detected links.
class LinkMenuBar extends StatelessWidget {
  final NoteLinkType type;
  final bool isDark;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const LinkMenuBar({
    super.key,
    required this.type,
    required this.isDark,
    required this.onOpen,
    required this.onCopy,
    required this.onShare,
  });

  (String label, IconData icon) get _primaryConfig {
    switch (type) {
      case NoteLinkType.phone:
        return ('Call', Icons.phone);
      case NoteLinkType.mail:
        return ('Gmail', Icons.mail);
      case NoteLinkType.calendar:
        return ('Add Event', Icons.edit_calendar);
      case NoteLinkType.web:
        return ('Open', Icons.language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, icon) = _primaryConfig;

    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.linkPopupSurfaceDark
              : AppColors.linkPopupSurfaceLight,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: AppColors.linkPopupShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: onOpen,
              icon: Icon(icon, size: 18, color: AppColors.linkPopupPrimary),
              label: Text(
                label,
                style: const TextStyle(color: AppColors.linkPopupPrimary),
              ),
            ),
            TextButton.icon(
              onPressed: onCopy,
              icon: const Icon(
                Icons.copy,
                size: 18,
                color: AppColors.linkPopupSecondary,
              ),
              label: const Text(
                'Copy',
                style: TextStyle(color: AppColors.linkPopupSecondary),
              ),
            ),
            TextButton.icon(
              onPressed: onShare,
              icon: const Icon(
                Icons.share,
                size: 18,
                color: AppColors.linkPopupSuccess,
              ),
              label: const Text(
                'Share',
                style: TextStyle(color: AppColors.linkPopupSuccess),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
