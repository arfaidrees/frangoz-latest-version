import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:login_signup/Globals.dart';
import 'package:login_signup/components/Screens/forget_password_page.dart';
import 'package:login_signup/components/Screens/nav_screen.dart';
import 'package:login_signup/components/Screens/signup_page.dart';
import 'package:login_signup/components/common/custom_form_button.dart';
import 'package:login_signup/components/common/custom_input_field.dart';
import 'package:login_signup/components/common/page_heading.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/page_header.dart';
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginFormKey = GlobalKey<FormState>();
  String email = "", password = "";

  final emailcontroller = TextEditingController();
  TextEditingController passwordcontroller = TextEditingController();

  userLogin() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email, password: password);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Homepage()),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'User Not Found') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              "No user found for that Email",
              style: TextStyle(fontSize: 18),
            )));
      } else if (e.code == 'wrong password') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              "Wrong Password Provided by User",
              style: TextStyle(fontSize: 18),
            )));
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Have a listener on the TextEditingController to see changes
    emailcontroller.addListener(() {
      print('Email Controller Value: ${emailcontroller.text}');
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery
        .of(context)
        .size;
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xffEEF1F3),
        body: Column(
          children: [
            const PageHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),),
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: _loginFormKey,
                    child: Column(
                      children: [
                        const PageHeading(title: 'Welcome Riders!',),
                        CustomInputField(
                            controller: emailcontroller,
                            labelText: 'Email',
                            hintText: 'Your email id',
                            validator: (textValue) {
                              if (textValue == null || textValue.isEmpty) {
                                return 'Email is required!';
                              }

                              return null;
                            }
                        ),
                        const SizedBox(height: 16,),
                        CustomInputField(
                          controller: passwordcontroller,
                          labelText: 'Password',
                          hintText: 'Your password',
                          obscureText: true,
                          suffixIcon: true,
                          validator: (textValue) {
                            if (textValue == null || textValue.isEmpty) {
                              return 'Password is required!';
                            }
                            //if(!EmailValidator.validate(textValue)) {
                            //   return 'Please enter a valid email';
                            //  }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16,),
                        Container(
                          width: size.width * 0.80,
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () =>
                            {
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (
                                      context) => const ForgetPasswordPage()))
                            },
                            child: const Text(
                              'Forget password?',
                              style: TextStyle(
                                color: Color(0xff939393),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20,),
                        CustomFormButton(
                          innerText: 'Login', onPressed: _handleLoginUser,),
                        const SizedBox(height: 18,),
                        SizedBox(
                          width: size.width * 0.8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Don\'t have an account ? ',
                                style: TextStyle(fontSize: 13,
                                    color: Color(0xff939393),
                                    fontWeight: FontWeight.bold),),
                              GestureDetector(
                                onTap: () =>
                                {
                                  Navigator.push(context, MaterialPageRoute(
                                      builder: (context) => const SignupPage()))
                                },
                                child: const Text('Sign-up', style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xff748288),
                                    fontWeight: FontWeight.bold),),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20,),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  _handleLoginUser() async {
    // login user
    if (_loginFormKey.currentState!.validate()) {
      // Set email and password directly from text controllers
      email = emailcontroller.text;
      password = passwordcontroller.text;
      loginEmail = emailcontroller.text;
      if (kDebugMode) {
        print(loginEmail);
        // print("Email: $email");
        print("Password: $password");
      }
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('loginEmail', emailcontroller.text);
      // Print email and password to check if they are correct

      // Call userLogin with the updated values
      await userLogin();
    }
  }

}