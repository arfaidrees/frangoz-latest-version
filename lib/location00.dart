import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gpx/gpx.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  //late LocationManager locationManager;
  late Gpx gpx;
  late Trk track;
  late Trkseg segment;
  late File file;
  late bool isFirstRun;
  late bool isConnected;
  late var lat, longi;
  //late StreamSubscription<LocationDto> locationSubscription;
  late String userIdForLocation;
  late String userCityForLocatiion;
  late String userDesignationForLocation;
  late final filepath;
  late final Directory? downloadDirectory;
  late double totalDistance;
  late Position? lastTrackPoint;
  String gpxString="";

  LocationService() {
    totalDistance = 0.0;
    lastTrackPoint = null;
    init();
    Firebase.initializeApp();
    lat = 0.0;
    longi = 0.0;
  }

  StreamSubscription<Position>? positionStream;
  LocationSettings locationSettings = AndroidSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 9,
    forceLocationManager: true,
    // intervalDuration: const Duration(seconds:1 ),
  );

  Future<void> listenLocation() async {
    positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
      if (kDebugMode) {
        print("W100 Repeat");
      }

      longi = position.longitude.toString();
      lat = position.latitude.toString();
      final trackPoint = Wpt(
        lat: position.latitude,
        lon: position.longitude,
        time: DateTime.now(),
      );

      segment.trkpts.add(trackPoint);

      if (isFirstRun) {
        track.trksegs.add(segment);
        gpx.trks.add(track);
        isFirstRun = false;
      }

      if (lastTrackPoint != null) {
        totalDistance += calculateDistance(
          lastTrackPoint!.latitude,
          lastTrackPoint!.longitude,
          position.latitude,
          position.longitude,
        );
      }

      lastTrackPoint = Position(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        timestamp: DateTime.now(),
      );
      gpxString = GpxWriter().asString(gpx, pretty: true);
      if (kDebugMode) {
        print("W100 $gpxString");
      }
      file.writeAsStringSync(gpxString);

      isConnected = await isInternetConnected();
      if (isConnected) {
        await FirebaseFirestore.instance.collection('location').doc(userIdForLocation.toString()).set({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'name': userIdForLocation.toString(),
          //'city': userCityForLocatiion.toString(),
          //'designation': userDesignationForLocation.toString(),
          'isActive': true
        }, SetOptions(merge: true));
      }
    });

    SharedPreferences pref = await SharedPreferences.getInstance();
    userIdForLocation = pref.getString("loginEmail") ?? "USER";
    // userCityForLocatiion = pref.getString("userCitys") ?? "CITY";
    // userDesignationForLocation = pref.getString("userDesignation") ?? "DESIGNATION";
    try {
      gpx = Gpx();
      track = Trk();
      segment = Trkseg();
      if (kDebugMode) {
        print("W100 Start");
      }
      final date = DateFormat('dd-MM-yyyy').format(DateTime.now());

      final downloadDirectory = await getDownloadsDirectory();
      final filePath = "${downloadDirectory!.path}/track$date.gpx";

      file = File(filePath);
      isFirstRun = !file.existsSync();
      if (!file.existsSync()) {
        file.createSync();
      } else {
        Gpx existingGpx = GpxReader().fromString(file.readAsStringSync());
        gpx.trks.add(existingGpx.trks[0]);
        track = gpx.trks[0];
        segment = Trkseg();
        track.trksegs.add(segment);
      }

      if (kDebugMode) {
        print("W100 END");
      }
    } catch (e) {
      if (kDebugMode) {
        print('W100 An error occurred: $e');
      }
    }
  }

  Future<void> init() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    userIdForLocation = pref.getString("loginEmail") ?? "USER";
    // userCityForLocatiion=pref.getString("userCitys") ?? "CITY";
    // userDesignationForLocation=pref.getString("userDesignation") ?? "DESIGNATION";
  }
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    double distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return (distanceInMeters / 1000); // Multiply the result by 2
  }

  Future<void> deleteDocument() async {
    await FirebaseFirestore.instance
        .collection('location')
        .doc(userIdForLocation)
        .delete()
        .then(
          (doc) => print("Document deleted"),
      onError: (e) => print("Error updating document $e"),
    );
  }

  Future<void> stopListening() async {
    try {
      //WakelockPlus.disable();
      positionStream?.cancel();
      SharedPreferences pref = await SharedPreferences.getInstance();
      pref.setDouble("TotalDistance", totalDistance);
    } catch (e) {
      print("ERROR ${e.toString()}");
    }
  }
}
Future<bool> isInternetConnected() async {
  bool isConnected = await InternetConnectionChecker().hasConnection;
  if (kDebugMode) {
    print('Internet Connected: $isConnected');
  }
  return isConnected;
}