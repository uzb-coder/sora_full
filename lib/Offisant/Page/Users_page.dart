import 'dart:async';
import 'package:flutter/material.dart';
import '../../DB/UI/Hall_UI.dart';
import '../../DB/UI/Local_UI.dart';
import '../../Kirish.dart';
import '../Controller/usersCOntroller.dart';
import 'Login.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  late Future<List<User>> _usersFuture;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _usersFuture = UserController.getAllUsers();

    // ⏳ Har 1 soatda avtomatik yangilash
    _autoRefreshTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      final users = await UserController.getAllUsers(forceRefresh: true);
      setState(() {
        _usersFuture = Future.value(users);
      });
      debugPrint("⏰ Avto yangilash bajarildi (${DateTime.now()})");
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUsers() async {
    final users = await UserController.getAllUsers(forceRefresh: true);
    setState(() {
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
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HallTablesPage()),
              );
            },
            child: Text("Local"),
          ),
          IconButton(
            onPressed: _refreshUsers, // 🔄 qo‘lda yangilash
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Yangilash",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshUsers, // 📱 pull-to-refresh
        child: FutureBuilder<List<User>>(
          future: _usersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF144D37)),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Xatolik: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  "Foydalanuvchi topilmadi",
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            final users = snapshot.data!;

            return LayoutBuilder(
              builder: (context, constraints) {
                double maxWidth = constraints.maxWidth;
                double spacing = 12;

                if (maxWidth < 600) {
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => SizedBox(height: spacing),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return _buildUserCard(user);
                    },
                  );
                } else {
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 250,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return _buildUserCard(user);
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => WelcomeScreen()),
          );
        },
        label: const Text("Чиқиш"),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(120, 70),
          backgroundColor: const Color(0xFF144D37),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.white70, width: 1.5),
          ),
          elevation: 6,
        ),
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${user.firstName}",
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
  }
}
