import 'package:flutter_test/flutter_test.dart';

import 'package:setflow/data/wger_api.dart';

void main() {
  test('buildCatalog joins images with English translations', () {
    final images = [
      {
        'exercise': 167,
        'image': 'https://wger.de/media/x/Crunches-1.png',
        'thumbnails': {'small': 'https://wger.de/media/x/thumb.png'},
        'is_main': false,
      },
      {
        'exercise': 167,
        'image': 'https://wger.de/media/x/Crunches-main.png',
        'thumbnails': null,
        'is_main': true,
      },
      {'exercise': 999, 'image': 'https://wger.de/media/x/NoName.png'},
    ];
    final translations = [
      // German translation must be ignored.
      {'exercise': 167, 'name': 'Bauchpressen', 'language': 1},
      {
        'exercise': 167,
        'name': 'Crunches',
        'language': 2,
        'description': '<p>Lie down.</p><p>Curl &amp; hold.</p>',
      },
      // No image for this one → excluded.
      {'exercise': 555, 'name': 'Imageless', 'language': 2},
    ];

    final catalog = WgerApi.buildCatalog(images, translations);
    expect(catalog, hasLength(1));
    final r = catalog.single;
    expect(r.exerciseId, 167);
    expect(r.name, 'Crunches');
    // is_main image wins over the first-seen one.
    expect(r.imageUrl, 'https://wger.de/media/x/Crunches-main.png');
    expect(r.description, 'Lie down.\nCurl & hold.');
  });

  test('plainDescription strips tags and entities', () {
    expect(
      WgerApi.plainDescription(
          '<p>One</p><ul><li>Two&nbsp;&amp; three</li></ul><br>Four'),
      'One\nTwo & three\nFour',
    );
    expect(WgerApi.plainDescription(''), '');
  });
}
