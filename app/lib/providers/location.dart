import 'package:flutter_riverpod/legacy.dart';

final locationProvider = StateProvider<Map<String, double>>((ref) => {
  'lat': 0.0,
  'lng': 0.0,
});
