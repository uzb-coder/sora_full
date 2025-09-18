import 'package:flutter/material.dart';
import 'package:sora/data/user_datas.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final TextEditingController _controller = TextEditingController();

  Future getValue() async {
    final api = await UserDatas().getApi();
    if (mounted) {
      setState(() {
        _controller.text = api;
      });
    }
  }

  @override
  void initState() {
    getValue();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xffeae3e3),
      appBar: AppBar(
        title: const Text('Sozlamalar'),
        backgroundColor: const Color(0xffeae3e3),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: width * .05),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: width * .02,
            children: [
              Text(
                "Server Api:",
                style: TextStyle(
                  fontSize: width * .04,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextFormField(
                controller: _controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                onChanged: (value) {
                  UserDatas().saveApi(value.trim());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
