import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled2/consumption_screen.dart';
import 'package:provider/provider.dart';
import 'data_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool hasSetupCompleted = prefs.getBool('setupCompleted') ?? false;

  runApp(
    ChangeNotifierProvider(
      create: (context) => DataModel(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateRoute: (settings) {
          if (settings.name == '/') {
            return MaterialPageRoute(
              builder: (context) {
                return hasSetupCompleted
                    ? MyApp.withDeviceId(
                    prefs.getString('deviceId') ?? "")
                    : SetupScreen();
              },
            );
          }
          return null;
        },
      ),
    ),
  );
}


class SetupScreen extends StatelessWidget {
  final TextEditingController deviceIdController = TextEditingController();

  void _saveDeviceId(BuildContext context) async {
    final String deviceId = deviceIdController.text.trim();

    if (deviceId.isNotEmpty) {
      // Save the deviceId to SharedPreferences
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('deviceId', deviceId);
      await prefs.setBool('setupCompleted', true);

      // Navigate to the main app screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MyApp(deviceId: deviceId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup Screen'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TextField(
              controller: deviceIdController,
              decoration: InputDecoration(labelText: 'Enter Device ID'),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () => _saveDeviceId(context),
              child: Text('Save and Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  final String deviceId; // Add this parameter
  const MyApp({Key? key, required this.deviceId}) : super(key: key);
  static MyApp withDeviceId(String deviceId) {
    return MyApp(deviceId: deviceId);
  }
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late GoogleMapController mapController;
  Set<Marker> allMarkers = {};
  final Set<Marker> _currentLocationMarkers = {};
  final Set<Marker> _fuelStationMarkers = {}; // Initialize with a default value
  LatLng center = LatLng(8.358040, 80.501892);
  late DatabaseReference _deviceRef; // Reference for the unique device node
  late String deviceId; // Unique device identifier
  String realTimeValue = '01';
  double realTimeValue1 = 01;
  double realTimeValue2 = 01;
  int realTimeValue3 = 5000;
  String? _currentAddress;
  Position? _currentPosition;
  Position? _previousPosition;
  double totalDistance = 0.0;
  double Distance20km = 0.0;
  double Distance40km = 0.0;
  double Distance60km = 0.0;
  double Distance100km = 0.0;
  double totalDistanceAfterTank = 0.0;
  double previous = 0.0;
  int consum = 0;
  int consum40km = 0;
  int consum60km = 0;
  int consum100km = 0;
  int consum20km = 0;
  int previousconsum = 0;
  double totalconsum = 0.0;
  int initFuelLevel = 0;
  double average_consumption = 0.0;
  double average_consumption20km = 0.0;
  double average_consumption40km = 0.0;
  double average_consumption60km = 0.0;
  double average_consumption100km = 0.0;
  double fuel = 0.0;
  late Timer _timer;
  bool nodeCreated = false;
  bool keycreate = false;
  double fuelConsumption50UpKM = 0.0;
  int DistanceCanGo = 0;
  double fuel_fill = 0;
  double speed = 80.0;
  double _speed = 10.0;
  String alert="";

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadValuesFromSharedPreferences().then((_) {
      _loadNodeCreatedFlag().then((_) {
        print("id $nodeCreated");

        if (nodeCreated == false) {
          _initializeDatabaseReference();
        } else {
          // If the node is already created, just load the reference
          _deviceRef = FirebaseDatabase.instance.reference().child(
              "/$deviceId/initialDataKey");
        }
        print("Before Firebase listener");
        _timer = Timer.periodic(Duration(seconds: 5), (timer) {
          _getCurrentPosition();
          getcon();
          distancecango();
          fetchNearbyFuelStations(center);
        });
        _deviceRef.onValue.listen((event) {
          final dynamic value = event.snapshot.value;
          print("Received new value: ${event.snapshot.value}");
          setState(() {
            realTimeValue = value.toString();
            realTimeValue1 = double.parse(realTimeValue);
            print(realTimeValue1);
            realTimeValue3 = int.parse(realTimeValue);
            print("id $deviceId;");

          });
          _saveValuesToSharedPreferences();
        });
        print("After Firebase listener");
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    // Cancel the timer when the widget is disposed.
    _timer.cancel();
  }


  void _initializeDatabaseReference() {
    _deviceRef = FirebaseDatabase.instance.reference().child(deviceId);
    _deviceRef.set({
      'initialDataKey': 5000,
      // Add other initial data fields as needed
    });
    _saveNodeCreatedFlag(true);
    _deviceRef = FirebaseDatabase.instance.reference().child(
        "/$deviceId/initialDataKey");

  }

  Future<void> _loadNodeCreatedFlag() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      nodeCreated = prefs.getBool('nodeCreated') ?? false;
    });
  }

  Future<void> _saveNodeCreatedFlag(bool created) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('nodeCreated', true);
  }


  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location services are disabled. Please enable the services')));
      return false;
    }

    // Check if location permissions are granted.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')));
        return false;
      }
    }

    // Handle permanently denied location permissions.
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location permissions are permanently denied, we cannot request permissions.')));
      return false;
    }

    // If everything is fine, return true to indicate that permissions are granted.
    return true;
  }

  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();

    if (!hasPermission) return;
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best,)
        .then((Position? position) {
      if (position != null) {
        setState(() {
          _previousPosition = _currentPosition;
          _currentPosition = position;
          if (_previousPosition != null) {
            totalDistance += Geolocator.distanceBetween(
              _previousPosition!.latitude,
              _previousPosition!.longitude,
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            );
            totalDistanceAfterTank += Geolocator.distanceBetween(
              _previousPosition!.latitude,
              _previousPosition!.longitude,
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            );

            if (_speed < 20) {
              Distance20km += Geolocator.distanceBetween(
                _previousPosition!.latitude,
                _previousPosition!.longitude,
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              );
            }
            else if (_speed >= 20 && _speed < 40) {
              print("speed 40 below");
              Distance40km += Geolocator.distanceBetween(
                _previousPosition!.latitude,
                _previousPosition!.longitude,
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              );
            }

            else if (_speed < 60 && _speed >= 40) {
              print("speed 60 below");
              Distance60km += Geolocator.distanceBetween(
                _previousPosition!.latitude,
                _previousPosition!.longitude,
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              );
            }

            else if (_speed >= 60) {
              print("speed 60 up");
              Distance100km += Geolocator.distanceBetween(
                _previousPosition!.latitude,
                _previousPosition!.longitude,
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              );
            }

            _saveValuesToSharedPreferences();
          }
          //-----------------------------------------------------------------------
          print(position);
          center = LatLng(position.latitude, position.longitude);
          print(center);
          // Now you can safely use latLng

          _currentLocationMarkers
              .clear(); // Clear existing current location markers
          _currentLocationMarkers.add(
            Marker(
              markerId: MarkerId("currentLocation"),
              position: LatLng(position.latitude, position.longitude),
              infoWindow: InfoWindow(title: 'Current Location'),
            ),
          );

          mapController.animateCamera(CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude),
          ));
        });
      }
    }).catchError((e) {
      debugPrint(e);
    });
  }

  Future<void> getcon() async {
    if ((previous+100)< realTimeValue1) {
      setState(() {
        initFuelLevel = realTimeValue1.toInt();
        fuel_fill = realTimeValue1 - previous;
        consum = 0;
        previousconsum = 0;
        totalDistanceAfterTank = 0.0;

        _saveValuesToSharedPreferences();
      });
    }

    else if (initFuelLevel > realTimeValue1) {
      setState(() {
        previousconsum = consum;
        consum = (initFuelLevel - realTimeValue1).toInt();

        if (previousconsum != consum && previousconsum != 0) {
          if (consum > previousconsum) {
            totalconsum = totalconsum + (consum - previousconsum);
            previousconsum = consum;
          }
        }
        average_consumption = (totalDistance / totalconsum);

        if (_speed < 20) {
          print("Speed is less than 20");
          if (previous != realTimeValue1 && previous != 0 && previous>realTimeValue1) {
            consum20km = consum20km + (previous - realTimeValue1).toInt();
            print("consum20km updated: $consum20km");
          }
          average_consumption20km = (Distance20km / consum20km);

        }

        if (_speed >= 20 && _speed < 40) {
          if (previous != realTimeValue1 && previous != 0 && previous>realTimeValue1 ) {
            consum40km = consum40km + (previous - realTimeValue1).toInt();
          }
          average_consumption40km = (Distance40km / consum40km);

        }

        if (_speed < 60 && _speed >= 40) {
          print("i am 60 below");
          if (previous != realTimeValue1 && previous != 0 && previous>realTimeValue1) {
            consum60km = consum60km + (previous - realTimeValue1).toInt();
          }
          average_consumption60km = (Distance60km / consum60km);

        }

        if (_speed >= 60) {
          print("i am 60 up");
          if (previous != realTimeValue1 && previous != 0 && previous>realTimeValue1) {
            consum100km = consum100km + (previous - realTimeValue1).toInt();
          }
          average_consumption100km = (Distance100km / consum100km);

        }
      });
    }

    previous = realTimeValue1;
    _saveValuesToSharedPreferences();
    print("totalconsum $totalconsum");
    Provider
        .of<DataModel>(context, listen: false)
        .consum = consum;
    Provider
        .of<DataModel>(context, listen: false)
        .totalDistanceAfterTank = totalDistanceAfterTank;
    Provider
        .of<DataModel>(context, listen: false)
        .totalconsum = totalconsum;
    Provider
        .of<DataModel>(context, listen: false)
        .initFuelLevel = initFuelLevel;
    Provider
        .of<DataModel>(context, listen: false)
        .average_consumption = average_consumption;
    Provider
        .of<DataModel>(context, listen: false)
        .totalDistance = totalDistance;
    Provider
        .of<DataModel>(context, listen: false)
        .deviceId = deviceId;
    Provider
        .of<DataModel>(context, listen: false)
        .fuel_fill = fuel_fill;
  }

  void _initLocation() async {
    final geolocator = GeolocatorPlatform.instance;

    geolocator.getPositionStream().listen((position) {
      setState(() {
        _speed = (position.speed)*3.6 ?? 0.0;
      });
    });
  }

  Future<void> distancecango() async {

      setState(() {
        if (_speed < 20) {
          average_consumption20km = (Distance20km / consum20km);
          DistanceCanGo = (average_consumption20km * realTimeValue1).toInt();
        }

       else if (_speed >= 20 && _speed < 40) {
          average_consumption40km = (Distance40km / consum40km);
          DistanceCanGo = (average_consumption40km * realTimeValue1).toInt();
        }

       else if (_speed < 60 && _speed >= 40) {

          average_consumption60km = (Distance60km / consum60km);
          DistanceCanGo = (average_consumption60km * realTimeValue1).toInt();
        }

        else if (_speed >= 60) {
          average_consumption100km = (Distance100km / consum100km);
          DistanceCanGo = (average_consumption100km * realTimeValue1).toInt();
        }

          if(DistanceCanGo<30000){
          alert="fuel level runninng low";
               }
          else {
            alert="";
          }
      });
    }





  void reset() {
    print("reset");
    setState(() {
      previous = realTimeValue1;
      totalDistance = 0.0;
      initFuelLevel = realTimeValue1.toInt();
      consum = 0;
      consum40km = 0;
      fuelConsumption50UpKM = average_consumption;
      average_consumption = 0;
      totalconsum = 0;
      Distance20km = 0;
      Distance40km = 0;
      Distance60km = 0;
      Distance100km = 0;
      consum60km = 0;
      consum100km = 0;
      consum40km = 0;
      consum20km = 0;
      DistanceCanGo=0;
    });
  }

  Future<void> _saveValuesToSharedPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('initFuelLevel', initFuelLevel);
    prefs.setInt('previousconsum', previousconsum);
    prefs.setDouble('previous', previous);
    prefs.setDouble('_totalDistance', totalDistance);
    prefs.setString('deviceId', deviceId);
    prefs.setDouble('totalconsum', totalconsum);
    prefs.setDouble('totalDistanceAfterTank', totalDistanceAfterTank);
    prefs.setDouble('Distance60km', Distance60km);
    prefs.setDouble('Distance40km', Distance40km);
    prefs.setDouble('Distance100km', Distance100km);
    prefs.setDouble('Distance20km', Distance20km);
    prefs.setInt('consum40km', consum40km);
    prefs.setInt('consum20km', consum20km);
    prefs.setInt('consum60km', consum60km);
    prefs.setInt('consum100km', consum100km);
  }

  Future<void> _loadValuesFromSharedPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      initFuelLevel = prefs.getInt('initFuelLevel') ?? 0;
      consum = prefs.getInt('consum') ?? 0;
      totalconsum = prefs.getDouble('totalconsum') ?? 0.0;
      previous = prefs.getDouble('previous') ?? 0.0;
      totalDistance = prefs.getDouble('_totalDistance') ?? 0.0;
      totalDistanceAfterTank = prefs.getDouble('totalDistanceAfterTank') ?? 0.0;
      deviceId = prefs.getString('deviceId') ?? "";
      previousconsum = prefs.getInt('previousconsum') ?? 0;
      Distance100km = prefs.getDouble('Distance100km') ?? 0.0;
      Distance40km = prefs.getDouble('Distance40km') ?? 0.0;
      Distance60km = prefs.getDouble('Distance60km') ?? 0.0;
      Distance60km = prefs.getDouble('Distance20km') ?? 0.0;
      consum40km = prefs.getInt('consum40km') ?? 0;
      consum60km = prefs.getInt('consum60km') ?? 0;
      consum100km = prefs.getInt('consum100km') ?? 0;
      consum20km = prefs.getInt('consum20km') ?? 0;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  List<dynamic> _farthestFuelStations = [];

  Future<void> fetchNearbyFuelStations(LatLng center) async {
    const maxResults =10;
    const String apiKey = 'AIzaSyBFp19_yYfISlAtN6V9c4KLZzC7bwBkiFc';
    const String baseUrl =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
    final response = await http.get(
      Uri.parse('$baseUrl?location=${center.latitude},${center.longitude}'
          '&radius=$DistanceCanGo'
          '&type=gas_station'
          '&key=$apiKey'),

    );
    print("distance:$DistanceCanGo");
    if (response.statusCode == 200) {
      setState(() {
        _fuelStationMarkers.clear(); // Clear existing markers

        final List<dynamic> results = json.decode(response.body)['results'];
        results.sort((a, b) {
          // Sort by distance in descending order
          final distanceA = a['geometry']['location']['lat'] +
              a['geometry']['location']['lng'];
          final distanceB = b['geometry']['location']['lat'] +
              b['geometry']['location']['lng'];
          return distanceB.compareTo(distanceA);
        });
        _farthestFuelStations = results.take(maxResults).toList();
        for (final result in _farthestFuelStations) {
          final location = result['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];
          final LatLng position = LatLng(lat, lng);

          _fuelStationMarkers.add(
            Marker(
              markerId: MarkerId(position.toString()),
              position: position,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange),
              infoWindow: InfoWindow(
                  title: 'Fuel Station', snippet: result['name']),
            ),
          );
        }
      });
      allMarkers.clear(); // Clear existing markers
      allMarkers.addAll(_fuelStationMarkers); // Add gas station markers
      allMarkers.addAll(
          _currentLocationMarkers); // Add current location markers
    } else {
      throw Exception('Failed to fetch nearby fuel stations');
    }
    print(center);
  }


  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 60,
          title: Column(
            children: [
              Text("Fuel Alert System", style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold,)),
              Text("$alert", style: TextStyle(fontSize: 16.0, color: Colors.redAccent, fontWeight: FontWeight.bold)),

            ],
          ),
      ),
      body: SafeArea(
        child: Container(
          color: Colors.blue[100],
          child: Column(
            children: [

              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 5.0, 5.0, 5.0),
                    child: Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.grey,
                            blurRadius: 6.0,
                            spreadRadius: 2.0,
                            offset: Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text("Fuel Left", style: TextStyle(fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900])),
                          Text("${(realTimeValue1/1000).toStringAsFixed(2)}", style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
                         // Text("${Distance60km.toStringAsFixed(1)}", style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
                         // Text("$consum60km", style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(25.0, 5.0, 10.0, 5.0),
                    child: Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.grey,
                            blurRadius: 6.0,
                            spreadRadius: 2.0,
                            offset: Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text("Speed", style: TextStyle(fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900])),
                          Text("${_speed > 5 ? _speed.toStringAsFixed(1) : '0'}", style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
                         // Text("${Distance40km.toStringAsFixed(1)}", style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
                         // Text("$consum40km", style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(5.0, 5.0, 20.0, 5.0),
                    child: Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.grey,
                            blurRadius: 10.0,
                            spreadRadius: 2.0,
                            offset: Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text("Distance left", style: TextStyle(
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900])),
                          Text("${(DistanceCanGo/1000).toInt()} Km", style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],

              ),
              Expanded(
                child: Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: center,
                        zoom: 10.0,
                      ),
                      markers: allMarkers,
                    ),
                    Positioned(
                      bottom: 16.0,
                      left: 16.0,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ConsumptionScreen(resetCallback: reset),
                            ),
                          );
                        },
                        child: Text("See Full Information"),
                      ),
                    ),
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