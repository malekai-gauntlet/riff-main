import 'package:flutter/material.dart';
import '../../../domain/video/video_model.dart';
import '../../../domain/video/video_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/tutorial/tutorial_screen.dart';
import 'package:video_player/video_player.dart';
import '../comment/comment_bottom_sheet.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Convert to StatefulWidget for local state management
class VideoActionButtons extends StatefulWidget {
  final Video video;
  final VideoPlayerController? controller;

  const VideoActionButtons({
    super.key,
    required this.video,
    this.controller,
  });

  @override
  State<VideoActionButtons> createState() => _VideoActionButtonsState();
}

class _VideoActionButtonsState extends State<VideoActionButtons> {
  final VideoRepository _videoRepository = VideoRepository();
  
  // Local state to track saved and liked status
  bool? _optimisticIsSaved;
  bool? _optimisticIsLiked;
  // Add optimistic like count
  int? _optimisticLikeCount;
  
  // Get current user ID
  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // Check if video is saved by current user, using optimistic value if available
  bool get _isSaved {
    if (_optimisticIsSaved != null) return _optimisticIsSaved!;
    return _currentUserId != null && widget.video.savedByUsers.contains(_currentUserId!);
  }

  // Check if video is liked by current user, using optimistic value if available
  bool get _isLiked {
    if (_optimisticIsLiked != null) return _optimisticIsLiked!;
    return _currentUserId != null && widget.video.likedByUsers.contains(_currentUserId!);
  }

  // Get current like count with optimistic value
  int get _likeCount {
    return _optimisticLikeCount ?? widget.video.likeCount;
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentBottomSheet(
        videoId: widget.video.id,
        onClose: () {
          Navigator.pop(context);
          widget.controller?.play();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70, // Fixed width for the action buttons column
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Like Button
          _ActionButton(
            icon: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: _isLiked ? Colors.red : Colors.white,
              size: 32,
            ),
            label: _likeCount.toString(),
            onTap: () async {
              final userId = _currentUserId;
              if (userId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please log in to like videos')),
                );
                return;
              }
              
              // Optimistically update UI including like count
              setState(() {
                _optimisticIsLiked = !_isLiked;
                _optimisticLikeCount = _likeCount + (_isLiked ? 1 : -1);
              });
              
              try {
                final isLiked = await _videoRepository.toggleLikeVideo(widget.video.id, userId);
                
                // Update local state with server response
                setState(() {
                  _optimisticIsLiked = isLiked;
                });
                
                // Show feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isLiked ? 'Video liked' : 'Like removed'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              } catch (e) {
                // Revert optimistic update on error
                setState(() {
                  _optimisticIsLiked = null;
                  _optimisticLikeCount = null;
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error liking video')),
                );
              }
            },
          ),
          // Save Button
          _ActionButton(
            icon: Icon(
              _isSaved ? Icons.bookmark : Icons.bookmark_outline,
              color: _isSaved ? Colors.blue : Colors.white,
              size: 32,
            ),
            label: _isSaved ? 'Saved' : 'Save',
            onTap: () async {
              final userId = _currentUserId;
              if (userId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please log in to save videos')),
                );
                return;
              }
              
              // Optimistically update UI
              setState(() {
                _optimisticIsSaved = !_isSaved;
              });
              
              try {
                final isSaved = await _videoRepository.toggleSaveVideo(widget.video.id, userId);
                
                // Update local state with server response
                setState(() {
                  _optimisticIsSaved = isSaved;
                });
                
                // Show feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isSaved ? 'Video saved' : 'Video unsaved'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              } catch (e) {
                // Revert optimistic update on error
                setState(() {
                  _optimisticIsSaved = null;
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error saving video')),
                );
              }
            },
          ),
          // Comment Button
          _ActionButton(
            icon: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.white,
              size: 24,
            ),
            label: 'Comments',
            onTap: () {
              // Pause the video when opening comments
              widget.controller?.pause();
              _showComments(context);
            },
          ),
          // Tutorial Button
          _ActionButton(
            icon: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30), // Makes the shadow area circular
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade200.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 12,
                  ),
                ],
              ),
              child: SvgPicture.asset(
                'assets/images/guitar-solid.svg',
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                height: 30,
                width: 30,
              ),
            ),
            label: 'Tutorial',
            onTap: () {
              // Pause the video if controller exists
              widget.controller?.pause();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TutorialScreen(
                    video: widget.video,
                    onClose: () {
                      // Resume video when returning from tutorial screen
                      widget.controller?.play();
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20), // Spacing from bottom
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: icon,
        ),
        const SizedBox(height: 15), // Increased from 12 to 15
      ],
    );
  }
} 