import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class RecycleBin {
  static Future<void> moveToTrash(String path) async {
    if (!Platform.isWindows) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      return;
    }

    final from = '$path\u0000\u0000'.toNativeUtf16();
    final fileOp = calloc<SHFILEOPSTRUCT>();

    fileOp.ref.hwnd = 0;
    fileOp.ref.wFunc = FO_DELETE;
    fileOp.ref.pFrom = from;
    fileOp.ref.pTo = nullptr;
    fileOp.ref.fFlags = FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_SILENT;

    final result = SHFileOperation(fileOp);

    calloc.free(from);
    calloc.free(fileOp);

    if (result != 0) {
      throw FileSystemException('trash failed with code $result', path);
    }
  }
}