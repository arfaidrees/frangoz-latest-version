import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:login_signup/components/Screens/optimized_delivery_route.dart';
import 'package:geolocator/geolocator.dart';

class MapSample extends StatefulWidget {
  const MapSample({Key? key});

  @override
  State<MapSample> createState() => MapSampleState();
}

class MapSampleState extends State<MapSample> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  List<String> addresses = [];
  bool showAddresses = true;

  TextEditingController _searchController = TextEditingController();
  var uuid = const Uuid();
  String _sessionToken = '1234567890';
  List<dynamic> _placeList = [];
  LatLng geoFenceCenter = LatLng(32.4770, 74.4496);
  double geoFenceRadius = 300;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onChanged);
  }

  _onChanged() {
    if (_sessionToken == null) {
      setState(() {
        _sessionToken = uuid.v4();
      });
    }
    getSuggestion(_searchController.text);
  }

  void getSuggestion(String input) async {
    const String placesApiKey = "AIzaSyBcfwu-Rj73Gr9dvOvN_rCMmGDn-Mmp024";

    try {
      String baseURL = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
      String request = '$baseURL?input=$input&key=$placesApiKey&sessiontoken=$_sessionToken';
      var response = await http.get(Uri.parse(request));
      var data = json.decode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          _placeList = json.decode(response.body)['predictions'];
        });
      } else {
        throw Exception('Failed to load predictions');
      }
    } catch (e) {
      print(e);
    }
  }

  Future<LatLng> _getCurrentLocation() async {
    bool locationPermissionGranted = await _requestLocationPermission();

    if (locationPermissionGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        return LatLng(position.latitude, position.longitude);
      } catch (e) {
        print("Error getting current location: $e");
        return const LatLng(0, 0);
      }
    } else {
      return const LatLng(0, 0);
    }
  }

  Future<bool> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: GoogleMap(
                mapType: MapType.hybrid,
                initialCameraPosition: _kGooglePlex,
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Stops:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 27),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      LatLng currentLocation = await _getCurrentLocation();
                      Get.to(() => Routes(
                        addresses: addresses,
                        currentLocation: currentLocation,
                        geoFenceCenter: geoFenceCenter,
                        geoFenceRadius: geoFenceRadius,
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: const Color(0xffae2012),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Proceed',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  showAddresses = !showAddresses;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Icon(
                      showAddresses ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    ),
                  ],
                ),
              ),
            ),
            Visibility(
              visible: showAddresses,
              child: Expanded(
                child: ListView.builder(
                  itemCount: addresses.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(addresses[index]),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            addresses.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
            Visibility(
              visible: showAddresses,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search for a place",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _placeList.clear();
                      });
                    },
                  )
                      : null,
                ),
              ),
            ),
            Visibility(
              visible: showAddresses,
              child: Expanded(
                child: ListView.builder(
                  itemCount: _placeList.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_placeList[index]["description"]),
                      onTap: () {
                        setState(() {
                          addresses.add(_placeList[index]["description"]);
                          _searchController.clear();
                          _placeList.clear();
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Uuid {
  const Uuid();
  String v4() {
    return 'dummy_uuid';
  }
}
