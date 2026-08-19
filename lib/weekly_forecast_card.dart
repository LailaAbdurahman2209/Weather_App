import 'package:flutter/material.dart';

class WeeklyForecastCard extends StatelessWidget {
  final List<dynamic> dailyTimes;
  final List<dynamic> dailyMaxTemps;
  final List<dynamic> dailyMinTemps;
  final List<dynamic> dailyWeatherCodes;
  final bool isDarkMode;

  const WeeklyForecastCard({
    super.key,
    required this.dailyTimes,
    required this.dailyMaxTemps,
    required this.dailyMinTemps,
    required this.dailyWeatherCodes,
    required this.isDarkMode,
  });

  // Helper to map weather codes to icons/colors
  Map<String, dynamic> _getWeatherInfo(int code) {
    if (code == 0) {
      return {'icon': Icons.wb_sunny_rounded, 'color': Colors.amberAccent};
    }
    if (code <= 3) {
      return {'icon': Icons.cloud_queue_rounded, 'color': Colors.lightBlueAccent};
    }
    if (code <= 48) return {'icon': Icons.foggy, 'color': Colors.blueGrey};
    if (code <= 67) return {'icon': Icons.water_drop_rounded, 'color': Colors.cyanAccent};
    if (code <= 77) return {'icon': Icons.ac_unit_rounded, 'color': Colors.white};
    return {'icon': Icons.flash_on_rounded, 'color': Colors.purpleAccent};
  }

  // Format date string natively (e.g., "2026-08-19" -> "Today" or "Wed")
  String _formatDay(String dateStr, int index) {
    if (index == 0) return 'Today';
    try {
      DateTime dateTime = DateTime.parse(dateStr);
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    } catch (_) {
      return 'Day';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDarkMode ? Colors.white70 : const Color(0xFF334155);
    final cardBg = isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04);
    final cardBorder = isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    if (dailyTimes.isEmpty) return const SizedBox.shrink();

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
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: subtextColor, size: 18),
              const SizedBox(width: 8),
              Text(
                '7-Day Forecast',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dailyTimes.length > 7 ? 7 : dailyTimes.length,
            itemBuilder: (context, index) {
              final dayString = _formatDay(dailyTimes[index], index);
              final maxTemp = (dailyMaxTemps[index] as num).toDouble();
              final minTemp = (dailyMinTemps[index] as num).toDouble();
              final code = (dailyWeatherCodes[index] as num).toInt();
              final weatherInfo = _getWeatherInfo(code);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Day Name
                    SizedBox(
                      width: 70,
                      child: Text(
                        dayString,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Weather Icon
                    Icon(
                      weatherInfo['icon'],
                      color: weatherInfo['color'],
                      size: 22,
                    ),
                    // Min / Max Temperatures
                    Row(
                      children: [
                        Text(
                          '${minTemp.toStringAsFixed(0)}°',
                          style: TextStyle(
                            color: subtextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: LinearProgressIndicator(
                            value: 0.5, // Can scale dynamically if needed
                            backgroundColor: cardBorder,
                            color: const Color(0xFF38BDF8),
                            minHeight: 4.0, // Fixed: changed from minRating to minHeight
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${maxTemp.toStringAsFixed(0)}°',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}