import 'package:flutter/material.dart';

class RequirementDetailsCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const RequirementDetailsCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['projectName'] ?? 'Unnamed Project',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Text('${data['assetType']} - ${data['configuration']}'),
            SizedBox(height: 8),
            Text('Area: ${data['area']} sqft'),
            SizedBox(height: 8),
            Text(
              'Budget: ${data['asPerMarketPrice'] ? 'As per market price' : '${data['budgetFrom']} Cr - ${data['budgetTo']} Cr'}',
            ),
            SizedBox(height: 16),
            Text(
              'Details:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(data['details'] ?? 'No details provided'),
            if (data['imageUrls'] != null &&
                (data['imageUrls'] as List).isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),
                  Text(
                    'Images:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Container(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: (data['imageUrls'] as List).length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              data['imageUrls'][index],
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
