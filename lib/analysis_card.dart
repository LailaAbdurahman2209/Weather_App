import 'package:flutter/material.dart';

class TodayAnalysisCard extends StatelessWidget {
  final bool isDarkMode;

  const TodayAnalysisCard({
    super.key,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    // Theme-aware dynamic styling variables
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDarkMode ? Colors.white70 : const Color(0xFF334155);
    final cardBg = isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04);
    final cardBorder = isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.1 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF38BDF8),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                "Today's Analysis",
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Description Text
          Text(
            "Temperatures will remain mild throughout the morning, with rainfall probability increasing after 15:00. Winds are expected to strengthen toward the evening.",
            style: TextStyle(
              color: subtextColor,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          
          // Recommendation Callout Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFF38BDF8),
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Outdoor activities are best completed before 14:00.",
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}