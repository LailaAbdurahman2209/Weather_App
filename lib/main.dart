import 'weekly_forecast_card.dart';
import 'analysis_card.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Weather App',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const WeatherScreen(),
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {

  // ==================== CONTROLLERS & STATE VARIABLES ====================
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _errorMessage = '';
  bool _isDarkMode = true; // Theme mode state toggle

  // Weather Data States
  String _cityName = 'Cape Town';
  double _currentTemp = 0.0;
  double _dailyMaxTemp = 0.0; 
  int _humidity = 0;
  double _windSpeed = 0.0;
  String _weatherDesc = '';
  IconData _weatherIcon = Icons.wb_sunny;
  Color _weatherIconColor = Colors.amber;

  // Hourly Forecast States
  List<dynamic> _hourlyTimes = [];
  List<dynamic> _hourlyTemps = [];
  List<dynamic> _hourlyCodes = [];
  List<dynamic> _hourlyIsDay = [];

  // Daily Forecast States
  List<dynamic> _dailyTimes = [];
  List<dynamic> _dailyMaxTemps = [];
  List<dynamic> _dailyMinTemps = [];
  List<dynamic> _dailyWeatherCodes = [];

  // Dynamic Theme Colors
  Color get _textColor => _isDarkMode ? Colors.white : const Color(0xFF0F172A);
  Color get _subtextColor => _isDarkMode ? Colors.white70 : const Color(0xFF334155);
  Color get _hintColor => _isDarkMode ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF64748B);
  Color get _cardBg => _isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04);
  Color get _cardBorder => _isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

  // ==================== LIFECYCLE METHODS ====================
  @override
  void initState() {
    super.initState();
    _fetchWeatherByCityName(_cityName);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==================== API & LOCATION SERVICES ====================

 /// Fetches weather data using the device's exact GPS coordinates.
  Future<void> _fetchWeatherByGPS() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _searchController.clear();
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are turned off. Please enable GPS.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions were denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied in settings.');
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final lat = position.latitude;
      final lon = position.longitude;

      // Reverse Geocode with Zoom level 18 (building/street level accuracy)
      final geoUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1&zoom=18');
      final geoResponse = await http.get(geoUrl, headers: {'User-Agent': 'FlutterWeatherApp_Test'});
      final geoData = jsonDecode(geoResponse.body);

      final address = geoData['address'] ?? {};
      
      // Clean up and prioritize hyper-local fields first
      String? localArea = address['suburb'] 
          ?? address['neighbourhood'] 
          ?? address['residential']
          ?? address['city_district'] 
          ?? address['quarter']
          ?? address['settlement']
          ?? address['hamlet'];     

      if (localArea != null && localArea.toLowerCase().contains('ward')) {
        localArea = null; 
      }

      // Fallback hierarchy if hyper-local fields are missing
      final resolvedName = localArea 
          ?? address['town'] 
          ?? address['city'] 
          ?? address['village'] 
          ?? address['municipality']
          ?? address['county']
          ?? 'Current Location';

      await _fetchWeatherForCoordinates(lat, lon, resolvedName);

    } catch (e, stackTrace) {
      developer.log('Error fetching weather by GPS', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// Fetches weather data by querying a city or suburb name string.
  Future<void> _fetchWeatherByCityName(String searchLocation) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final geoUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$searchLocation&format=json&addressdetails=1&limit=1');
      final geoResponse = await http.get(geoUrl, headers: {'User-Agent': 'FlutterWeatherApp_Test'});
      final List<dynamic> geoData = jsonDecode(geoResponse.body);

      if (geoData.isEmpty) {
        setState(() {
          _errorMessage = 'Location not found. Try adding the city.';
          _isLoading = false;
        });
        return;
      }

      final lat = double.parse(geoData[0]['lat']);
      final lon = double.parse(geoData[0]['lon']);
      
      final address = geoData[0]['address'] ?? {};
      String? localArea = address['neighbourhood']
          ?? address['suburb'] 
          ?? address['residential'];

      if (localArea != null && localArea.toLowerCase().contains('ward')) {
        localArea = null;
      }

      final resolvedName = localArea
          ?? address['town'] 
          ?? address['city'] 
          ?? address['village'] 
          ?? address['county']
          ?? geoData[0]['name'];

      await _fetchWeatherForCoordinates(lat, lon, resolvedName);
    } catch (e, stackTrace) {
      developer.log('Error fetching weather by city name: $searchLocation', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Failed to find location.';
        _isLoading = false;
      });
    }
  }

  /// Shared helper to query Open-Meteo forecast endpoints using latitude and longitude.
  Future<void> _fetchWeatherForCoordinates(double lat, double lon, String resolvedName) async {
    try {
      final weatherUrl = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,is_day&hourly=temperature_2m,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=auto');
      final weatherResponse = await http.get(weatherUrl);
      final weatherData = jsonDecode(weatherResponse.body);

      final current = weatherData['current'];
      final hourly = weatherData['hourly'];
      final daily = weatherData['daily'];
      final code = current['weather_code'];
      final isDay = (current['is_day'] as num?)?.toInt() == 1;
      
      final weatherInfo = _getWeatherInfo(code, isDay: isDay);

      setState(() {
        _cityName = resolvedName;
        _currentTemp = (current['temperature_2m'] as num).toDouble();
        _humidity = (current['relative_humidity_2m'] as num).toInt();
        _windSpeed = (current['wind_speed_10m'] as num).toDouble();
        _dailyMaxTemp = (daily['temperature_2m_max'][0] as num).toDouble();
        
        _dailyTimes = daily['time'];
        _dailyMaxTemps = daily['temperature_2m_max'];
        _dailyMinTemps = daily['temperature_2m_min'];
        _dailyWeatherCodes = daily['weather_code'];
        
        _weatherDesc = weatherInfo['desc'];
        _weatherIcon = weatherInfo['icon'];
        _weatherIconColor = weatherInfo['color'];

        _hourlyTimes = hourly['time'].take(24).toList();
        _hourlyTemps = hourly['temperature_2m'].take(24).toList();
        _hourlyCodes = hourly['weather_code'].take(24).toList();
        _hourlyIsDay = hourly['is_day'].take(24).toList();

        _isLoading = false;
      });
    } catch (e, stackTrace) {
      developer.log('Error retrieving forecast payload for coordinates ($lat, $lon)', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Failed to load weather forecast.';
        _isLoading = false;
      });
    }
  }

  // ==================== UTILITY & MAPPING METHODS ====================

  Map<String, dynamic> _getWeatherInfo(int code, {bool isDay = true}) {
    if (code == 0) {
      return {
        'desc': isDay ? 'Clear Sky' : 'Clear Night',
        'icon': isDay ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
        'color': isDay ? Colors.amberAccent : const Color(0xFF6366F1),
      };
    }
    if (code <= 3) {
      return {
        'desc': 'Partly Cloudy',
        'icon': isDay ? Icons.cloud_queue_rounded : Icons.nights_stay_rounded,
        'color': Colors.lightBlueAccent,
      };
    }
    if (code <= 48) return {'desc': 'Foggy', 'icon': Icons.foggy, 'color': Colors.blueGrey};
    if (code <= 67) return {'desc': 'Rain Showers', 'icon': Icons.water_drop_rounded, 'color': Colors.cyanAccent};
    if (code <= 77) return {'desc': 'Snowy', 'icon': Icons.ac_unit_rounded, 'color': Colors.white};
    return {'desc': 'Thunderstorm', 'icon': Icons.flash_on_rounded, 'color': Colors.purpleAccent};
  }

  String _formatTime(String isoTime) {
    final dateTime = DateTime.parse(isoTime);
    return '${dateTime.hour.toString().padLeft(2, '0')}:00';
  }

  // ==================== UI BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _isDarkMode
                ? const [
                    Color(0xFF1E1B4B),
                    Color(0xFF0F172A),
                    Color(0xFF090D16),
                  ]
                : const [
                    Color(0xFFE0F2FE),
                    Color(0xFFF1F5F9),
                    Color(0xFFE2E8F0),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildSearchHeader(),
              _buildMainBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: _isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: _textColor, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search city or suburb...',
            hintStyle: TextStyle(color: _hintColor),
            prefixIcon: Icon(Icons.search_rounded, color: _subtextColor),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _isDarkMode ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
                    color: _isDarkMode ? Colors.amberAccent : const Color(0xFF6366F1),
                  ),
                  tooltip: _isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                  onPressed: () {
                    setState(() {
                      _isDarkMode = !_isDarkMode;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.my_location_rounded, color: Color(0xFF38BDF8)),
                  tooltip: 'Use GPS Location',
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _fetchWeatherByGPS();
                  },
                ),
              ],
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              _fetchWeatherByCityName(value.trim());
              _searchController.clear();
              FocusScope.of(context).unfocus(); 
            }
          },
        ),
      ),
    );
  }

  Widget _buildMainBody() {
    return Expanded(
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF38BDF8),
                strokeWidth: 3,
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 16, height: 1.4),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF38BDF8),
                  backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                  onRefresh: () => _fetchWeatherByCityName(_cityName),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildWeatherIconGlow(),
                        const SizedBox(height: 20),
                        _buildLocationHeader(),
                        const SizedBox(height: 10),
                        _buildTemperatureDisplay(),
                        _buildDescriptionBadge(),
                        const SizedBox(height: 25),
                        
                        TodayAnalysisCard(isDarkMode: _isDarkMode),
                        const SizedBox(height: 25),

                        DailyChallengeCard(
                          actualHighTemp: _dailyMaxTemp,
                          isDarkMode: _isDarkMode,
                        ),
                        const SizedBox(height: 25),
                        _buildDetailsRow(),
                        const SizedBox(height: 30),
                        _buildHourlySectionHeader(),
                        const SizedBox(height: 15),
                        _buildHourlyForecastList(),
                        const SizedBox(height: 25),
                        
                        WeeklyForecastCard(
                          dailyTimes: _dailyTimes,
                          dailyMaxTemps: _dailyMaxTemps,
                          dailyMinTemps: _dailyMinTemps,
                          dailyWeatherCodes: _dailyWeatherCodes,
                          isDarkMode: _isDarkMode,
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildWeatherIconGlow() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _weatherIconColor.withValues(alpha: 0.1),
        boxShadow: [
          BoxShadow(
            color: _weatherIconColor.withValues(alpha: _isDarkMode ? 0.15 : 0.25),
            blurRadius: 40,
            spreadRadius: 10,
          )
        ],
      ),
      child: Icon(_weatherIcon, size: 90, color: _weatherIconColor),
    );
  }

  Widget _buildLocationHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.location_on_rounded, color: Color(0xFF38BDF8), size: 20),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _cityName,
            style: TextStyle(
              fontSize: 28,
              color: _textColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTemperatureDisplay() {
    return Text(
      '${_currentTemp.toStringAsFixed(1)}°',
      style: TextStyle(
        fontSize: 76,
        color: _textColor,
        fontWeight: FontWeight.w200,
        letterSpacing: -2,
      ),
    );
  }

  Widget _buildDescriptionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Text(
        _weatherDesc,
        style: TextStyle(
          fontSize: 16,
          color: _subtextColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDetailsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.1 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildDetailColumn(Icons.water_drop_rounded, 'Humidity', '$_humidity%', const Color(0xFF38BDF8)),
          Container(height: 35, width: 1, color: _cardBorder),
          _buildDetailColumn(Icons.air_rounded, 'Wind Speed', '${_windSpeed.toStringAsFixed(1)} km/h', const Color(0xFFA78BFA)),
        ],
      ),
    );
  }

  Widget _buildHourlySectionHeader() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: _subtextColor, size: 18),
          const SizedBox(width: 8),
          Text(
            'Hourly Forecast',
            style: TextStyle(
              color: _textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyForecastList() {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _hourlyTimes.length,
        itemBuilder: (context, index) {
          final time = _formatTime(_hourlyTimes[index]);
          final temp = (_hourlyTemps[index] as num).toDouble();
          final code = (_hourlyCodes[index] as num).toInt();
          final isDay = (_hourlyIsDay[index] as num?)?.toInt() == 1;

          final info = _getWeatherInfo(code, isDay: isDay);

          return Container(
            width: 85,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _cardBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time, 
                  style: TextStyle(color: _hintColor, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Icon(info['icon'], color: info['color'], size: 28),
                Text(
                  '${temp.toStringAsFixed(0)}°', 
                  style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailColumn(IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: _hintColor, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

// ==================== DAILY CHALLENGE CARD COMPONENT ====================

class DailyChallengeCard extends StatefulWidget {
  final double actualHighTemp;
  final bool isDarkMode;

  const DailyChallengeCard({
    super.key,
    required this.actualHighTemp,
    required this.isDarkMode,
  });

  @override
  State<DailyChallengeCard> createState() => _DailyChallengeCardState();
}

class _DailyChallengeCardState extends State<DailyChallengeCard> {
  final TextEditingController _guessController = TextEditingController();
  bool _hasGuessedToday = false;
  int _streak = 0;
  int _score = 0;
  String _feedback = "";

  @override
  void initState() {
    super.initState();
    _loadChallengeData();
  }

  @override
  void dispose() {
    _guessController.dispose();
    super.dispose();
  }

  Future<void> _loadChallengeData() async {
    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().substring(0, 10);
    final String? lastGuessDate = prefs.getString('last_guess_date');

    setState(() {
      _streak = prefs.getInt('challenge_streak') ?? 0;
      _score = prefs.getInt('challenge_score') ?? 0;

      if (lastGuessDate == today) {
        _hasGuessedToday = true;
        _feedback = "You've already guessed today! Come back tomorrow.";
      }
    });
  }

  Future<void> _submitGuess() async {
    final guessText = _guessController.text.trim();
    if (guessText.isEmpty) return;

    final double? guess = double.tryParse(guessText);
    if (guess == null) return;

    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().substring(0, 10);

    final double difference = (widget.actualHighTemp - guess).abs();
    int pointsEarned = 0;

    if (difference <= 1.0) {
      pointsEarned = 100;
      _streak++;
      _feedback = "🎯 Bullseye! Spot on! +100 pts\nActual High: ${widget.actualHighTemp.toStringAsFixed(1)}°C";
    } else if (difference <= 3.0) {
      pointsEarned = 50;
      _streak++;
      _feedback = "⭐ You're getting good! +50 pts\nActual High: ${widget.actualHighTemp.toStringAsFixed(1)}°C";
    } else if (difference <= 5.0) {
      pointsEarned = 20;
      _streak++;
      _feedback = "👍 Close call! +20 pts\nActual High: ${widget.actualHighTemp.toStringAsFixed(1)}°C";
    } else {
      _streak = 0;
      _feedback = "🥶 Way off! Streak reset.\nActual High: ${widget.actualHighTemp.toStringAsFixed(1)}°C";
    }

    _score += pointsEarned;

    await prefs.setString('last_guess_date', today);
    await prefs.setInt('challenge_streak', _streak);
    await prefs.setInt('challenge_score', _score);

    setState(() {
      _hasGuessedToday = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = widget.isDarkMode ? Colors.white70 : const Color(0xFF334155);
    final hintColor = widget.isDarkMode ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF64748B);
    final cardBg = widget.isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04);
    final cardBorder = widget.isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDarkMode ? 0.1 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.amber, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Daily Challenge',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '🔥 $_streak  |  ⭐ $_score',
                style: TextStyle(
                  color: subtextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_hasGuessedToday) ...[
            Text(
              "Guess today's high temperature:",
              style: TextStyle(color: subtextColor, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: TextField(
                      controller: _guessController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: textColor, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'e.g. 23',
                        hintStyle: TextStyle(color: hintColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _submitGuess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Text(
                _feedback,
                style: TextStyle(color: textColor, fontSize: 15, height: 1.4, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}