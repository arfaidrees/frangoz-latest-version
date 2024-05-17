import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart';
import 'package:login_signup/Tracker/trac.dart';
import 'package:login_signup/components/Screens/delivery_stops%20.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Globals.dart';
import 'package:location/location.dart' as loc;
import 'dart:async' show Completer, Future, Timer;

//tarcker
final FirebaseAuth auth = FirebaseAuth.instance;
final User? user = auth.currentUser;
final myUid = loginEmail;
final name = loginName;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage2(),
    );
  }
}

class HomePage2 extends StatefulWidget {
  @override
  _HomePage2State createState() => _HomePage2State();
}

class _HomePage2State extends State<HomePage2> {

  final loc.Location location = loc.Location();
  Future<void> _toggleClockInOut() async {
    print("serivices start ho");
    final service = FlutterBackgroundService();
    print("serivices start ho gaii haiiiiiiiiiiiiiiiiiiiiiiiiii");
    Completer<void> completer = Completer<void>();
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent users from dismissing the dialog
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() async {
      isClockedIn = !isClockedIn;
      if (isClockedIn) {
        await location.enableBackgroundMode(enable: true);
        await location.changeSettings(interval: 300, accuracy: loc.LocationAccuracy.high);
        locationbool = true;
        service.startService();
        _saveCurrentTime();
        _saveClockStatus(true);
        _clockRefresh();
        isClockedIn = true;
        await Future.delayed(const Duration(seconds: 5));

      } else {
        // Generate a unique ID for the current post
        service.invoke("stopService");
        location.enableBackgroundMode(enable: false);
        await Future.delayed(const Duration(seconds: 10));
        await Future.delayed(const Duration(seconds: 4));
        isClockedIn = false;
        _saveClockStatus(false);
        _stopTimer();
        setState(() async {
          _clockRefresh();
          await prefs.remove('clockInId');
        });

      }
    });
    await Future.delayed(const Duration(seconds: 10));
    Navigator.pop(context); // Close the loading indicator dialog
    completer.complete();
    return completer.future;
  }
  String formatTimer(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds ~/ 60) % 60;
    int secs = seconds % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  _loadClockStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    isClockedIn = prefs.getBool('isClockedIn') ?? false;
    print(isClockedIn.toString() + "RES B100");
    if (isClockedIn == true) {
      print("B100 CLOCKIN RUNN");
      //startTimerFromSavedTime();
      final service = FlutterBackgroundService();
      service.startService();
      _clockRefresh();
    }else{
      prefs.setInt('secondsPassed', 0);
    }
  }

  _saveClockStatus(bool clockedIn) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isClockedIn', clockedIn);
    isClockedIn = clockedIn;
  }

  void _saveCurrentTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    DateTime currentTime = DateTime.now();
    String formattedTime = _formatDateTime(currentTime);
    prefs.setString('savedTime', formattedTime);
    print("Save Current Time");
  }

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('HH:mm:ss');
    return formatter.format(dateTime);
  }
  int newsecondpassed = 0;
  void _clockRefresh() async {
    newsecondpassed = 0;
    timer = Timer.periodic(Duration(seconds: 0), (timer) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        prefs.reload();
        newsecondpassed = prefs.getInt('secondsPassed')!;
      });
    });
  }

  Future<String> _stopTimer() async {
    String totalTime = _formatDuration(newsecondpassed.toString());
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('secondsPassed', 0);
    setState(() {
      secondsPassed = 0;
    });
    return totalTime;
  }

  String _formatDuration(String secondsString) {
    int seconds = int.parse(secondsString);
    Duration duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);

    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String secondsFormatted = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$secondsFormatted';
  }
  String _getFormattedDate() {
    final now = DateTime.now();
    final formatter = DateFormat('dd-MMM-yyyy');
    return formatter.format(now);
  }
  @override
  void dispose() {

    super.dispose();
    WidgetsBinding.instance!.addObserver(this as WidgetsBindingObserver);
    _loadClockStatus();
    _getFormattedDate();
    _clockRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Timer: ${_formatDuration(newsecondpassed.toString())}',
              style: TextStyle(fontSize: 20, ),
            ),
            IconButton(
              onPressed: () {
                if (isClockedIn) {
                  startTimer();
                  _saveCurrentTime();
                  _saveClockStatus(true);
                  //_getLocation();
                  //getLocation();
                  _clockRefresh();
                  isClockedIn = true;
                } else {
                  isClockedIn = false;
                  _saveClockStatus(false);
                  _stopTimer();
                  setState(() async {
                    _clockRefresh();
                  });
                }
                setState(() {
                  isClockedIn = !isClockedIn;
                });
              },
              icon: Icon(
                isClockedIn ? Icons.timer_off : Icons.timer,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedLogo(),
                SizedBox(height: 4),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MapSample()),
                    );
                  },
                  style: ButtonStyle(
                    overlayColor: MaterialStateProperty.resolveWith<Color?>(
                          (Set<MaterialState> states) {
                        if (states.contains(MaterialState.hovered))
                          return Colors.transparent;
                        if (states.contains(MaterialState.focused) ||
                            states.contains(MaterialState.pressed))
                          return Colors.transparent;
                        return null;
                      },
                    ),
                  ),
                  child: Text(
                    'Tap to Add Stops',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'NotoSerif',
                      color: const Color(0xffae2012),
                      fontSize: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
           _toggleClockInOut();
        },
        child: Icon(
          isClockedIn ? Icons.timer_off : Icons.timer,
          color: Colors.white,
        ),
        backgroundColor: Color(0xffae2012),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

}

class AnimatedLogo extends StatefulWidget {
  @override
  _AnimatedLogoState createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );
    animation = Tween<double>(begin: 0, end: 1).animate(controller)
      ..addListener(() {
        setState(() {});
      });
    controller.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: animation.value,
      child: Image.asset(
        'assets/images/stopicon.png',
        height: 249,
        width: 200,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
