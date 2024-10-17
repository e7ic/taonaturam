// lib/rust_ffi.dart
import 'dart:ffi'; // FFI 标准库
import 'dart:io'; // 用于检查平台

typedef RustAddNumbers = Int32 Function(Int32 a, Int32 b);
typedef AddNumbers = int Function(int a, int b);

class RustFFI {
  late DynamicLibrary _lib;

  RustFFI() {
    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open("rslib.so");
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process();
    }
  }

  int addNumbers(int a, int b) {
    final addNumbersPointer =
        _lib.lookup<NativeFunction<RustAddNumbers>>('add');
    final addNumbers = addNumbersPointer.asFunction<AddNumbers>();
    return addNumbers(a, b);
  }
}
