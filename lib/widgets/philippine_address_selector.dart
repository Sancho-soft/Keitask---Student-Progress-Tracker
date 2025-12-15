import 'package:flutter/material.dart';
import '../services/philippine_address_service.dart';

class PhilippineAddressSelector extends StatefulWidget {
  final Function(String) onAddressChanged;
  final String? initialAddress;

  const PhilippineAddressSelector({
    super.key,
    required this.onAddressChanged,
    this.initialAddress,
  });

  @override
  State<PhilippineAddressSelector> createState() =>
      _PhilippineAddressSelectorState();
}

class _PhilippineAddressSelectorState extends State<PhilippineAddressSelector> {
  // Data Lists
  List<Map<String, dynamic>> regions = [];
  List<Map<String, dynamic>> provinces = [];
  List<Map<String, dynamic>> cities = [];
  List<Map<String, dynamic>> barangays = [];

  // Selected Values (Codes)
  String? selectedRegionCode;
  String? selectedProvinceCode;
  String? selectedCityCode;
  String? selectedBarangayCode;

  // Selected Names (for storage)
  String? regionName;
  String? provinceName;
  String? cityName;
  String? barangayName;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    setState(() => _isLoading = true);
    final data = await PhilippineAddressService.getRegions();
    if (mounted) {
      setState(() {
        regions = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProvinces(String regionCode) async {
    setState(() => _isLoading = true);
    final data = await PhilippineAddressService.getProvinces(regionCode);

    // Some regions like NCR don't have provinces in the strict sense or API returns empty.
    // If no provinces, we might need to check for districts or go straight to cities (API dependant).
    // For PSGC API: NCR typically has districts which act as provinces level, or we can fetch cities directly by region if province list is empty.

    List<Map<String, dynamic>> cityData = [];
    if (data.isEmpty) {
      // Try fetching cities directly by region (e.g. NCR)
      cityData = await PhilippineAddressService.getCitiesMunicipalities(
        regionCode,
        isRegion: true,
      );
    }

    if (mounted) {
      setState(() {
        if (data.isNotEmpty) {
          provinces = data;
          cities = []; // reset cities if we found provinces
        } else {
          provinces = [];
          cities = cityData; // if no provinces, we populate cities directly
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCities(String provinceCode) async {
    setState(() => _isLoading = true);
    final data = await PhilippineAddressService.getCitiesMunicipalities(
      provinceCode,
    );
    if (mounted) {
      setState(() {
        cities = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBarangays(String cityCode) async {
    setState(() => _isLoading = true);
    final data = await PhilippineAddressService.getBarangays(cityCode);
    if (mounted) {
      setState(() {
        barangays = data;
        _isLoading = false;
      });
    }
  }

  void _updateAddress() {
    final parts = [
      barangayName,
      cityName,
      provinceName,
      regionName,
    ].where((s) => s != null && s.isNotEmpty).toList();

    widget.onAddressChanged(parts.join(', '));
  }

  // Custom dropdown builder
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade100,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Text('Select $label'),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item['code'],
                  child: Text(
                    item['name'] ?? item['regionName'] ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLoading) const LinearProgressIndicator(minHeight: 2),

        // Region
        _buildDropdown(
          label: 'Region',
          value: selectedRegionCode,
          items: regions,
          onChanged: (val) {
            if (val == null) return;
            final region = regions.firstWhere((e) => e['code'] == val);
            setState(() {
              selectedRegionCode = val;
              regionName = region['regionName'] ?? region['name'];
              // Reset lower levels
              selectedProvinceCode = null;
              provinceName = null;
              selectedCityCode = null;
              cityName = null;
              selectedBarangayCode = null;
              barangayName = null;
              provinces = [];
              cities = [];
              barangays = [];
            });
            _loadProvinces(val);
            _updateAddress();
          },
        ),

        // Province (Only show if we have provinces)
        if (provinces.isNotEmpty)
          _buildDropdown(
            label: 'Province',
            value: selectedProvinceCode,
            items: provinces,
            onChanged: (val) {
              if (val == null) return;
              final province = provinces.firstWhere((e) => e['code'] == val);
              setState(() {
                selectedProvinceCode = val;
                provinceName = province['name'];
                // Reset lower levels
                selectedCityCode = null;
                cityName = null;
                selectedBarangayCode = null;
                barangayName = null;
                cities = [];
                barangays = [];
              });
              _loadCities(val);
              _updateAddress();
            },
          ),

        // City / Municipality (Show if cities populated)
        // Note: For NCR, regions triggers cities population directly if provinces is empty.
        if (cities.isNotEmpty)
          _buildDropdown(
            label: 'City / Municipality',
            value: selectedCityCode,
            items: cities,
            onChanged: (val) {
              if (val == null) return;
              final city = cities.firstWhere((e) => e['code'] == val);
              setState(() {
                selectedCityCode = val;
                cityName = city['name'];
                // Reset lower levels
                selectedBarangayCode = null;
                barangayName = null;
                barangays = [];
              });
              _loadBarangays(val);
              _updateAddress();
            },
          ),

        // Barangay
        if (barangays.isNotEmpty)
          _buildDropdown(
            label: 'Barangay',
            value: selectedBarangayCode,
            items: barangays,
            onChanged: (val) {
              if (val == null) return;
              final barangay = barangays.firstWhere((e) => e['code'] == val);
              setState(() {
                selectedBarangayCode = val;
                barangayName = barangay['name'];
              });
              _updateAddress();
            },
          ),

        // Display Full Address Preview
        if (regionName != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Address: ${[barangayName, cityName, provinceName, regionName].where((s) => s != null).join(', ')}',
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.blueGrey,
              ),
            ),
          ),
      ],
    );
  }
}
