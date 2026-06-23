import 'package:geolocator/geolocator.dart';
import '../../domain/entities/location_point.dart';

abstract class GpsDataSource {
  Future<LocationPoint?> getCurrentLocation();
  Stream<LocationPoint> get locationStream;
  Future<bool> isGpsEnabled();
  Future<bool> requestPermissions();
}

class GpsDataSourceImpl implements GpsDataSource {
  static const _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 2,
  );

  @override
  Future<bool> requestPermissions() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<bool> isGpsEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPoint?> getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return _fromPosition(pos);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<LocationPoint> get locationStream =>
      Geolocator.getPositionStream(locationSettings: _locationSettings)
          .map(_fromPosition);

  LocationPoint _fromPosition(Position pos) => LocationPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        altitude: pos.altitude,
        speed: pos.speed,
        accuracy: pos.accuracy,
        timestamp: pos.timestamp,
      );
}
