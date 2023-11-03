import 'package:flutter/material.dart';
import 'data_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data_model.dart'; // Import the DataModel cla
import 'package:untitled2/main.dart';

class ConsumptionScreen extends StatefulWidget {
  final VoidCallback resetCallback;
  ConsumptionScreen({required this.resetCallback});
  @override
  _ConsumptionScreenState createState() => _ConsumptionScreenState();
}

class _ConsumptionScreenState extends State<ConsumptionScreen> {
  @override
  Widget build(BuildContext context) {
    final dataModel = Provider.of<DataModel>(context);

    return Scaffold(
      appBar: AppBar(title: Text("Consumption Screen")),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Consumption After last Fuel fill: ${((dataModel.consum)/1000).toStringAsFixed(2)}L", style:TextStyle(fontSize: 15.0,fontWeight: FontWeight.bold)),
              Text("Distance travelled: ${((dataModel.totalDistance)/1000).toStringAsFixed(2) }KM",style:TextStyle(fontSize: 15.0,fontWeight: FontWeight.bold)),
              Text("Distance travelled:after tank ${((dataModel.totalDistanceAfterTank)/1000).toStringAsFixed(2) }KM",style:TextStyle(fontSize: 15.0,fontWeight: FontWeight.bold)),
              Text("Total Consumption: ${((dataModel.totalconsum)/1000).toStringAsFixed(2)}L",style:TextStyle(fontSize: 15.0,fontWeight: FontWeight.bold)),
              Text("Initial Fuel Level: ${dataModel.initFuelLevel}",style:TextStyle(fontSize: 15.0,fontWeight: FontWeight.bold)),
              Text("Average Consumption: ${dataModel. average_consumption.toStringAsFixed(2)} Km per l",style:TextStyle(fontSize: 15.0,fontWeight: FontWeight.bold)),
              Text("Your device ID: ${dataModel.deviceId}",style:TextStyle(fontSize: 15.0,fontWeight: FontWeight.bold)),
              Text("fuel fill last time: ${dataModel.fuel_fill}",style:TextStyle(fontSize: 15.0,fontWeight: FontWeight.bold)),

              ElevatedButton(
                onPressed: () {
                  widget.resetCallback();
                },
                child: Text("Reset"),
              )

            ],
          ),
        ),
      ),
    );
  }
}
