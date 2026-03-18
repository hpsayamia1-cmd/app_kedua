import 'package:flutter/material.dart';
import 'dart:ui';

class HeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  final bool isDarkMode;
  final bool isLoading; 
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<Map<String, String>> filteredSuggestions;
  final Function(String) onSearchSubmitted;
  final Function(String) onSearchChanged;
  final Function(Map<String, String>) onSitemapTap; 
  final VoidCallback onResetSearch;
  final VoidCallback onLogoTap;

  const HeaderWidget({
    super.key,
    required this.isDarkMode,
    this.isLoading = false,
    required this.searchController,
    required this.searchFocusNode,
    required this.filteredSuggestions,
    required this.onSearchSubmitted,
    required this.onSearchChanged,
    required this.onSitemapTap,
    required this.onResetSearch,
    required this.onLogoTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
      automaticallyImplyLeading: false, 
      title: Row(
        children: [
          // LOGO SINSANGNOT
          GestureDetector(
            onTap: onLogoTap,
            child: Image.asset(
              'assets/logo.png', 
              height: 28, 
              errorBuilder: (c, e, s) => const Icon(Icons.play_circle_fill, color: Colors.red)
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            "SinsangNot", 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -1)
          ),
          const SizedBox(width: 10),
          
          // KOLOM PENCARIAN DINAMIS
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white10 : Colors.grey[200],
                borderRadius: BorderRadius.circular(20)),
              child: TextField(
                controller: searchController,
                focusNode: searchFocusNode,
                onChanged: onSearchChanged,
                onSubmitted: onSearchSubmitted,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Cari...",
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: searchController,
                    builder: (context, value, child) {
                      return value.text.isNotEmpty
                          ? IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: onResetSearch,
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                  border: InputBorder.none, 
                  contentPadding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2.0),
        child: isLoading 
          ? const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              minHeight: 2.0,
            )
          : const SizedBox(height: 2.0),
      ),
    );
  }

  // WIDGET FLOATING SUGGESTIONS (Muncul saat mengetik)
Widget buildFloatingSuggestions(BuildContext context) {
  if (filteredSuggestions.isEmpty) return const SizedBox.shrink();

  return Positioned(
    top: 0, // Mengambang tepat di bawah Search Bar
    left: 20,
    right: 20,
    child: Material(
      elevation: 8, // Memberi efek bayangan agar terlihat mengambang
      borderRadius: BorderRadius.circular(15),
      color: Colors.transparent, // Kita buat transparan untuk efek blur
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          // Efek blur latar belakang (Glassmorphism)
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), 
          child: Container(
            constraints: const BoxConstraints(maxHeight: 300), // Batasi tinggi saran
            decoration: BoxDecoration(
  color: isDarkMode 
      ? const Color(0xFF0A2417).withOpacity(0.95)
      : Colors.white.withOpacity(0.8),
  borderRadius: BorderRadius.circular(15),
  border: Border.all(
    color: isDarkMode ? const Color(0xFF0F2D1A) : Colors.black12,
    width: 1,
  ),
),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: filteredSuggestions.length,
              separatorBuilder: (context, index) => Divider(
                height: 1, 
                color: isDarkMode ? Colors.white10 : Colors.black12
              ),
              itemBuilder: (context, index) {
                final s = filteredSuggestions[index];
                return ListTile(
                  leading: const Icon(Icons.history, size: 20, color: Colors.red),
                  title: Text(
                    s['title'] ?? "",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  onTap: () => onSitemapTap(s),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 2.0);
}