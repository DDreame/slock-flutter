// Standard integration test driver shim.
// Used with: flutter drive --driver=test_driver/integration_test.dart
//            --target=integration_test/benchmarks/<test>.dart -d linux --profile
import 'package:integration_test/integration_test_driver.dart';

void main() => integrationDriver();
