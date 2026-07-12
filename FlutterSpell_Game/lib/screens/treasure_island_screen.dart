import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';

class Cosmetic {
  final int id;
  final String name;
  final String icon;
  final bool owned;
  final bool equipped;

  Cosmetic({
    required this.id,
    required this.name,
    required this.icon,
    required this.owned,
    required this.equipped,
  });
}

class TreasureIslandScreen extends StatefulWidget {
  const TreasureIslandScreen({Key? key}) : super(key: key);

  @override
  State<TreasureIslandScreen> createState() => _TreasureIslandScreenState();
}

class _TreasureIslandScreenState extends State<TreasureIslandScreen> {
  late List<Cosmetic> _cosmetics;
  late int _equippedId;

  @override
  void initState() {
    super.initState();
    _initializeMockData();
  }

  void _initializeMockData() {
    _cosmetics = [
      Cosmetic(
        id: 1,
        name: 'Panda',
        icon: '🐼',
        owned: true,
        equipped: true,
      ),
      Cosmetic(
        id: 2,
        name: 'Fox',
        icon: '🦊',
        owned: true,
        equipped: false,
      ),
      Cosmetic(
        id: 3,
        name: 'Pirate Outfit',
        icon: '🏴‍☠️',
        owned: true,
        equipped: false,
      ),
      Cosmetic(
        id: 4,
        name: 'Detective Hat',
        icon: '🎩',
        owned: true,
        equipped: false,
      ),
      Cosmetic(
        id: 5,
        name: 'Wizard',
        icon: '🧙',
        owned: false,
        equipped: false,
      ),
    ];
    _equippedId = 1;
  }

  void _equipCosmetic(int cosmeticId) {
    setState(() {
      _equippedId = cosmeticId;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cosmetic equipped!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Treasure Island'),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Cosmetics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cosmetics.length,
              itemBuilder: (context, index) {
                return _buildCosmeticCard(_cosmetics[index]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCosmeticCard(Cosmetic cosmetic) {
    final isOwned = cosmetic.owned;
    final isEquipped = cosmetic.id == _equippedId;

    return Card(
      color: isEquipped ? Colors.amber[50] : Colors.white,
      elevation: isEquipped ? 4 : 1,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Cosmetic Icon
                Text(
                  cosmetic.icon,
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 8),

                // Name
                Text(
                  cosmetic.name,
                  style: Theme.of(context).textTheme.labelLarge,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Button
                if (isOwned)
                  ElevatedButton(
                    onPressed: () => _equipCosmetic(cosmetic.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEquipped ? Colors.green : Colors.blue,
                      minimumSize: const Size(double.infinity, 36),
                    ),
                    child: Text(
                      isEquipped ? 'Equipped ✓' : 'Equip',
                      style: const TextStyle(fontSize: 12),
                    ),
                  )
                else
                  OutlinedButton(
                    onPressed: null,
                    child: const Text(
                      'Locked',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          // Equipped badge
          if (isEquipped)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green[400],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

          // Locked badge
          if (!isOwned)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red[400],
                ),
                child: const Icon(
                  Icons.lock,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
