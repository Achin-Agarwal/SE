import 'package:app/components/rolecard.dart';
import 'package:app/screens/organizer/role_list.dart';
import 'package:flutter/material.dart';

class Cart extends StatefulWidget {
  const Cart({super.key});

  @override
  State<Cart> createState() => _CartState();
}

class _CartState extends State<Cart> {
  String? selectedRole;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Padding(padding: EdgeInsets.only(left: size.width * 0.08)),
            Text(
              'Ongoing Deals',
              style: TextStyle(
                fontSize: size.width * 0.06,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        Expanded(
          child: SingleChildScrollView(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: selectedRole == null
                  ? _buildRoleList(size)
                  : RoleList(selectedRole: selectedRole),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleList(Size size) {
    return Row(
      children: [
        Padding(padding: EdgeInsets.only(left: size.width * 0.05)),
        Column(
          key: const ValueKey('roleList'),
          children: [
            SizedBox(height: size.height * 0.02),
            RoleCard(
              label: 'Photographer',
              icon: Icons.camera_alt,
              onTap: () => setState(() => selectedRole = 'Photographer'),
            ),
            SizedBox(height: size.height * 0.02),
            RoleCard(
              label: 'Caterer',
              icon: Icons.restaurant,
              onTap: () => setState(() => selectedRole = 'Caterer'),
            ),
            SizedBox(height: size.height * 0.02),
            RoleCard(
              label: 'Decorator',
              icon: Icons.brush,
              onTap: () => setState(() => selectedRole = 'Decorator'),
            ),
            SizedBox(height: size.height * 0.02),
            RoleCard(
              label: 'Musician',
              icon: Icons.music_note,
              onTap: () => setState(() => selectedRole = 'Musician'),
            ),
            SizedBox(height: size.height * 0.02),
          ],
        ),
      ],
    );
  }
}
