import 'package:flutter/material.dart';

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
      top: kToolbarHeight + MediaQuery.of(context).padding.top - 5, 
      left: 110, 
      right: 16,
      child: Material(
        elevation: 8, 
        borderRadius: BorderRadius.circular(12),
        color: isDarkMode ? const Color(0xFF1E1E1E).withOpacity(0.95) : Colors.white.withOpacity(0.98),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDarkMode ? Colors.white10 : Colors.grey[300]!),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 5), 
            shrinkWrap: true,
            itemCount: filteredSuggestions.length,
            separatorBuilder: (c, i) => Divider(height: 1, color: isDarkMode ? Colors.white10 : Colors.grey[100]),
            itemBuilder: (c, i) {
              final suggestion = filteredSuggestions[i];
              return ListTile(
                dense: true, 
                visualDensity: VisualDensity.compact,
                leading: const Icon(Icons.history, size: 18, color: Colors.grey),
                title: Text(
                  suggestion['title']!, 
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black87
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  searchController.text = suggestion['title']!;
                  onSitemapTap(suggestion);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 2.0);
}