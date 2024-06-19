import 'package:assignment661/homepage.dart';
import 'package:assignment661/utils/authentication.dart';
import 'package:flutter/material.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      body: SafeArea(
          child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logoMoodForMusic.png', // Replace with your image asset path
              height: 200, // Set the desired height
              width: 200, // Set the desired width
            ),
            SizedBox(
              height: 20,
            ),
            Text(
              "Mood For Music",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic),
            ),
            SizedBox(
              height: 80,
            ),
            Text(
              "Welcome! ",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 30),
            Text(
              "Use your fingerprint to login",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 30),
            ElevatedButton(
                onPressed: () async {
                  bool auth = await Authentication.authentication();
                  print("can authenticate: $auth");
                  if (auth) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => MyHomePage()));
                  }
                },
                style: ButtonStyle(
                  fixedSize: MaterialStateProperty.all<Size>(
                    Size(100, 75), // Set the width and height of the button
                  ),
                ),
                child: Icon(Icons.fingerprint)),
          ],
        ),
      )),
    );
  }
}
