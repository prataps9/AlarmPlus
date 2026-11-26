
import 'package:timezone/timezone.dart' as tz;

// ─── World clock ───────────────────────────────────────────────────────────

/// A city offered in the world-clock picker.
class WorldCity {
  const WorldCity(this.name, this.country, this.tzId);

  final String name;
  final String country;

  /// IANA zone id, e.g. `Asia/Kolkata`.
  final String tzId;

  static const all = <WorldCity>[
    WorldCity('Auckland', 'New Zealand', 'Pacific/Auckland'),
    WorldCity('Sydney', 'Australia', 'Australia/Sydney'),
    WorldCity('Tokyo', 'Japan', 'Asia/Tokyo'),
    WorldCity('Seoul', 'South Korea', 'Asia/Seoul'),
    WorldCity('Beijing', 'China', 'Asia/Shanghai'),
    WorldCity('Hong Kong', 'China', 'Asia/Hong_Kong'),
    WorldCity('Singapore', 'Singapore', 'Asia/Singapore'),
    WorldCity('Bangkok', 'Thailand', 'Asia/Bangkok'),
    WorldCity('Jakarta', 'Indonesia', 'Asia/Jakarta'),
    WorldCity('Dhaka', 'Bangladesh', 'Asia/Dhaka'),
    WorldCity('Kathmandu', 'Nepal', 'Asia/Kathmandu'),
    WorldCity('New Delhi', 'India', 'Asia/Kolkata'),
    WorldCity('Mumbai', 'India', 'Asia/Kolkata'),
    WorldCity('Karachi', 'Pakistan', 'Asia/Karachi'),
    WorldCity('Dubai', 'UAE', 'Asia/Dubai'),
    WorldCity('Riyadh', 'Saudi Arabia', 'Asia/Riyadh'),
    WorldCity('Moscow', 'Russia', 'Europe/Moscow'),
    WorldCity('Istanbul', 'Türkiye', 'Europe/Istanbul'),
    WorldCity('Cairo', 'Egypt', 'Africa/Cairo'),
    WorldCity('Nairobi', 'Kenya', 'Africa/Nairobi'),
    WorldCity('Johannesburg', 'South Africa', 'Africa/Johannesburg'),
    WorldCity('Lagos', 'Nigeria', 'Africa/Lagos'),
    WorldCity('Berlin', 'Germany', 'Europe/Berlin'),
    WorldCity('Paris', 'France', 'Europe/Paris'),
    WorldCity('Madrid', 'Spain', 'Europe/Madrid'),
    WorldCity('Rome', 'Italy', 'Europe/Rome'),
    WorldCity('Amsterdam', 'Netherlands', 'Europe/Amsterdam'),
    WorldCity('London', 'United Kingdom', 'Europe/London'),
    WorldCity('Dublin', 'Ireland', 'Europe/Dublin'),
    WorldCity('Lisbon', 'Portugal', 'Europe/Lisbon'),
    WorldCity('São Paulo', 'Brazil', 'America/Sao_Paulo'),
    WorldCity('Buenos Aires', 'Argentina', 'America/Argentina/Buenos_Aires'),
    WorldCity('New York', 'United States', 'America/New_York'),
    WorldCity('Toronto', 'Canada', 'America/Toronto'),
    WorldCity('Chicago', 'United States', 'America/Chicago'),
    WorldCity('Mexico City', 'Mexico', 'America/Mexico_City'),
    WorldCity('Denver', 'United States', 'America/Denver'),
    WorldCity('Los Angeles', 'United States', 'America/Los_Angeles'),
    WorldCity('Vancouver', 'Canada', 'America/Vancouver'),
    WorldCity('Anchorage', 'United States', 'America/Anchorage'),
    WorldCity('Honolulu', 'United States', 'Pacific/Honolulu'),
  ];

  static WorldCity? byName(String name) {
    for (final c in all) {
      if (c.name == name) return c;
    }
    return null;
  }
}

/// What a world-clock row shows for [city] at the instant [nowUtc].
class CityTime {
  const CityTime({required this.wallTime, required this.offsetFromLocal, required this.dayLabel});

  /// The city's wall-clock time (fields only; don't treat as local).
  final DateTime wallTime;

  /// City offset minus local offset: how far ahead the city is.
  final Duration offsetFromLocal;

  /// "Today", "Tomorrow" or "Yesterday", relative to the local date.
  final String dayLabel;

  static CityTime of(WorldCity city, DateTime nowUtc, Duration localOffset) {
    final loc = tz.getLocation(city.tzId);
    final cityOffset = Duration(milliseconds: loc.timeZone(nowUtc.millisecondsSinceEpoch).offset);
    final wall = nowUtc.toUtc().add(cityOffset);
    final localWall = nowUtc.toUtc().add(localOffset);
    final dayDiff = DateTime.utc(wall.year, wall.month, wall.day)
        .difference(DateTime.utc(localWall.year, localWall.month, localWall.day))
        .inDays;
    return CityTime(
      // Kept in UTC: only its fields are shown, and building a local
      // DateTime moved a 02:xx city time an hour on the device's own
      // spring-forward day (that hour doesn't exist locally).
      wallTime: wall,
      offsetFromLocal: cityOffset - localOffset,
      dayLabel: switch (dayDiff) {
        > 0 => 'Tomorrow',
        < 0 => 'Yesterday',
        _ => 'Today',
      },
    );
  }
}
