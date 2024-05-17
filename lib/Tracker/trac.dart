import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:nanoid/nanoid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Globals.dart';


//final locationViewModel = Get.put(LocationViewModel());
String gpxString="";

Future<void> startTimer() async {
  startTimerFromSavedTime();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    secondsPassed++;
    await prefs.setInt('secondsPassed', secondsPassed);
  });
}

void startTimerFromSavedTime() {
  SharedPreferences.getInstance().then((prefs) async {
    String savedTime = prefs.getString('savedTime') ?? '00:00:00';
    List<String> timeComponents = savedTime.split(':');
    int hours = int.parse(timeComponents[0]);
    int minutes = int.parse(timeComponents[1]);
    int seconds = int.parse(timeComponents[2]);
    int totalSavedSeconds = hours * 3600 + minutes * 60 + seconds;
    final now = DateTime.now();
    int totalCurrentSeconds = now.hour * 3600 + now.minute * 60 + now.second;
    secondsPassed = totalCurrentSeconds - totalSavedSeconds;
    if (secondsPassed < 0) {
      secondsPassed = 0;
    }
    await prefs.setInt('secondsPassed', secondsPassed);
    if (kDebugMode) {
      print("Loaded Saved Time");
    }
  });
}



// Future<void> postFile() async {
//   SharedPreferences pref = await SharedPreferences.getInstance();
//   double totalDistance = pref.getDouble("TotalDistance") ?? 0.0;
//   pref.setDouble("TotalDistance", totalDistance);
//   if (kDebugMode) {
//     print('Distance:$totalDistance');
//   }
//   final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
//   final downloadDirectory = await getDownloadsDirectory();
//   final gpxFilePath = '${downloadDirectory!.path}/track$date.gpx';
//   final maingpxFile = File(gpxFilePath);
//
//   if (!maingpxFile.existsSync()) {
//     if (kDebugMode) {
//       print('GPX file does not exist');
//     }
//     return;
//   }

// Read the GPX file
// List<int> gpxBytesList = await maingpxFile.readAsBytes();
// Uint8List gpxBytes = Uint8List.fromList(gpxBytesList);
// var id = customAlphabet('1234567890', 10);
//
// locationViewModel.addLocation(LocationModel(
//   id: int.parse(id),
//   userId: userId,
//   userName: userNames,
//   totalDistance: pref.getDouble("TotalDistance").toString(),
//   fileName: "${_getFormattedDate1()}.gpx",
//   date: _getFormattedDate1(),
//   body: gpxBytes,
// ));
//
//   if (kDebugMode) {
// print(userId);
// }
// if (kDebugMode) {
// print(userid);
// }
// if (kDebugMode) {
// print(userNames);
// }
// postLocationData();

String _getFormattedDate1() {
  final now = DateTime.now();
  final formatter = DateFormat('dd-MMM-yyyy  [hh:mm a] ');
  return formatter.format(now);
}