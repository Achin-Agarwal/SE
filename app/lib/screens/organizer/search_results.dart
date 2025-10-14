import 'package:app/screens/organizer/vendor_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/providers/navigation_provider.dart';

class SearchResult extends ConsumerStatefulWidget {
  final String? selectedRole;
  const SearchResult({super.key, required this.selectedRole});

  @override
  ConsumerState<SearchResult> createState() => _SearchResultState();
}

class _SearchResultState extends ConsumerState<SearchResult> {
  Map<String, dynamic>? selectedVendor;

  final List<Map<String, dynamic>> vendors = [
    {
      "id": null,
      "name": "Sweet Delights Bakery",
      "rating": 4.9,
      "role": "Caterer",
      "description":
          "Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.Delicate pastries, exquisite cakes, and desserts for all occasions.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Cake World",
      "rating": 4.7,
      "role": "Caterer",
      "description": "Custom cakes and desserts for every celebration.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Sugar & Spice",
      "rating": 4.8,
      "role": "Decorator",
      "description": "Home-style baking with love and passion.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Bake My Day",
      "rating": 3.6,
      "role": "Musician",
      "description": "Delicious cakes, cupcakes, and more for all occasions.",
      "selected": false,
    },
    {
      "id": null,
      "name": "The Dessert Studio",
      "rating": 4.9,
      "role": "Photographer",
      "description": "Creative desserts and custom sweet treats.",
      "selected": false,
    },
    {
      "id": null,
      "name": "LensCraft Studios",
      "rating": 4.8,
      "role": "Photographer",
      "description": "Capturing timeless memories with creative perspective.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Golden Frame Photography",
      "rating": 4.5,
      "role": "Photographer",
      "description": "Wedding, portrait, and event photography services.",
      "selected": false,
    },
    {
      "id": null,
      "name": "StarSound Band",
      "rating": 4.6,
      "role": "Musician",
      "description": "Live band performances for parties and weddings.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Harmony Tunes",
      "rating": 4.2,
      "role": "Musician",
      "description": "Acoustic and instrumental music for all moods.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Elite Events Decor",
      "rating": 4.7,
      "role": "Decorator",
      "description": "Transforming spaces into unforgettable experiences.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Bloom & Bliss",
      "rating": 4.4,
      "role": "Decorator",
      "description": "Floral arrangements and elegant wedding decorations.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Melody Makers",
      "rating": 4.9,
      "role": "Musician",
      "description": "Professional music group with a wide genre range.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Flavorsome Feast",
      "rating": 4.3,
      "role": "Caterer",
      "description": "Gourmet dishes made to delight every palate.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Visual Verse Studio",
      "rating": 4.8,
      "role": "Photographer",
      "description": "Creative wedding and fashion photography specialists.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Grand Affair Caterers",
      "rating": 4.5,
      "role": "Caterer",
      "description": "Elegant dining solutions for large events and parties.",
      "selected": false,
    },
    {
      "id": null,
      "name": "StageGlow Events",
      "rating": 4.6,
      "role": "Decorator",
      "description":
          "Lighting, decor, and setup for unforgettable celebrations.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Rhythm Roots",
      "rating": 4.1,
      "role": "Musician",
      "description": "Fusion music group bringing energy and rhythm.",
      "selected": false,
    },
    {
      "id": null,
      "name": "CineSnap Creations",
      "rating": 4.9,
      "role": "Photographer",
      "description": "Award-winning cinematography and photography studio.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Gourmet Gala",
      "rating": 4.8,
      "role": "Caterer",
      "description": "Luxury catering with a mix of global cuisines.",
      "selected": false,
    },
    {
      "id": null,
      "name": "DecorDazzle",
      "rating": 4.2,
      "role": "Decorator",
      "description": "Theme-based decoration experts for weddings & events.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Perfect Capture",
      "rating": 4.7,
      "role": "Photographer",
      "description": "Specialized in candid wedding and portrait photography.",
      "selected": false,
    },
    {
      "id": null,
      "name": "FoodMood Catering",
      "rating": 4.4,
      "role": "Caterer",
      "description": "Delicious, hygienic, and creatively served food.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Symphony Souls",
      "rating": 4.8,
      "role": "Musician",
      "description": "Soulful live band bringing your events to life.",
      "selected": false,
    },
    {
      "id": null,
      "name": "DreamCanvas Decor",
      "rating": 4.3,
      "role": "Decorator",
      "description": "We paint your dream wedding with lights and flowers.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Candid Soul Studio",
      "rating": 4.9,
      "role": "Photographer",
      "description": "Emotional and cinematic photography for modern couples.",
      "selected": false,
    },
    {
      "id": null,
      "name": "FeastCraft",
      "rating": 4.5,
      "role": "Caterer",
      "description": "Inventive menus and seamless service for all events.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Harmony Hive",
      "rating": 4.6,
      "role": "Musician",
      "description":
          "Melodic ensemble performing both classical and modern hits.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Velvet Lights Decor",
      "rating": 4.7,
      "role": "Decorator",
      "description": "Adding elegance and charm to every corner of your venue.",
      "selected": false,
    },
    {
      "id": null,
      "name": "SnapSphere Studio",
      "rating": 4.8,
      "role": "Photographer",
      "description": "Professional photo & video coverage for all occasions.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Epicurean Edge",
      "rating": 4.9,
      "role": "Caterer",
      "description": "Luxury catering that blends taste and presentation.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Rhythm Rebels",
      "rating": 4.5,
      "role": "Musician",
      "description": "Dynamic band creating unforgettable vibes.",
      "selected": false,
    },
    {
      "id": null,
      "name": "DecorMania",
      "rating": 4.4,
      "role": "Decorator",
      "description": "Bespoke decoration services with creativity and detail.",
      "selected": false,
    },
    {
      "id": null,
      "name": "LensLuxe",
      "rating": 4.6,
      "role": "Photographer",
      "description": "High-end event and lifestyle photography experts.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Chef’s Palette",
      "rating": 4.7,
      "role": "Caterer",
      "description": "Fine dining catering service with artistic presentation.",
      "selected": false,
    },
    {
      "id": null,
      "name": "SoulStrings",
      "rating": 4.3,
      "role": "Musician",
      "description": "Live acoustic sessions for intimate gatherings.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Elegant Aura Decor",
      "rating": 4.6,
      "role": "Decorator",
      "description": "Luxury decoration for modern wedding experiences.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Visionary Frames",
      "rating": 4.9,
      "role": "Photographer",
      "description": "Cinematic visuals and storytelling photography.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Food Symphony",
      "rating": 4.2,
      "role": "Caterer",
      "description": "Innovative cuisine with perfect flavor balance.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Echo Beats",
      "rating": 4.7,
      "role": "Musician",
      "description": "Energetic band with live DJ performances.",
      "selected": false,
    },
    {
      "id": null,
      "name": "Drape & Dazzle",
      "rating": 4.5,
      "role": "Decorator",
      "description": "Custom decor solutions to match any theme or vibe.",
      "selected": false,
    },
    {
      "id": null,
      "name": "AuraCaptures",
      "rating": 4.8,
      "role": "Photographer",
      "description": "Vibrant photos that capture emotions in motion.",
      "selected": false,
    },
    {
      "id": null,
      "name": "TasteQuest",
      "rating": 4.1,
      "role": "Caterer",
      "description": "Quality food service with innovative menu options.",
      "selected": false,
    },
    {
      "id": null,
      "name": "RhythmRise",
      "rating": 4.6,
      "role": "Musician",
      "description": "Upbeat performers to set the tone of your event.",
      "selected": false,
    },
    {
      "id": null,
      "name": "BloomVista Decor",
      "rating": 4.4,
      "role": "Decorator",
      "description": "Aesthetic event design with floral art and elegance.",
      "selected": false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final vendorsOfRole = vendors.where(
      (v) => v["role"] == widget.selectedRole,
    );

    final allSelected =
        vendorsOfRole.isNotEmpty &&
        vendorsOfRole.every((v) => v["selected"] == true);

    return Container(
      // decoration: BoxDecoration(color: Colors.red),
      padding: EdgeInsets.only(bottom: size.height * 0.015),
      width: size.width * 0.9,
      child: selectedVendor == null
          ? Column(
              children: [
                SizedBox(height: size.height * 0.01),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: size.width * 0.02),
                        ),
                        Text(
                          "List",
                          style: TextStyle(
                            fontSize: size.width * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "All",
                          style: TextStyle(
                            fontSize: size.width * 0.04,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFFF4B7D),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              for (var vendor in vendors.where(
                                (v) => v["role"] == widget.selectedRole,
                              )) {
                                vendor["selected"] = !allSelected;
                              }
                            });
                          },
                          icon: Icon(
                            allSelected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: const Color(0xFFFF4B7D),
                            size: size.width * 0.07,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Vendor List
                Expanded(
                  child: ListView.builder(
                    itemCount: vendorsOfRole.length,
                    itemBuilder: (context, index) {
                      final vendor = vendorsOfRole.elementAt(index);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedVendor = vendor; // 👈 open detail
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: size.height * 0.006,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.brown[300],
                                child: Text(
                                  vendor["name"][0],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: size.width * 0.045,
                                  ),
                                ),
                              ),
                              SizedBox(width: size.width * 0.04),

                              // Vendor info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vendor["name"],
                                      style: TextStyle(
                                        fontSize: size.width * 0.045,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: size.height * 0.004),
                                    Row(
                                      children: [
                                        ...List.generate(
                                          5,
                                          (i) => Icon(
                                            i < vendor["rating"].floor()
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: Colors.amber,
                                            size: size.width * 0.04,
                                          ),
                                        ),
                                        SizedBox(width: size.width * 0.02),
                                        Text(
                                          vendor["rating"].toString(),
                                          style: TextStyle(
                                            fontSize: size.width * 0.035,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: size.height * 0.004),
                                    Text(
                                      vendor["description"],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: size.width * 0.035,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Checkbox
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    vendor["selected"] = !vendor["selected"];
                                  });
                                },
                                icon: Icon(
                                  vendor["selected"]
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  color: vendor["selected"]
                                      ? const Color(0xFFFF4B7D)
                                      : Colors.grey[400],
                                  size: size.width * 0.07,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Done button
                Padding(
                  padding: EdgeInsets.only(top: size.height * 0.015),
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(navIndexProvider.notifier).state = 1;
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4B7D),
                      minimumSize: Size(double.infinity, size.height * 0.065),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      "Done",
                      style: TextStyle(
                        fontSize: size.width * 0.045,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : VendorDetailCard(
              vendor: selectedVendor!,
              onClose: () {
                setState(() {
                  selectedVendor = null; // 👈 back to list
                });
              },
            ),
    );
  }
}
