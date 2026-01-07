import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

class ProductState {
  final bool isLoading;
  ProductState({this.isLoading = false});
}

class ProductController extends StateNotifier<ProductState> {
  ProductController() : super(ProductState());
  Future<bool> uploadProduct({required String name, required String price, required File imageFile}) async {
    state = ProductState(isLoading: true);
    await Future.delayed(const Duration(seconds: 2));
    state = ProductState(isLoading: false);
    return true;
  }
}

final productControllerProvider = StateNotifierProvider<ProductController, ProductState>((ref) => ProductController());