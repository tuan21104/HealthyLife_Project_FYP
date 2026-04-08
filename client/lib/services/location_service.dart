import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  const LocationService();

  Future<Position?> getCurrentLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        lat,
        lng,
      );

      if (placemarks.isEmpty) {
        return 'Không xác định được địa chỉ';
      }

      final Placemark p = placemarks.first;

      final String houseNumber = (p.subThoroughfare ?? '').trim();
      final String streetName = (p.thoroughfare ?? '').trim();
      final String ward = (p.subLocality ?? '').trim();
      final String district = (p.locality ?? '').trim();
      final String city = (p.administrativeArea ?? '').trim();

      final List<String> parts = <String>[];

      final String streetFull = [
        houseNumber,
        streetName,
      ].where((String s) => s.isNotEmpty).join(' ').trim();

      if (streetFull.isNotEmpty) {
        parts.add(streetFull);
      }
      if (ward.isNotEmpty) {
        parts.add(ward);
      }
      if (district.isNotEmpty) {
        parts.add(district);
      }
      if (city.isNotEmpty) {
        parts.add(city);
      }

      if (parts.isNotEmpty) {
        return parts.join(', ');
      }

      return 'Không xác định được địa chỉ';
    } catch (_) {
      return 'Không xác định được địa chỉ';
    }
  }
}
