import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

class MediaHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Picks an image from the gallery and compresses it
  static Future<Uint8List?> pickAndCompressImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    return _compressImage(bytes);
  }

  /// Captures an image with the camera and compresses it
  static Future<Uint8List?> captureAndCompressImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    return _compressImage(bytes);
  }

  static Uint8List? _compressImage(Uint8List bytes) {
    // Decode image
    img.Image? decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) return null;

    // Resize if too large (e.g. max 1280px)
    final int maxSize = 1280;
    if (decodedImage.width > maxSize || decodedImage.height > maxSize) {
      decodedImage = img.copyResize(
        decodedImage,
        width: decodedImage.width > decodedImage.height ? maxSize : null,
        height: decodedImage.height > decodedImage.width ? maxSize : null,
      );
    }

    // Encode as JPG with 80% quality
    return Uint8List.fromList(img.encodeJpg(decodedImage, quality: 80));
  }

  /// Picks any file
  static Future<File?> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      return File(result.files.single.path!);
    }
    return null;
  }
}
