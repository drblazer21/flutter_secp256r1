import 'dart:convert';

import 'package:agent_dart/agent_dart.dart' show P256PublicKey;
import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:secp256r1/secp256r1.dart';
import 'package:tuple/tuple.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _publicKeyAlice = 'Unknown';
  String _publicKeyBob = 'Unknown';
  String _strongboxSupport = 'Unknown';
  String _signed = 'Unknown';

  bool? _verified;

  String? _sharedSecret, _decrypted;
  Tuple2<Uint8List, Uint8List>? _encrypted;

  final _payloadTEC = TextEditingController(text: 'Hello world');
  final _othersPublicKeyTEC = TextEditingController();

  String get alice => 'alice';
  String get bob => 'bob';

  String get _verifyPayload => _payloadTEC.text;

  final LocalAuthentication auth = LocalAuthentication();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: ListView(
          children: [
            SelectableText('Android Strongbox support: $_strongboxSupport\n'),
            SelectableText('getPublicKey Alice: $_publicKeyAlice\n'),
            SelectableText('getPublicKey Bob: $_publicKeyBob\n'),
            SelectableText('sign: $_signed\n'),
            SelectableText('verify: $_verified\n'),
            SelectableText('sharedSecret: $_sharedSecret\n'),
            SelectableText('encrypted: $_encrypted\n'),
            SelectableText('decrypted: $_decrypted\n'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: TextField(
                controller: _payloadTEC,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  label: Text('Payload text field'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: TextField(
                controller: _othersPublicKeyTEC,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  label: Text('Others Public Key (hex)'),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                SecureP256.isStrongboxSupported().then(
                  (s) => setState(() => _strongboxSupport = s.toString()),
                );

                // VERIFY BIOMETRICS
                final bool canAuthenticateWithBiometrics =
                    await auth.canCheckBiometrics;
                final bool canAuthenticate = canAuthenticateWithBiometrics ||
                    await auth.isDeviceSupported();

                if (canAuthenticate) {
                  final List<BiometricType> availableBiometrics =
                      await auth.getAvailableBiometrics();

                  if (availableBiometrics.isNotEmpty) {
                    // Some biometrics are enrolled.
                    print('Biometrics enrolled');

                    bool didAuthenticate = false;
                    try {
                      didAuthenticate = await auth.authenticate(
                          localizedReason: 'Authentication required!');
                    } on PlatformException catch (e) {
                      print('PlatformException $e');
                    }
                    if (didAuthenticate) {
                      SecureP256.getPublicKey(alice).then(
                        (r) => setState(
                            () => _publicKeyAlice = hex.encode(r.rawKey)),
                      );
                      SecureP256.getPublicKey(bob).then(
                        (r) => setState(
                            () => _publicKeyBob = hex.encode(r.rawKey)),
                      );
                      print(_publicKeyAlice);
                      print(_publicKeyBob);
                    }
                  } else {
                    print('Biometrics not enrolled');
                  }
                } else {
                  print('Biometrics not supported');
                }
              },
              child: const Text('getPublicKey'),
            ),
            ElevatedButton(
              onPressed: () async {
                bool didAuthenticate = false;
                try {
                  didAuthenticate = await auth.authenticate(
                      localizedReason: 'Authentication required!');
                } on PlatformException catch (e) {
                  print('PlatformException $e');
                }
                if (didAuthenticate) {
                  SecureP256.sign(
                    alice,
                    Uint8List.fromList(utf8.encode(_verifyPayload)),
                  ).then((r) => setState(() => _signed = hex.encode(r)));
                }
              },
              child: const Text('sign'),
            ),
            ElevatedButton(
              onPressed: () async {
                bool didAuthenticate = false;
                try {
                  didAuthenticate = await auth.authenticate(
                      localizedReason: 'Authentication required!');
                } on PlatformException catch (e) {
                  print('PlatformException $e');
                }
                if (didAuthenticate) {
                  SecureP256.verify(
                    Uint8List.fromList(utf8.encode(_verifyPayload)),
                    P256PublicKey.fromRaw(
                      Uint8List.fromList(hex.decode(_publicKeyAlice)),
                    ),
                    Uint8List.fromList(hex.decode(_signed)),
                  ).then((r) => setState(() => _verified = r));
                }
              },
              child: const Text('verify'),
            ),
            ElevatedButton(
              onPressed: () async {
                bool didAuthenticate = false;
                try {
                  didAuthenticate = await auth.authenticate(
                      localizedReason: 'Authentication required!');
                } on PlatformException catch (e) {
                  print('PlatformException $e');
                }
                if (didAuthenticate) {
                  SecureP256.getSharedSecret(
                    alice,
                    await SecureP256.getPublicKey(bob),
                  ).then((r) => setState(() => _sharedSecret = hex.encode(r)));
                }
              },
              child: const Text('getSharedSecret'),
            ),
            ElevatedButton(
              onPressed: () async {
                bool didAuthenticate = false;
                try {
                  didAuthenticate = await auth.authenticate(
                      localizedReason: 'Authentication required!');
                } on PlatformException catch (e) {
                  print('PlatformException $e');
                }
                if (didAuthenticate) {
                  SecureP256.encrypt(
                    sharedSecret: Uint8List.fromList(
                      hex.decode(_sharedSecret!),
                    ),
                    message: Uint8List.fromList(utf8.encode('TEST')),
                  ).then((r) => setState(() => _encrypted = r));
                }
              },
              child: const Text('Encrypt (FFI)'),
            ),
            ElevatedButton(
              onPressed: () async {
                bool didAuthenticate = false;
                try {
                  didAuthenticate = await auth.authenticate(
                      localizedReason: 'Authentication required!');
                } on PlatformException catch (e) {
                  print('PlatformException $e');
                }
                if (didAuthenticate) {
                  SecureP256.decrypt(
                    sharedSecret: Uint8List.fromList(
                      hex.decode(_sharedSecret!),
                    ),
                    iv: _encrypted!.item1,
                    cipher: _encrypted!.item2,
                  ).then((r) => setState(() => _decrypted = utf8.decode(r)));
                }
              },
              child: const Text('Decrypt (FFI)'),
            ),
          ],
        ),
      ),
    );
  }
}
