import 'package:flutter/material.dart';
import 'package:notepad/core/extensions/context_extensions.dart';

class ScrollToTopFab extends StatelessWidget {
  const ScrollToTopFab({
    required this.scrollController,
    required this.showScrollToTopBtn,
    required this.heroTag,
    this.additionalCondition = true,
    this.onPressed,
    super.key,
  });

  final ScrollController scrollController;
  final ValueNotifier<bool> showScrollToTopBtn;
  final String heroTag;

  final bool additionalCondition;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: ValueListenableBuilder<bool>(
          valueListenable: showScrollToTopBtn,
          builder: (context, showBtn, _) {
            final bool isVisible = showBtn && additionalCondition;

            return AnimatedOpacity(
              opacity: isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !isVisible,
                child: FloatingActionButton.small(
                  heroTag: heroTag,
                  backgroundColor: isDark
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFF3F3F3),
                  foregroundColor: isDark ? Colors.white : Colors.black,
                  onPressed: () {
                    scrollController.animateTo(
                      0.0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.fastOutSlowIn,
                    );
                    onPressed?.call();
                  },
                  child: const Icon(Icons.arrow_upward),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
