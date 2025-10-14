import 'package:app/components/role_item_card.dart';
import 'package:flutter/material.dart';

class RoleList extends StatelessWidget {
  const RoleList({super.key, required this.selectedRole});

  final String? selectedRole;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final roles = [
      {
        'name': 'The Hearth Loaf Bakery',
        'description':
            'We believe baking is an art form. Our small-batch approach and commitment to traditional techniques result in a rustic charm and deep flavor in every loaf and pastry.',
        'rating': 4.8,
        'status': 'Requested',
        'statusColor': Colors.grey,
      },
      {
        'name': 'Elite Events DJ',
        'description':
            'Elite Events DJ provides professional and polished mobile DJ services for weddings, parties, and events, with a focus on creating the perfect atmosphere.',
        'rating': 4.9,
        'status': 'Requested',
        'statusColor': Colors.grey,
      },
      {
        'name': 'Urban Grooves Entertainment',
        'description':
            'Urban Grooves Entertainment provides professional and versatile DJ services for all occasions, offering seamless mixes and energetic performances.',
        'rating': 4.9,
        'status': 'Accepted',
        'statusColor': const Color(0xFFFF4B7D),
      },
      {
        'name': 'Urban Grooves Entertainment',
        'description':
            'Urban Grooves Entertainment provides professional and versatile DJ services for all occasions, offering seamless mixes and energetic performances.',
        'rating': 4.9,
        'status': 'Accepted',
        'statusColor': const Color(0xFFFF4B7D),
      },
      {
        'name': 'Urban Grooves Entertainment',
        'description':
            'Urban Grooves Entertainment provides professional and versatile DJ services for all occasions, offering seamless mixes and energetic performances.',
        'rating': 4.9,
        'status': 'Accepted',
        'statusColor': const Color(0xFFFF4B7D),
      },
    ];

    roles.sort((a, b) {
      if (a['status'] == b['status']) return 0;
      if (a['status'] == 'Accepted') return -1;
      return 1;
    });

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: size.height * 0.01,
        horizontal: size.width * 0.05,
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: roles.length,
        itemBuilder: (context, index) {
          final role = roles[index];
          return RoleItemCard(
            name: role['name'] as String,
            description: role['description'] as String,
            rating: role['rating'] as double,
            status: role['status'] as String,
            statusColor: role['statusColor'] as Color,
          );
        },
      ),
    );
  }
}
