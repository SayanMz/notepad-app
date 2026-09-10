import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/services/semantic/semantic_taxonomy.dart';

void main() {
  group('SemanticTaxonomy', () {
    test(
      'topicDescriptions contains orthogonal topic categories and rich descriptions',
      () {
        final taxonomy = SemanticTaxonomy.topicDescriptions;

        expect(taxonomy, isNotEmpty);
        expect(taxonomy.length, equals(8));

        // Verify no duplicate keys
        final uniqueKeys = taxonomy.keys.toSet();
        expect(uniqueKeys.length, equals(taxonomy.length));

        // Verify key domain UI chip titles are present
        expect(taxonomy.containsKey('Software & Tech'), isTrue);
        expect(taxonomy.containsKey('Health & Fitness'), isTrue);
        expect(taxonomy.containsKey('Finance & Shopping'), isTrue);
        expect(taxonomy.containsKey('Food & Cooking'), isTrue);
        expect(taxonomy.containsKey('Entertainment'), isTrue);
        expect(taxonomy.containsKey('Work & Study'), isTrue);
        expect(taxonomy.containsKey('Travel & Transport'), isTrue);
        expect(taxonomy.containsKey('Personal & Social'), isTrue);

        // Verify every topic has a non-empty descriptive semantic prompt
        for (final description in taxonomy.values) {
          expect(description.trim(), isNotEmpty);
          expect(description.split(',').length, greaterThanOrEqualTo(5));
        }
      },
    );
  });
}
