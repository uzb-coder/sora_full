import 'package:flutter/material.dart';

import '../../Admin/Page/Cilnet_page.dart';
import '../../Kirish.dart';
import '../Controller/usersCOntroller.dart';
import 'Login.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  static List<User>? _cachedUsers; // 🔹 Global cache (memory ichida saqlanadi)
  late Future<List<User>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<List<User>> _loadUsers() async {
    if (_cachedUsers != null && _cachedUsers!.isNotEmpty) {
      debugPrint("📦 Cache'dan yuklanyapti...");
      return _cachedUsers!;
    } else {
      debugPrint("🌐 Serverdan yuklanyapti...");
      final users = await UserController.getAllUsers();
      _cachedUsers = users;
      return users;
    }
  }

  Future<void> _refreshUsers() async {
    debugPrint("♻️ Cache tozalandi va qayta yuklanyapti...");
    _cachedUsers = null; // cache tozalash
    final users = await UserController.getAllUsers();
    setState(() {
      _cachedUsers = users;
      _usersFuture = Future.value(users);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: const Text(
          "Ҳодимлар",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF144D37),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _refreshUsers, // 🔄 sahifani yangilash
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Yangilash",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshUsers,
        child: FutureBuilder<List<User>>(
          future: _usersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF144D37)));
            } else if (snapshot.hasError) {
              return Center(
                  child: Text("Xatolik: ${snapshot.error}",
                      style: const TextStyle(color: Colors.red)));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                  child: Text("Foydalanuvchi topilmadi",
                      style: TextStyle(color: Colors.grey)));
            }

            final users = snapshot.data!;

            return LayoutBuilder(
              builder: (context, constraints) {
                double maxWidth = constraints.maxWidth;
                double spacing = 12;

                if (maxWidth < 600) {
                  // Kichik ekran: ListView vertikal ro'yxat
                  return ListView.separated(
                    padding: EdgeInsets.all(12),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => SizedBox(height: spacing),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return SizedBox(
                        height: 180,
                        child: Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => LoginScreen(user: user)),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF144D37), Color(0xFF1B5E20)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                    child: const Icon(Icons.person_rounded,
                                        color: Colors.white, size: 30),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    user.firstName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.role,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  // Katta ekran: Wrap grid
                  int crossAxisCount;

                  if (maxWidth >= 1200) {
                    crossAxisCount = 4;
                  } else if (maxWidth >= 900) {
                    crossAxisCount = 3;
                  } else {
                    crossAxisCount = 2;
                  }

                  double totalSpacing = spacing * (crossAxisCount - 1);
                  double cardWidth = (maxWidth - totalSpacing) / crossAxisCount;

                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 250, // har bir card uchun maksimal eni
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2, // eni/balandligi nisbatini boshqarish
                    ),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => LoginScreen(user: user)),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF144D37), Color(0xFF1B5E20)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  child: const Icon(Icons.person_rounded,
                                      color: Colors.white, size: 30),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  user.firstName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.role,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            );

          },
        ),
      ),
      floatingActionButton: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) =>WelcomeScreen()));
        },
        label: const Text("Чиқиш"),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(120, 70),
          backgroundColor: backgroundColor,
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.grey, width: 2),
          ),
          shadowColor: Colors.black.withOpacity(0.2),
          elevation: 6,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }
}
