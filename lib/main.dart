import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // 👈 needed for Timer

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Atmospheric Deposition Sampler',
    theme: ThemeData(useMaterial3: true),
    home: const Dashboard(),
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final String espIp = "10.228.244.159"; // <- Replace with your ESP IP
  final String espPath = "/data";

  String currentPage = "Home";
  String hoveredPage = "";

  String sensorStatus = "Loading...";
  String servo1Angle = "--";
  String servo2Angle = "--";
  String weatherValue = "Loading weather...";
  bool isLoadingSensor = false;
  bool isLoadingWeather = false;

  Timer? _sensorTimer; // 👈 timer for auto-refresh

  final Map<String, Widget> _staticPages = {
    "About": const Center(
      child: Text(
        "ℹ️ This dashboard shows real-time sensor data from ESP8266.\n\n"
        "👉 Edit this text in the About section of your code.",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: Colors.white70),
      ),
    ),
  };

  @override
  void initState() {
    super.initState();
    fetchSensorData();
    fetchWeather();

    // 👇 auto-refresh sensor data every 5 seconds
    _sensorTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      fetchSensorData();
    });
  }

  @override
  void dispose() {
    _sensorTimer?.cancel(); // cancel timer when widget is destroyed
    super.dispose();
  }

  Future<void> fetchSensorData() async {
    setState(() => isLoadingSensor = true);
    try {
      final response = await http.get(Uri.parse("http://$espIp$espPath"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          sensorStatus = data['sensor_status'] ?? "Unknown";
          servo1Angle = data['servo1_angle']?.toString() ?? "--";
          servo2Angle = data['servo2_angle']?.toString() ?? "--";
        });
      } else {
        setState(() {
          sensorStatus = "Error: ${response.statusCode}";
          servo1Angle = "--";
          servo2Angle = "--";
        });
      }
    } catch (e) {
      setState(() {
        sensorStatus = "Failed to fetch data";
        servo1Angle = "--";
        servo2Angle = "--";
      });
    }
    setState(() => isLoadingSensor = false);
  }

  Future<void> fetchWeather() async {
    setState(() => isLoadingWeather = true);
    const apiKey = "9a992e2d66244a67b1435835252209";
    const city = "Kandy";
    final url = Uri.parse(
      "https://api.weatherapi.com/v1/current.json?key=$apiKey&q=$city",
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final temp = data['current']['temp_c'];
        final condition = data['current']['condition']['text'];
        setState(() {
          weatherValue = "${temp.toStringAsFixed(1)}°C, $condition";
        });
      } else {
        setState(() => weatherValue = "Error: ${response.statusCode}");
      }
    } catch (_) {
      setState(() => weatherValue = "Failed to fetch weather");
    }
    setState(() => isLoadingWeather = false);
  }

  Widget _navButton(String page) {
    bool isActive = currentPage == page;
    bool isHovered = hoveredPage == page;
    Color color = isActive || isHovered
        ? Colors.white
        : Colors.white.withOpacity(0.85);

    return MouseRegion(
      onEnter: (_) => setState(() => hoveredPage = page),
      onExit: (_) => setState(() => hoveredPage = ""),
      child: GestureDetector(
        onTap: () => setState(() => currentPage = page),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
            shadows: isActive || isHovered
                ? const [
                    Shadow(
                      blurRadius: 8,
                      color: Colors.black38,
                      offset: Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(page),
          ),
        ),
      ),
    );
  }

  Widget _refreshButton(String label, VoidCallback onPressed) => ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blueAccent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 10,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    ),
    onPressed: onPressed,
    child: Text(label, style: const TextStyle(fontSize: 16)),
  );

  Widget _homeContent() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Weather card
          Expanded(
            child: SizedBox(
              height: 350,
              child: Card(
                color: Colors.lightBlue.shade200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network(
                        'https://cdn-icons-png.flaticon.com/512/1163/1163661.png',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "🌦 Current Weather",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isLoadingWeather ? "Loading..." : weatherValue,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _refreshButton("🌦 Refresh Weather", fetchWeather),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Sensor card
          Expanded(
            child: SizedBox(
              height: 350,
              child: Card(
                color: Colors.blueAccent.shade200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network(
                        'https://static.thenounproject.com/png/1368291-512.png',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "🌧 Rain Sensor",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isLoadingSensor ? "Loading..." : sensorStatus,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Servo1: $servo1Angle°, Servo2: $servo2Angle°",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _refreshButton("🔄 Refresh Sensor", fetchSensorData),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sensorDataContent() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Card(
            color: Colors.blueAccent.shade200,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "🌧 Rain Sensor Data",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isLoadingSensor ? "Loading..." : sensorStatus,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Servo1: $servo1Angle°, Servo2: $servo2Angle°",
                    style: const TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  _refreshButton("🔄 Refresh Sensor", fetchSensorData),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF5eb8ff), Color(0xFFa7e9ff)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 110,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0077c2), Color(0xFF00b4db)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "Atmospheric Deposition Sampler",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFe0f7ff),
                          letterSpacing: 1.1,
                          fontFamily: "Poppins",
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        "Home",
                        "Sensor Data",
                        "About",
                      ].map((p) => _navButton(p)).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: currentPage == "Home"
                  ? _homeContent()
                  : currentPage == "Sensor Data"
                  ? _sensorDataContent()
                  : _staticPages[currentPage] ?? Container(),
            ),
          ],
        ),
      ),
    );
  }
}
