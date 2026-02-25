import 'package:flutter/material.dart';
import '../../utils/session.dart';

class LocationPickerScreen extends StatelessWidget {
  const LocationPickerScreen({super.key});

  static const locations = {
    "Ikeja": [6.6059, 3.3491],
    "Lekki": [6.4698, 3.5852],
    "Yaba": [6.5095, 3.3711],
    "Surulere": [6.4969, 3.3486],
    "Ajah": [6.4690, 3.6218],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Choose location")),
      body: ListView.separated(
        itemCount: locations.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (_, i) {
          final name = locations.keys.elementAt(i);
          final coords = locations[name]!;

          return ListTile(
            title: Text(name),
            onTap: () async {
              await Session.saveLocation(coords[0], coords[1]);

              Navigator.pop(context, {
                "lat": coords[0],
                "lng": coords[1],
              });
            },
          );
        },
      ),
    );
  }
}