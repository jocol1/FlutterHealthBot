import 'package:dio/dio.dart';

/// More examples see https://github.com/cfug/dio/blob/main/example
void sendmessage(message) async {
  try {
    final dio = Dio();
    final response = await dio.post(
        'https://api.telegram.org/bot7750523012:AAF6xJWhhywTIixNw_klqQzVvErU6NyhN_g/sendMessage?chat_id=1677251523&text=$message');
    print(response);
  } catch (e) {
    print(e.toString());
  }
}
