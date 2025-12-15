import 'dart:convert';
import 'package:http/http.dart' as http;

class PhilippineAddressService {
  // Using PSGC API (Philippine Standard Geographic Code)
  static const String baseUrl = 'https://psgc.gitlab.io/api';

  // Get all regions
  static Future<List<Map<String, dynamic>>> getRegions() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/regions/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map(
              (e) => {
                'code': e['code'],
                'name': e['name'],
                'regionName': e['regionName'] ?? e['name'],
              },
            )
            .toList();
      }
    } catch (e) {
      print('Error fetching regions: $e');
    }
    return [];
  }

  // Get provinces by region code
  static Future<List<Map<String, dynamic>>> getProvinces(
    String regionCode,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/regions/$regionCode/provinces/'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // Sort alphabetically
        data.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );
        return data.map((e) => {'code': e['code'], 'name': e['name']}).toList();
      }
    } catch (e) {
      print('Error fetching provinces: $e');
    }
    return [];
  }

  // Get cities/municipalities by province code
  // Note: For NCR (Metro Manila), cities are directly under the region, but the API might structure them under "districts" or treat them specially.
  // The PSGC API usually allows fetching cities/mun by region as well for NCR.
  static Future<List<Map<String, dynamic>>> getCitiesMunicipalities(
    String code, {
    bool isRegion = false,
  }) async {
    try {
      final url = isRegion
          ? '$baseUrl/regions/$code/cities-municipalities/'
          : '$baseUrl/provinces/$code/cities-municipalities/';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        data.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );
        return data.map((e) => {'code': e['code'], 'name': e['name']}).toList();
      }
    } catch (e) {
      print('Error fetching cities/municipalities: $e');
    }
    return [];
  }

  // Get barangays by city/municipality code
  static Future<List<Map<String, dynamic>>> getBarangays(
    String cityMunicipalityCode,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/cities-municipalities/$cityMunicipalityCode/barangays/',
        ),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        data.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );
        return data.map((e) => {'code': e['code'], 'name': e['name']}).toList();
      }
    } catch (e) {
      print('Error fetching barangays: $e');
    }
    return [];
  }
}
