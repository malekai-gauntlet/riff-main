import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../domain/video/video_model.dart';
import '../../../domain/video/video_repository.dart';
import '../../widgets/video/video_action_buttons.dart';
import '../../../domain/video/electric_video_sequence.dart';
import '../../physics/one_page_scroll_physics.dart';

class FeedScreen extends StatefulWidget {
  final int selectedGenre;
  
  const FeedScreen({
    super.key,
    required this.selectedGenre,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // Repository to fetch videos
  final VideoRepository _videoRepository = VideoRepository();
  
  // Electric video sequence handler
  final ElectricVideoSequence _electricSequence = ElectricVideoSequence();
  
  // List to store fetched videos
  List<Video> _videos = [];
  
  // Loading state
  bool _isLoading = false;

  // Add PageController
  late final PageController _pageController;
  // Track current page
  int _currentPage = 0;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 1.0,
      keepPage: true,
    );
    _electricSequence.onSuppressStateChanged = () {
      setState(() {
        if (_electricSequence.suppressElectric) {
          _videos = _videos.where((video) => !video.tags.contains('electric')).toList();
        }
      });
    };
    _loadVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedGenre != widget.selectedGenre) {
      print('📱 Genre changed to: ${_getGenreName(widget.selectedGenre)}');
      // Reset page controller and clear videos before loading new ones
      _pageController.jumpTo(0);
      setState(() => _videos = []);
      _loadVideos(); // Reload videos when genre changes
    }
  }

  String _getGenreName(int genre) {
    switch (genre) {
      case 1: return 'For You';
      case 2: return 'Acoustic';
      case 3: return 'Fingerstyle';
      case 4: return 'Electric';
      default: return 'Unknown';
    }
  }
  
  // Load initial videos
  Future<void> _loadVideos() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    
    try {
      final videos = await _videoRepository.getVideoFeed();
      var genreFilteredVideos = videos;
      
      switch (widget.selectedGenre) {
        case 2:
          genreFilteredVideos = videos.where((video) => video.tags.contains('acoustic')).toList();
          break;
        case 3:
          genreFilteredVideos = videos.where((video) => video.tags.contains('fingerstyle')).toList();
          break;
        case 4:
          genreFilteredVideos = videos.where((video) => video.tags.contains('electric')).toList();
          break;
      }
      
      final filteredVideos = _electricSequence.suppressElectric
          ? genreFilteredVideos.where((video) => !video.tags.contains('electric')).toList()
          : genreFilteredVideos;
      
      setState(() => _videos = filteredVideos);
    } catch (e) {
      print('❌ Error loading videos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Handle page changes and electric video sequence
  void _handlePageChange(int index) async {
    print('\n🎯 Active Window Status:');
    if (index > 0) {
      print('   Previous [$index-1]: ${_videos[index - 1].id} (Active)');
    }
    print('   Current  [$index]: ${_videos[index].id} (Active)');
    if (index < _videos.length - 1) {
      print('   Next    [$index+1]: ${_videos[index + 1].id} (Active)');
    }
    if (index < _videos.length - 2) {
      print('   Future  [$index+2]: ${_videos[index + 2].id} (Inactive)');
    }
    print('🎮 Total videos in memory: ${_videos.length}');

    await _electricSequence.stopWatching();
    setState(() {
      _currentPage = index;
      
      // Keep only necessary videos in memory (window of 5: 2 before, current, 2 after)
      if (_videos.length > 5) {
        int startKeep = (index - 2).clamp(0, _videos.length);
        int endKeep = (index + 3).clamp(0, _videos.length);
        _videos = _videos.sublist(startKeep, endKeep);
        print('📦 Trimmed videos list to: ${_videos.length} videos');
      }
    });

    if (_electricSequence.shouldShowElectricNext()) {
      final nextElectricVideo = await _electricSequence.getNextElectricVideo();
      if (nextElectricVideo != null) {
        setState(() {
          _videos.insert(index + 1, Video.fromFirestore(nextElectricVideo));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const OnePageScrollPhysics().applyTo(
                const ClampingScrollPhysics(),
              ),
              itemCount: _videos.length + 1, // Add 1 for end screen
              onPageChanged: _handlePageChange,
              itemBuilder: (context, index) {
                // Show end screen if we're at the last index
                if (index == _videos.length) {
                  return Container(
                    color: Colors.black,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "That's all the riffs!",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "More coming tomorrow.",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                
                final video = _videos[index];
                return _VideoItem(
                  video: video,
                  isVisible: index == _currentPage,
                  onVisibilityChanged: (isVisible) {
                    if (isVisible) {
                      _electricSequence.startWatching(video.id);
                    }
                  },
                  shouldPreload: index == _currentPage + 1,
                  isInActiveWindow: (index >= _currentPage - 1 && index <= _currentPage + 1), // In 3-video window
                );
              },
            ),
    );
  }
}

// Individual video item widget
class _VideoItem extends StatefulWidget {
  final Video video;
  final bool isVisible;
  final Function(bool isVisible) onVisibilityChanged;
  final bool shouldPreload;
  final bool isInActiveWindow;

  const _VideoItem({
    required this.video,
    required this.isVisible,
    required this.onVisibilityChanged,
    this.shouldPreload = false,
    this.isInActiveWindow = false,
  });

  @override
  State<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<_VideoItem> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  final String _instanceId = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    if (widget.isInActiveWindow) {
      print('🎥 Initializing: ${widget.video.id}');
      _initializeVideo();
    }
    
    if (widget.isVisible) {
      widget.onVisibilityChanged(true);
    }
  }

  @override
  void didUpdateWidget(_VideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.isInActiveWindow != widget.isInActiveWindow) {
      if (!widget.isInActiveWindow && _isInitialized) {
        print('🗑️ Disposing: ${widget.video.id}');
        _controller.dispose();
        _isInitialized = false;
      } else if (widget.isInActiveWindow && !_isInitialized) {
        print('🎥 Initializing: ${widget.video.id}');
        _initializeVideo();
      }
    }
    
    if (oldWidget.isVisible != widget.isVisible) {
      widget.onVisibilityChanged(widget.isVisible);
      if (widget.isVisible && _isInitialized) {
        _controller.play();
      } else if (_isInitialized) {
        _controller.pause();
      }
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.network(widget.video.url);
      await _controller.initialize();
      await _controller.setLooping(true);
      
      if (mounted) {
        setState(() => _isInitialized = true);
        if (widget.isVisible) {
          await _controller.play();
        }
      }
    } catch (e) {
      print('❌ Failed to initialize: ${widget.video.id}');
    }
  }

  void _togglePlayPause() async {
    if (!_isInitialized) return;

    try {
      if (_controller.value.isPlaying) {
        await _controller.pause();
      } else {
        await _controller.play();
      }
      setState(() {});
    } catch (e) {
      print('❌ Error toggling play/pause: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // Make sure tap is detected anywhere
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player
          if (widget.isVisible && _isInitialized)
            VideoPlayer(_controller)
          else
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
            
          // Play/Pause indicator overlay
          if (widget.isVisible && _isInitialized)
            AnimatedOpacity(
              opacity: _controller.value.isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                color: Colors.black.withOpacity(0.2),
                child: const Center(),
              ),
            ),
            
          // Action buttons (right side)
          Positioned(
            right: 8,
            bottom: 0,
            child: VideoActionButtons(
              video: widget.video,
              controller: _controller,
            ),
          ),
            
          // Video info overlay (bottom)
          Positioned(
            left: 0,
            right: 70, // Make room for action buttons
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.video.description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 