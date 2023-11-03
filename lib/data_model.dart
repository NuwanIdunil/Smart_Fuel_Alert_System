import 'package:flutter/foundation.dart'; // Import the foundation package

class DataModel with ChangeNotifier {
  int _consum = 0;
  int _previousconsum = 0;
  double _totalconsum = 0;
  int _initFuelLevel = 0;
  double _averageConsumption = 0.0;
  double _totalDistanceAfterTank =0.0;
  double _totalDistance=0.0;
  late String _deviceId;
  double _fuel_fill=0.0;

  int get consum => _consum;
  int get previousconsum => _previousconsum;
  double get totalconsum => _totalconsum;
  int get initFuelLevel => _initFuelLevel;
  double get average_consumption => _averageConsumption;
  double get totalDistanceAfterTank => _totalDistanceAfterTank;
  double get totalDistance => _totalDistance ;
  String get deviceId => _deviceId;
  double get fuel_fill =>_fuel_fill;

  set consum(int value) {
    _consum = value;
    notifyListeners(); // Notify listeners when the data changes
  }
  set previousconsum(int value) {
    _previousconsum = value;
    notifyListeners(); // Notify listeners when the data changes
  }
  set totalDistanceAfterTank (double value) {
    _totalDistanceAfterTank = value;
    notifyListeners();
  }

  set totalconsum(double value) {
    _totalconsum = value;
    notifyListeners();
  }

  set initFuelLevel(int value) {
    _initFuelLevel = value;
    notifyListeners();
  }

  set average_consumption(double value) {
    _averageConsumption = value;
    notifyListeners();
  }
  set totalDistance (double value) {
    _totalDistance = value;
    notifyListeners();
  }

  set deviceId (String value) {
    _deviceId = value;
    notifyListeners(); // Notify listeners when the data changes
  }

  set fuel_fill (double value) {
    _fuel_fill = value;
    notifyListeners();
  }
}

