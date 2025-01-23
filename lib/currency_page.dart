import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// المزود الخاص بالعملة الورقية (له fetchRate وغيره)
import 'currency_rate_provider.dart';

class CurrencyPage extends StatefulWidget {
  const CurrencyPage({super.key});

  @override
  State<CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<CurrencyPage> {
  bool _isLoading = false;

  /// القائمتان: الأصلية (الكل) والمعروضة (قد تُفلتر)
  List<dynamic> _originalList = [];
  List<dynamic> _displayedList = [];

  String _searchQuery = "";

  /// العملات المُفضَّلة (تظهر أعلى القائمة)
  final List<String> _majorSymbols = ["USD", "EUR", "GBP", "JPY"];

  @override
  void initState() {
    super.initState();
    _fetchCurrencies();
  }

  /// جلب البيانات من Supabase
  Future<void> _fetchCurrencies() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('curricanes') // <-- اسم الجدول في Supabase
          .select()
          .order('currency_name', ascending: true);

      _originalList = response;

      // وضع عملات الـ major في الأعلى
      _originalList = _sortMajorOnTop(_originalList);
      _displayedList = _originalList;

      // تعيين العملة الافتراضية (USD)
      final defaultCurrency = _originalList.firstWhere(
        (item) =>
            (item['currency_name'] ?? '').toString().toUpperCase() == "USD",
        orElse: () => null,
      );

      if (defaultCurrency != null) {
        // ignore: use_build_context_synchronously
        final currencyRateProv = context.read<CurrencyRateProvider>();
        await currencyRateProv.fetchRate(
          currencySymbol: defaultCurrency['currency_name'],
          flagUrl: defaultCurrency['currency_flag'],
        );
      }
    } catch (_) {
      // يمكن التعامل مع الخطأ هنا إن أحببت بدون طباعته
    }

    setState(() => _isLoading = false);
  }

  /// ترتيب عملات _majorSymbols في الأعلى
  List<dynamic> _sortMajorOnTop(List<dynamic> all) {
    final majorList = <dynamic>[];
    final othersList = <dynamic>[];

    for (var item in all) {
      final symbol = (item['currency_name'] ?? '').toString().toUpperCase();
      if (_majorSymbols.contains(symbol)) {
        majorList.add(item);
      } else {
        othersList.add(item);
      }
    }
    return [...majorList, ...othersList];
  }

  /// فلترة القائمة حسب البحث
  void _filterList(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();

      if (_searchQuery.isEmpty) {
        _displayedList = _originalList;
      } else {
        _displayedList = _originalList.where((currency) {
          final name =
              (currency['currency_name'] ?? '').toString().toLowerCase();
          final country = (currency['currency_country_name'] ?? '')
              .toString()
              .toLowerCase();
          return name.contains(_searchQuery) || country.contains(_searchQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF1F4F8);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Currency',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // حقل البحث
                  Container(
                    color: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      onTap: () => HapticFeedback.lightImpact(),
                      onChanged: (val) => _filterList(val),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        hintText: "Search currencies...",
                        hintStyle: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                  // القائمة
                  Expanded(
                    child: ListView.builder(
                      itemCount: _displayedList.length,
                      itemBuilder: (context, index) {
                        final currency = _displayedList[index];
                        final currencyName =
                            (currency['currency_name'] ?? '').toString();
                        final countryName =
                            (currency['currency_country_name'] ?? '')
                                .toString();
                        final flagUrl =
                            (currency['currency_flag'] ?? '').toString();

                        return Column(
                          children: [
                            InkWell(
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                final symbolUp = currencyName.toUpperCase();
                                final currencyRateProv =
                                    context.read<CurrencyRateProvider>();

                                // عند الاختيار: نحدّثه بالعملة + العلم
                                await currencyRateProv.fetchRate(
                                  currencySymbol: symbolUp,
                                  flagUrl: flagUrl,
                                );

                                // ignore: use_build_context_synchronously
                                Navigator.pop(context);
                              },
                              child: Container(
                                color: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    if (flagUrl.isNotEmpty) ...[
                                      Image.network(
                                        flagUrl,
                                        width: 32,
                                        height: 32,
                                        errorBuilder: (ctx, err, stack) {
                                          return const Icon(Icons.flag);
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            currencyName,
                                            style: const TextStyle(
                                              fontFamily: 'SpaceGrotesk',
                                              fontSize: 16,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            countryName,
                                            style: const TextStyle(
                                              fontFamily: 'SpaceGrotesk',
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              height: 1,
                              color: const Color(0xFFE6E6E9),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
