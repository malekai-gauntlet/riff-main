import 'package:flutter/material.dart';
import '../../../domain/video/video_model.dart';
import '../../../domain/tab/tab_repository.dart';
import '../../../domain/tab/tab_template.dart';
import '../../../domain/tab/tab_renderer.dart';

class TabViewScreen extends StatefulWidget {
  final Video video;

  const TabViewScreen({
    super.key,
    required this.video,
  });

  @override
  State<TabViewScreen> createState() => _TabViewScreenState();
}

class _TabViewScreenState extends State<TabViewScreen> {
  // Repository instance
  final TabRepository _tabRepository = TabRepository();
  
  // Loading state
  bool _isLoading = true;
  String? _error;
  TabTemplate? _tab;

  @override
  void initState() {
    super.initState();
    _loadTab();
  }

  // Load or generate tab for the video
  Future<void> _loadTab() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final tab = await _tabRepository.getTabForVideo(widget.video);
      
      if (mounted) {
        setState(() {
          _tab = tab;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load tab: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.video.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Generating Tab...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTab,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_tab == null) {
      return const Center(
        child: Text(
          'No tab available',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      );
    }

    // Display the tab in a scrollable monospace font
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tab metadata
            Text(
              '${_tab!.songInfo.title} - ${_tab!.songInfo.artist}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Difficulty: ${_tab!.songInfo.difficulty}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            // Tab content in monospace font
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _tab!.toVisualTab(),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 