import 'package:intl/intl.dart';

Map<String, String> formatDateAndTime(String start, String end) {
  try {
    final startDT = DateTime.parse(start).toLocal();
    final endDT = DateTime.parse(end).toLocal();

    final dateFormat = DateFormat('dd/MM/yy');
    final timeFormat = DateFormat('h:mm a');

    final dateRange =
        "${dateFormat.format(startDT)} - ${dateFormat.format(endDT)}";
    final timeRange =
        "${timeFormat.format(startDT)} - ${timeFormat.format(endDT)}";

    return {"date": dateRange, "time": timeRange};
  } catch (e) {
    return {"date": "Invalid", "time": "Invalid"};
  }
}