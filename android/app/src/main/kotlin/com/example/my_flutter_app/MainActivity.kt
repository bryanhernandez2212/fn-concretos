package com.example.my_flutter_app

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth (Face ID/Touch ID/biometría) requires a FragmentActivity to
// host its authentication prompt — FlutterActivity alone can't.
class MainActivity : FlutterFragmentActivity()
