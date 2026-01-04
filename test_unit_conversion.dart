/// Test file to demonstrate unit conversion functionality
/// This shows how the UnitConverter handles different units

import 'package:visionvolcan_site_app/screens/inventory_screen.dart';

void main() {
  print('=== Unit Conversion Test ===');
  
  // Test 1: Ton to KG conversion
  final tonToKg = UnitConverter.convertToBaseUnit(1, 'ton');
  print('1 ton = $tonToKg kg'); // Should print: 1 ton = 1000.0 kg
  
  // Test 2: KG to KG conversion (base unit)
  final kgToKg = UnitConverter.convertToBaseUnit(3, 'kg');
  print('3 kg = $kgToKg kg'); // Should print: 3 kg = 3.0 kg
  
  // Test 3: Gram to KG conversion
  final gramToKg = UnitConverter.convertToBaseUnit(500, 'g');
  print('500 g = $gramToKg kg'); // Should print: 500 g = 0.5 kg
  
  // Test 4: Meter to Meter conversion (base unit)
  final meterToMeter = UnitConverter.convertToBaseUnit(5, 'm');
  print('5 m = $meterToMeter m'); // Should print: 5 m = 5.0 m
  
  // Test 5: Feet to Meter conversion
  final feetToMeter = UnitConverter.convertToBaseUnit(10, 'ft');
  print('10 ft = $feetToMeter m'); // Should print: 10 ft = 3.048 m
  
  // Test 6: Base unit identification
  print('Base unit for "ton": ${UnitConverter.getBaseUnit('ton')}'); // Should print: kg
  print('Base unit for "kg": ${UnitConverter.getBaseUnit('kg')}'); // Should print: kg
  print('Base unit for "meter": ${UnitConverter.getBaseUnit('meter')}'); // Should print: m
  print('Base unit for "bags": ${UnitConverter.getBaseUnit('bags')}'); // Should print: pcs
  
  // Test 7: Unit compatibility
  print('Are "ton" and "kg" compatible? ${UnitConverter.areCompatibleUnits('ton', 'kg')}'); // Should print: true
  print('Are "ton" and "meter" compatible? ${UnitConverter.areCompatibleUnits('ton', 'meter')}'); // Should print: false
  
  print('=== Test Complete ===');
}
