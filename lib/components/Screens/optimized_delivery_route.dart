import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

class Routes extends StatefulWidget {
  final List<String> addresses;
  final LatLng currentLocation;
  final LatLng geoFenceCenter; // New variable for geofence center
  final double geoFenceRadius; // New variable for geofence radius

  const Routes({required this.addresses, required this.currentLocation, required this.geoFenceCenter, required this.geoFenceRadius});

  @override
  State<Routes> createState() => RoutesState();
}

class RoutesState extends State<Routes> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(32.4920, 74.5319),
    zoom: 12.0,
  );

  Set<Marker> _markers = {};
  Set<Polyline> _polyLines = {};

  double _totalDistance = 0.0;
  double _coveredDistance = 0.0;
  List<LatLng> _route = [];
  bool isInsideGeofence = false; // New variable for geofence status
  Set<Circle> circles = Set(); // New variable for geofence circle

  @override
  void initState() {
    super.initState();
    _addMarkers();
    _initializeGeofencing(); // Initialize geofencing logic
  }

  void _initializeGeofencing() {
    setState(() {
      // Add geofence circle
      circles.add(
        Circle(
          circleId: CircleId('geo_fence'),
          center: widget.geoFenceCenter,
          radius: widget.geoFenceRadius,
          strokeWidth: 2,
          strokeColor: Colors.green,
          fillColor: Colors.green.withOpacity(0.15),
        ),
      );
    });
  }

  void _addMarkers() async {
    Uint8List resizedImageBytes =
    await _resizeImage('assets/images/frangozlogo-removebg-preview.png');
    BitmapDescriptor customIcon = BitmapDescriptor.fromBytes(resizedImageBytes);

    _markers.add(
      Marker(
        markerId: const MarkerId('Rider'),
        position: widget.currentLocation,
        infoWindow: const InfoWindow(title: 'Rider'),
        icon: customIcon,
      ),
    );

    for (String address in widget.addresses) {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        LatLng position = LatLng(locations[0].latitude, locations[0].longitude);
        _markers.add(
          Marker(
            markerId: MarkerId(address),
            position: position,
            infoWindow: InfoWindow(title: address),
          ),
        );
      }
    }
    setState(() {});
  }

  Future<void> _startRouteOptimization() async {
    List<LatLng> waypoints = [widget.currentLocation];

    for (String address in widget.addresses) {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        LatLng position = LatLng(locations[0].latitude, locations[0].longitude);
        waypoints.add(position);
      }
    }

    String origin = "${widget.currentLocation.latitude},${widget.currentLocation.longitude}";
    String destination = "${waypoints.last.latitude},${waypoints.last.longitude}";
    List<LatLng> intermediatePoints = waypoints.sublist(1, waypoints.length - 1);
    String waypointsString =
    intermediatePoints.map((point) => "${point.latitude},${point.longitude}").join('|');

    String apiKey = 'AIzaSyBcfwu-Rj73Gr9dvOvN_rCMmGDn-Mmp024';
    String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&waypoints=$waypointsString&key=$apiKey';

    var response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      _route = _decodePoly(data['routes'][0]['overview_polyline']['points']);
      _totalDistance = _calculateTotalDistance(_route);
      _drawRoute(_route);
      _startTracking();
    } else {
      throw Exception('Failed to load route');
    }
  }

  void _startTracking() {
    Geolocator.getPositionStream().listen((Position position) {
      double minDistance = double.infinity;
      int nearestIndex = 0;

      for (int i = 0; i < _route.length; i++) {
        double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          _route[i].latitude,
          _route[i].longitude,
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestIndex = i;
        }
      }

      double coveredDistance = 0.0;
      for (int i = 0; i < nearestIndex; i++) {
        coveredDistance += _calculateDistance(_route[i], _route[i + 1]);
      }

      setState(() async {
        Uint8List resizedImageBytes =
        await _resizeImage('assets/images/frangozlogo-removebg-preview.png');
        BitmapDescriptor customIcon = BitmapDescriptor.fromBytes(resizedImageBytes);
        _coveredDistance = coveredDistance;
        _markers.removeWhere((marker) => marker.markerId.value == 'Rider');
        _markers.add(
          Marker(
            markerId: MarkerId('Rider'),
            position: LatLng(position.latitude, position.longitude),
            infoWindow: InfoWindow(title: 'Rider'),
            icon: BitmapDescriptor.fromBytes(resizedImageBytes), // Use custom icon here
          ),
        );
        checkGeofence(); // Check geofence when updating position
      });
    });
  }

  List<LatLng> _decodePoly(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      double latitude = lat / 1E5;
      double longitude = lng / 1E5;
      poly.add(LatLng(latitude, longitude));
    }
    return poly;
  }

  void _drawRoute(List<LatLng> route) {
    setState(() {
      _polyLines.add(
        Polyline(
          polylineId: const PolylineId('optimized_route'),
          points: route,
          color: Colors.blue,
          width: 5,
        ),
      );
    });
  }

  Future<Uint8List> _resizeImage(String imagePath) async {
    Uint8List imageBytes = await (await rootBundle.load(imagePath)).buffer.asUint8List();

    List<int> compressedImageBytes = await FlutterImageCompress.compressWithList(
      imageBytes,
      minHeight: 100,
      minWidth: 100,
      format: CompressFormat.png,
      quality: 100,
    );

    return Uint8List.fromList(compressedImageBytes);
  }

  double _calculateTotalDistance(List<LatLng> route) {
    double totalDistance = 0.0;
    for (int i = 0; i < route.length - 1; i++) {
      totalDistance += _calculateDistance(route[i], route[i + 1]);
    }
    return totalDistance;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    final double distance = Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
    return distance / 1000;
  }

  void checkGeofence() {
    if (widget.currentLocation != null) {
      double distance = Geolocator.distanceBetween(
        widget.currentLocation.latitude,
        widget.currentLocation.longitude,
        widget.geoFenceCenter.latitude,
        widget.geoFenceCenter.longitude,
      );

      // Check if the user is currently inside the geofence
      bool insideNow = distance <= widget.geoFenceRadius;

      // Only update state and show Snackbar if the status changes
      if (insideNow != isInsideGeofence) {
        setState(() {
          isInsideGeofence = insideNow;
        });

        // Show Snackbar if the user crosses the geofence boundary
        if (!isInsideGeofence) {
          showSnackbar(isInsideGeofence);
        }
      }
    }
  }

  void showSnackbar(bool isInside) {
    String message = isInside ? 'You are inside the geofence!' : 'You are outside the geofence!';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        key: _scaffoldKey,
        body: Stack(
          children: [
            GoogleMap(
              mapType: MapType.hybrid,
              initialCameraPosition: _kGooglePlex,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
              markers: _markers,
              polylines: _polyLines,
              circles: circles, // Add geofence circle to the map
            ),
          ],
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: _startRouteOptimization,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffae2012),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 12.0,
                  ),
                ),
                icon: Icon(
                  Icons.navigation,
                  color: Colors.white,
                ),
                label: Text(
                  'Make Route',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Get.snackbar(
                    'Total Distance',
                    'Total Distance: ${_totalDistance.toStringAsFixed(2)} km\nCovered Distance: ${_coveredDistance.toStringAsFixed(2)} km',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: Color(0xffae2012),
                    colorText: Colors.blue,
                    titleText: Padding(
                      padding: EdgeInsets.only(bottom: 5.0),
                      child: Text('Total Distance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    messageText: Padding(
                      padding: EdgeInsets.only(top: .0),
                      child: Text('Distance: ${_totalDistance.toStringAsFixed(2)} km\nCovered Distance: ${_coveredDistance.toStringAsFixed(2)} km', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffae2012),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 12.0,
                  ),
                ),
                icon: Icon(
                  Icons.accessibility,
                  color: Colors.white,
                ),
                label: Row(
                  children: [
                    Text(
                      'Total Distance',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
