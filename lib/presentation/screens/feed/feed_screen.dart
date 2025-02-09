import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../domain/video/video_model.dart';
import '../../../domain/video/video_repository.dart';
import '../../widgets/video/video_action_buttons.dart';
import '../../../domain/video/electric_video_sequence.dart';
import '../../physics/one_page_scroll_physics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
  
  // Map to store persistent keys for videos
  final Map<String, GlobalKey<_VideoItemState>> _videoKeys = {};
  
  // Loading state
  bool _isLoading = false;

  // Add PageController
  late final PageController _pageController;
  // Track current page
  int _currentPage = 0;
  
  // Track number of active controllers
  int _activeControllers = 0;

  // Method to update active controller count
  void _updateActiveControllerCount(bool isActive) {
    setState(() {
      if (isActive) {
        _activeControllers++;
        print('➕ Controller added (Total: $_activeControllers)');
      } else {
        _activeControllers--;
        print('➖ Controller removed (Total: $_activeControllers)');
      }
      
      // Sanity check
      if (_activeControllers > 3) {
        print('⚠️ Warning: More than 3 active controllers ($_activeControllers)');
      }
    });
  }

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
    // Clean up all keys when disposing
    _videoKeys.clear();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedGenre != widget.selectedGenre) {
      print('\n🔄 Genre Switch:');
      print('📱 Genre changed to: ${_getGenreName(widget.selectedGenre)}');
      print('🔑 Clearing ${_videoKeys.length} keys');
      print('🎮 Active controllers before clear: $_activeControllers');
      _pageController.jumpTo(0);
      _videoKeys.clear();
      setState(() => _videos = []);
      _loadVideos();
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
    print('\n📱 Feed Status:');
    print('📍 Page changed to index: $index');
    print('🎥 Current video ID: ${_videos[index].id}');
    print('🔑 Active keys count: ${_videoKeys.length}');
    print('🎮 Active controllers: $_activeControllers');
    print('🗺️ All video keys: ${_videoKeys.keys.join(", ")}');
    
    // First, dispose all existing controllers
    for (int i = 0; i < _videos.length; i++) {
      final key = _getVideoItemKey(i);
      print('🗑️ Attempting to dispose controller for video ${_videos[i].id}');
      if (key.currentState?.isInitialized ?? false) {
        print('✅ Found initialized controller for video ${_videos[i].id}');
      } else {
        print('❌ No initialized controller for video ${_videos[i].id}');
      }
      key.currentState?.disposeController();
    }
    
    // Then update current page
    setState(() {
      _currentPage = index;
      print('📍 Updated current page to: $index');
    });

    // Handle electric sequence
    await _electricSequence.stopWatching();
    if (_electricSequence.shouldShowElectricNext()) {
      final nextElectricVideo = await _electricSequence.getNextElectricVideo();
      if (nextElectricVideo != null) {
        setState(() {
          _videos.insert(index + 1, Video.fromFirestore(nextElectricVideo));
          print('🎸 Inserted electric video at index ${index + 1}');
        });
      }
    }
  }

  // Get GlobalKey for video item
  GlobalKey<_VideoItemState> _getVideoItemKey(int index) {
    if (index < 0 || index >= _videos.length) {
      print('❌ Invalid index requested: $index (videos length: ${_videos.length})');
      throw Exception('Invalid video index');
    }
    final videoId = _videos[index].id;
    final existingKey = _videoKeys[videoId];
    if (existingKey != null) {
      print('🔑 Reusing existing key for video: $videoId');
      print('🎮 Controller status: ${existingKey.currentState?.isInitialized}');
    }
    return _videoKeys.putIfAbsent(videoId, () {
      print('🆕 Creating new key for video: $videoId');
      return GlobalKey<_VideoItemState>();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const OnePageScrollPhysics().applyTo(
                const ClampingScrollPhysics(),
              ),
              itemCount: _videos.length + 1,
              onPageChanged: _handlePageChange,
              itemBuilder: (context, index) {
                if (index == _videos.length) {
                  return _buildEndScreen();
                }
                
                final video = _videos[index];
                return _VideoItem(
                  key: _getVideoItemKey(index),
                  video: video,
                  isVisible: index == _currentPage,
                  onVisibilityChanged: (isVisible) {
                    if (isVisible) {
                      _electricSequence.startWatching(video.id);
                    }
                  },
                  shouldPreload: false,
                  isInActiveWindow: index == _currentPage, // Only current video active
                );
              },
            ),
    );
  }

  Widget _buildEndScreen() {
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
}

// Individual video item widget
class _VideoItem extends StatefulWidget {
  final Video video;
  final bool isVisible;
  final Function(bool isVisible) onVisibilityChanged;
  final bool shouldPreload;
  final bool isInActiveWindow;
  final GlobalKey<_VideoItemState> key;

  const _VideoItem({
    required this.video,
    required this.isVisible,
    required this.onVisibilityChanged,
    this.shouldPreload = false,
    this.isInActiveWindow = false,
    required this.key,
  });

  @override
  State<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<_VideoItem> {
  // Change from late to nullable
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  
  // Add public getter
  bool get isInitialized => _isInitialized;

  // Add connectivity checker
  Future<String> _getConnectionType() async {
    if (kIsWeb) return 'Web';
    try {
      final connectivity = await Connectivity().checkConnectivity();
      switch (connectivity) {
        case ConnectivityResult.mobile:
          return '4G/5G';
        case ConnectivityResult.wifi:
          return 'WiFi';
        default:
          return 'Unknown';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  void initState() {
    super.initState();
    print('\n🎥 VideoItem initState:');
    print('📺 Video ID: ${widget.video.id}');
    print('👁️ Is in active window: ${widget.isInActiveWindow}');
    print('🎮 Has controller: ${_controller != null}');
    
    if (widget.isInActiveWindow) {
      print('🎬 Starting initialization in initState');
      _initializeVideo();
    }
    
    if (widget.isVisible) {
      widget.onVisibilityChanged(true);
    }
  }

  @override
  void didUpdateWidget(_VideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    print('\n🔄 Widget Update:');
    print('📺 Video ID: ${widget.video.id}');
    print('👁️ Previous active: ${oldWidget.isInActiveWindow}');
    print('👁️ Current active: ${widget.isInActiveWindow}');
    print('🎮 Has controller: ${_controller != null}');
    if (_controller != null) {
      print('📊 Controller state:');
      print('   - Initialized: ${_controller?.value.isInitialized}');
      print('   - Playing: ${_controller?.value.isPlaying}');
      print('   - Position: ${_controller?.value.position}');
    }
    
    if (oldWidget.isInActiveWindow != widget.isInActiveWindow) {
      if (!widget.isInActiveWindow) {
        disposeController();
      } else if (!_isInitialized) {
        print('🎥 Initializing video: ${widget.video.id}');
        _initializeVideo();
      }
    }
    
    if (oldWidget.isVisible != widget.isVisible) {
      widget.onVisibilityChanged(widget.isVisible);
      if (widget.isVisible && _isInitialized) {
        _controller?.play();
      } else if (_isInitialized) {
        _controller?.pause();
      }
    }
  }

  void disposeController() {
    print('\n🗑️ Resource Cleanup:');
    print('📺 Video ID: ${widget.video.id}');
    print('🎮 Controller exists: ${_controller != null}');
    print('✨ Is initialized: $_isInitialized');
    print('📱 Platform: ${_getPlatformType()}');
    
    if (_isInitialized && _controller != null) {
      print('🚮 Starting controller disposal...');
      _controller!.dispose();
      _isInitialized = false;
      _controller = null;
      print('✅ Controller disposed successfully');
    }
  }

  @override
  void dispose() {
    disposeController();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    final startTime = DateTime.now();
    print('\n📱 Device Info:');
    print('📱 Platform: ${_getPlatformType()}');
    print('🌐 Network Info:');
    print('📡 Connection type: ${await _getConnectionType()}');
    print('🔗 Video URL: ${widget.video.url}');
    
    print('\n🎬 Starting video initialization:');
    print('📺 Video ID: ${widget.video.id}');
    print('🌟 Widget mounted: $mounted');
    
    try {
      print('⚡ Creating controller...');
      _controller = VideoPlayerController.network(
        widget.video.url,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      
      // Add initialization start timestamp
      final initStartTime = DateTime.now();
      print('🔄 Initializing controller...');
      print('⏰ Init start time: ${initStartTime.toString()}');
      
      await _controller?.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⚠️ Initialization timeout after 10 seconds');
          print('📊 Last known controller state:');
          if (_controller != null) {
            print('   - Has error: ${_controller!.value.hasError}');
            print('   - Error description: ${_controller!.value.errorDescription}');
            print('   - Is buffering: ${_controller!.value.isBuffering}');
            print('   - Is initialized: ${_controller!.value.isInitialized}');
          }
          throw TimeoutException('Video initialization timed out after 10 seconds');
        },
      );
      
      final loadTime = DateTime.now().difference(startTime);
      print('\n⏱️ Performance Metrics:');
      print('   - Total load time: ${loadTime.inMilliseconds}ms');
      print('   - Init time: ${DateTime.now().difference(initStartTime).inMilliseconds}ms');
      
      if (_controller?.value.hasError ?? false) {
        print('🚨 Controller has error: ${_controller?.value.errorDescription}');
        throw Exception(_controller?.value.errorDescription);
      }
      
      print('✅ Controller initialized');
      print('📊 Video details:');
      print('   - Duration: ${_controller?.value.duration.inSeconds}s');
      print('   - Size: ${_controller?.value.size.width}x${_controller?.value.size.height}');
      print('   - Buffered: ${_controller?.value.buffered.length} parts');
      print('   - Is buffering: ${_controller?.value.isBuffering}');
      print('   - Is playing: ${_controller?.value.isPlaying}');
      
      await _controller?.setLooping(true);
      print('🔁 Looping enabled');
      
      // Add listener for buffering state
      _controller?.addListener(() {
        if (_controller!.value.isBuffering) {
          print('📶 Buffering started at position: ${_controller!.value.position}');
        }
      });
      
      if (mounted) {
        print('🎯 Widget still mounted, updating state');
        setState(() => _isInitialized = true);
        if (widget.isVisible && _controller != null) {
          print('▶️ Auto-playing video');
          await _controller!.play();
          print('✅ Playback started');
        }
      } else {
        print('❌ Widget not mounted after initialization');
      }
    } catch (e, stackTrace) {
      print('\n💥 Error Details:');
      print('❌ Error type: ${e.runtimeType}');
      print('🚨 Error message: $e');
      print('📱 Platform: ${_getPlatformType()}');
      print('🌐 Network: ${await _getConnectionType()}');
      if (_controller != null) {
        print('🎮 Controller state at error:');
        print('   - Initialized: ${_controller?.value.isInitialized}');
        print('   - Playing: ${_controller?.value.isPlaying}');
        print('   - Has error: ${_controller?.value.hasError}');
        print('   - Is buffering: ${_controller?.value.isBuffering}');
        print('   - Error description: ${_controller?.value.errorDescription}');
        print('   - Position: ${_controller?.value.position}');
      }
      print('📍 Stack trace: $stackTrace');
    }
  }

  void _togglePlayPause() async {
    if (!_isInitialized || _controller == null) return;

    try {
      if (_controller!.value.isPlaying) {
        await _controller!.pause();
      } else {
        await _controller!.play();
      }
      setState(() {});
    } catch (e) {
      print('❌ Error toggling play/pause: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player
          if (widget.isVisible && _isInitialized && _controller != null)
            VideoPlayer(_controller!)
          else
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
            
          // Play/Pause indicator overlay
          if (widget.isVisible && _isInitialized && _controller != null)
            AnimatedOpacity(
              opacity: _controller!.value.isPlaying ? 0.0 : 1.0,
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

// Add this utility function at the top level, before the FeedScreen class
String _getPlatformType() {
  if (kIsWeb) return 'Web';
  try {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  } catch (e) {
    return 'Web';
  }
} 