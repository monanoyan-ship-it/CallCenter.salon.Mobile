import 'package:callcenter_salon_mobil/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SalonBookingApp mounts MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const SalonBookingApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
