import 'package:flutter_riverpod/legacy.dart';

final dateProvider = StateProvider<Map<String, DateTime?>>((ref) => {
  'start': null,
  'end': null,
});
