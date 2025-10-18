import 'package:get/get.dart';

class FavoriteController extends GetxController {
  final RxList<String> songs = <String>[].obs;

  void add(String s) => songs.add(s);
  void remove(String s) => songs.remove(s);
}
