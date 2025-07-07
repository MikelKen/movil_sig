import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DioProvider {

  static const String _baseUrl = 'http://10.29.8.48:3000/orders/formatted';

  Future<dynamic> getOrders() async {
    try{
      var response = await Dio().get('$_baseUrl/orders/formatted');

      if (response.statusCode == 200 && response.data != ''){
        print('Datos obtenidos: ${response.data}');
        return response.data;
      }
    }catch(error) {
      print ('Error al obtener los pedidos: $error');
      return error;
    }
  }

}