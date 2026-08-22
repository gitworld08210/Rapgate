/// Represents a single height measurement taken via one of the available methods.
class HeightMeasurement {
  final String method;
  final double valueCm;
  final DateTime timestamp;
  final String? referenceObjectType;

  HeightMeasurement({
    required this.method,
    required this.valueCm,
    DateTime? timestamp,
    this.referenceObjectType,
  }) : timestamp = timestamp ?? DateTime.now();

  factory HeightMeasurement.fromMap(Map<String, dynamic> data) {
    return HeightMeasurement(
      method: data['method'] as String? ?? 'pose',
      valueCm: (data['value_cm'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.tryParse(data['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      referenceObjectType: data['reference_object_type'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'method': method,
        'value_cm': valueCm,
        'timestamp': timestamp.toIso8601String(),
        'reference_object_type': referenceObjectType,
      };
}

/// Result of height measurement - can hold multiple measurements for accuracy mode.
class HeightMeasurementResult {
  final List<HeightMeasurement> measurements;
  final double median;
  final double average;

  HeightMeasurementResult({
    required this.measurements,
    required this.median,
    required this.average,
  });

  factory HeightMeasurementResult.fromMeasurements(
      List<HeightMeasurement> measurements) {
    if (measurements.isEmpty) {
      return HeightMeasurementResult(
        measurements: [],
        median: 0,
        average: 0,
      );
    }

    final values = measurements.map((m) => m.valueCm).toList()..sort();
    final avg = values.reduce((a, b) => a + b) / values.length;

    double med;
    final mid = values.length ~/ 2;
    if (values.length % 2 == 0) {
      med = (values[mid - 1] + values[mid]) / 2;
    } else {
      med = values[mid];
    }

    return HeightMeasurementResult(
      measurements: measurements,
      median: med,
      average: avg,
    );
  }

  bool get isAccuracyMode => measurements.length > 1;
}
