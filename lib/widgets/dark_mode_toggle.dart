import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/theme_provider.dart';

/// Drop this into any profile screen's settings section.
/// Shows current mode and a 3-way picker (System / Light / Dark).
class DarkModeToggle extends StatelessWidget {
  const DarkModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final border = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = isDark ? Colors.grey.shade400 : Colors.grey.shade500;
    final accentColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Appearance",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _modeLabel(provider.mode),
                      style: TextStyle(color: mutedColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ModeSelector(
            current: provider.mode,
            accent: accentColor,
            isDark: isDark,
            onChanged: (mode) => provider.setMode(mode),
          ),
        ],
      ),
    );
  }

  String _modeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return "Follows your phone setting";
      case ThemeMode.light:
        return "Always light";
      case ThemeMode.dark:
        return "Always dark";
    }
  }
}

class _ModeSelector extends StatelessWidget {
  final ThemeMode current;
  final Color accent;
  final bool isDark;
  final ValueChanged<ThemeMode> onChanged;

  const _ModeSelector({
    required this.current,
    required this.accent,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _option(ThemeMode.system, Icons.brightness_auto_rounded, "Auto"),
        const SizedBox(width: 8),
        _option(ThemeMode.light, Icons.light_mode_rounded, "Light"),
        const SizedBox(width: 8),
        _option(ThemeMode.dark, Icons.dark_mode_rounded, "Dark"),
      ],
    );
  }

  Widget _option(ThemeMode mode, IconData icon, String label) {
    final selected = current == mode;
    final inactiveBg = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.grey.shade100;
    final inactiveBorder = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade200;
    final inactiveText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent.withOpacity(0.15) : inactiveBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? accent.withOpacity(0.6) : inactiveBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? accent : inactiveText,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? accent : inactiveText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}