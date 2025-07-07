import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DioProvider {

  static const String _baseUrl = 'http:192.168.100.9:3000';

  Future<dynamic> getOrders() async {
    try{
      var response = await Dio().get('$_baseUrl/orders/formatted');

      if (response.statusCode == 200 && response.data != ''){
        return json.encode(response.data['data']);
      }
    }catch(error) {
      return error;
    }
  }

}