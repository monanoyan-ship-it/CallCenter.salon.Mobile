import 'dart:math' as math;

/// Web Discover.cshtml ile aynı Haversine (km).
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double toRad(double x) => x * math.pi / 180;
  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

String distanceLabelKm(double? km) {
  if (km == null) return '';
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1)} km';
}

/// Türkçe karakter + büyük/küçük harf duyarlılığını eleyen arama normalize.
/// `Şişli` ve `sisli` aynı şekilde eşleşsin diye `_filteredList` gibi yerlerde kullan.
String normalizeForSearch(String input) {
  const map = {
    'ç': 'c', 'Ç': 'c',
    'ğ': 'g', 'Ğ': 'g',
    'ı': 'i', 'I': 'i', 'İ': 'i', 'i': 'i',
    'ö': 'o', 'Ö': 'o',
    'ş': 's', 'Ş': 's',
    'ü': 'u', 'Ü': 'u',
  };
  final buf = StringBuffer();
  for (final ch in input.toLowerCase().split('')) {
    buf.write(map[ch] ?? ch);
  }
  return buf.toString();
}
