import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng initialPosition;
  const MapPickerScreen({super.key, required this.initialPosition});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? pickedPosition;
  late GoogleMapController mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick Location"),
        backgroundColor: const Color(0xFFFF4B7D),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => mapController = controller,
            initialCameraPosition: CameraPosition(
              target: widget.initialPosition,
              zoom: 14,
            ),
            onTap: (pos) => setState(() => pickedPosition = pos),
            markers: {
              if (pickedPosition != null)
                Marker(markerId: const MarkerId('picked'), position: pickedPosition!)
            },
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4B7D),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text(
                "Confirm Location",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              onPressed: pickedPosition == null
                  ? null
                  : () => Navigator.pop(context, pickedPosition),
            ),
          ),
        ],
      ),
    );
  }
}
