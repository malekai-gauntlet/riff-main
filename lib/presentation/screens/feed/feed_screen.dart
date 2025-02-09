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
    print('🔥 HOT RELOAD TEST - App running on phone and web!');
    // Debug print to verify selected genre
    print('Initial selected genre: ${widget.selectedGenre}');
    
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 1.0,
      keepPage: true,
    );
    // Set up callback for when electric suppression changes
    _electricSequence.onSuppressStateChanged = () {
      print('🔄 Filtering out electric videos from current feed');
      setState(() {
        // Filter existing videos without reloading
        if (_electricSequence.suppressElectric) {
          _videos = _videos.where((video) => !video.tags.contains('electric')).toList();
          print('🎸 Removed electric videos. ${_videos.length} videos remaining');
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
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final videos = await _videoRepository.getVideoFeed();
      
      // First filter by selected genre
      var genreFilteredVideos = videos;
      
      // Apply genre filtering (1 = For You, 2 = Acoustic, 3 = Fingerstyle, 4 = Electric)
      switch (widget.selectedGenre) {
        case 2: // Acoustic
          genreFilteredVideos = videos.where((video) => video.tags.contains('acoustic')).toList();
          print('🎸 Filtered for acoustic videos: ${genreFilteredVideos.length}');
          break;
        case 3: // Fingerstyle
          genreFilteredVideos = videos.where((video) => video.tags.contains('fingerstyle')).toList();
          print('🎸 Filtered for fingerstyle videos: ${genreFilteredVideos.length}');
          break;
        case 4: // Electric
          genreFilteredVideos = videos.where((video) => video.tags.contains('electric')).toList();
          print('🎸 Filtered for electric videos: ${genreFilteredVideos.length}');
          break;
        case 1: // For You - no filtering needed
        default:
          print('🎸 Showing all videos: ${genreFilteredVideos.length}');
          break;
      }
      
      // Then apply electric suppression if needed
      final filteredVideos = _electricSequence.suppressElectric
          ? genreFilteredVideos.where((video) => !video.tags.contains('electric')).toList()
          : genreFilteredVideos;
          
      print('🎸 Final video count after all filtering: ${filteredVideos.length}');
      
      setState(() {
        _videos = filteredVideos;
      });
      
    } catch (e) {
      print('Error loading videos: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Handle page changes and electric video sequence
  void _handlePageChange(int index) async {
    print('📱 PAGE CHANGE: Moving to index $index');
    print('🔄 Current video count in memory: ${_videos.length}');
    
    // Stop tracking previous video
    await _electricSequence.stopWatching();
    
    setState(() {
      _currentPage = index;
    });

    // Log the transition
    if (index > 0) {
      print('📊 Previous video: ${_videos[index - 1].id}');
    }
    print('📊 Current video: ${_videos[index].id}');
    if (index < _videos.length - 1) {
      print('📊 Next video: ${_videos[index + 1].id}');
    }

    // Check if we should show an electric video
    if (_electricSequence.shouldShowElectricNext()) {
      final nextElectricVideo = await _electricSequence.getNextElectricVideo();
      if (nextElectricVideo != null) {
        // Convert Firestore document to Video model
        final video = Video.fromFirestore(nextElectricVideo);
        
        // Insert the electric video as the next video
        setState(() {
          _videos.insert(index + 1, video);
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

  const _VideoItem({
    required this.video,
    required this.isVisible,
    required this.onVisibilityChanged,
    this.shouldPreload = false,
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
    print('🎥 [Instance: $_instanceId] Creating new video item:');
    print('   - Video ID: ${widget.video.id}');
    print('   - Preload: ${widget.shouldPreload}');
    print('   - Is Visible: ${widget.isVisible}');
    _initializeVideo();
    if (widget.isVisible) {
      widget.onVisibilityChanged(true);
    }
  }

  @override
  void didUpdateWidget(_VideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('🔄 [Instance: $_instanceId] Widget updated:');
    print('   - Video ID: ${widget.video.id}');
    print('   - Old visible: ${oldWidget.isVisible} -> New visible: ${widget.isVisible}');
    print('   - Is Initialized: $_isInitialized');
    
    if (oldWidget.isVisible != widget.isVisible) {
      widget.onVisibilityChanged(widget.isVisible);
      if (widget.isVisible) {
        print('▶️ [Instance: $_instanceId] Attempting to play video');
        if (_isInitialized) {
          _controller.play();
        } else {
          print('⚠️ [Instance: $_instanceId] Tried to play but not initialized');
        }
      } else {
        print('⏸️ [Instance: $_instanceId] Pausing video');
        _controller.pause();
      }
    }
  }

  @override
  void dispose() {
    print('🗑️ [Instance: $_instanceId] Disposing video item:');
    print('   - Video ID: ${widget.video.id}');
    print('   - Was Initialized: $_isInitialized');
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    print('🎥 [Instance: $_instanceId] Starting initialization:');
    print('   - Video ID: ${widget.video.id}');
    print('   - URL: ${widget.video.url}');
    
    try {
      print('🎥 [Instance: $_instanceId] Creating controller...');
      _controller = VideoPlayerController.network(widget.video.url);
      
      print('🎥 [Instance: $_instanceId] Calling initialize()...');
      await _controller.initialize();
      print('✅ [Instance: $_instanceId] Initialize completed:');
      print('   - Video size: ${_controller.value.size}');
      print('   - Duration: ${_controller.value.duration}');
      
      print('🔄 [Instance: $_instanceId] Setting video to loop...');
      await _controller.setLooping(true);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          print('✅ [Instance: $_instanceId] State updated, ready to play');
        });
        
        if (widget.isVisible) {
          print('▶️ [Instance: $_instanceId] Video is visible, starting playback');
          await _controller.play();
          print('✅ [Instance: $_instanceId] Playback started');
        }
      }
    } catch (e, stackTrace) {
      print('❌ [Instance: $_instanceId] Error initializing video:');
      print('   - Error: $e');
      print('   - Location: ${stackTrace.toString().split('\n')[0]}');
      print('   - Video ID: ${widget.video.id}');
      print('   - Is Visible: ${widget.isVisible}');
      print('   - Should Preload: ${widget.shouldPreload}');
    }
  }

  void _togglePlayPause() async {
    print('Tap detected!'); // Debug print
    if (!_isInitialized) return;

    try {
      if (_controller.value.isPlaying) {
        print('Pausing video...'); // Debug print
        await _controller.pause();
      } else {
        print('Playing video...'); // Debug print
        await _controller.play();
      }
      // Force rebuild to update UI
      setState(() {});
    } catch (e) {
      print('Error toggling play/pause: $e');
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