
import 'package:intl/intl.dart';

class NovaFormatters {
  NovaFormatters._();

  static String dateTime(DateTime value, String locale) {
    return DateFormat.yMMMd(locale).add_jm().format(value.toLocal());
  }

  static String date(DateTime value, String locale) {
    return DateFormat.yMMMd(locale).format(value.toLocal());
  }
}
