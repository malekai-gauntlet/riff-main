import 'package:cloud_firestore/cloud_firestore.dart';
import 'tab_template.dart';
import '../video/video_model.dart';

/// Repository for managing tab storage and retrieval
class TabRepository {
  final FirebaseFirestore _firestore;
  
  TabRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;
  
  /// Collection reference for tabs
  CollectionReference get _tabsCollection => 
      _firestore.collection('ai_tabs');
  
  /// Gets a tab for a video
  Future<TabTemplate?> getTabForVideo(Video video) async {
    try {
      print('🎸 Fetching tab for video: ${video.id}');
      
      // Query for tab with matching video_id
      final querySnapshot = await _tabsCollection
          .where('video_id', isEqualTo: video.id)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        print('✅ Found existing tab');
        final doc = querySnapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        
        print('📄 Tab data: $data'); // Debug print to see what we're getting from Firestore
        
        return TabTemplate(
          tabVersion: TabVersion(
            version: '1.0',
            revision: data['revision'] as int? ?? 1,
          ),
          songInfo: SongInfo(
            title: data['title'] as String? ?? video.title,
            artist: data['artist'] as String? ?? video.artist ?? 'Unknown Artist',
            tuning: (data['content']['tuning'] as List<dynamic>?)?.cast<String>() ?? ['E', 'A', 'D', 'G', 'B', 'E'],
            difficulty: data['content']['difficulty'] as String? ?? 'intermediate',
          ),
          meta: TabMeta(
            tempo: data['content']['tempo'] as int? ?? 120,
            timeSignature: data['content']['timeSignature'] as String? ?? '4/4',
            key: data['content']['key'] as String? ?? 'C',
          ),
          content: TabContent(
            measures: _extractMeasures(data['content']),
          ),
        );
      }
      
      print('❌ No tab found for video: ${video.id}');
      return null;
      
    } catch (e, stackTrace) {
      print('❌ Error getting tab:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Helper method to extract measures from the nested array structure
  List<Measure> _extractMeasures(Map<String, dynamic> content) {
    try {
      print('📝 Extracting measures from content');
      final sections = content['sections'] as List<dynamic>;
      final firstSection = sections[0] as Map<String, dynamic>;
      final measures = firstSection['measures'] as List<dynamic>;
      final firstMeasure = measures[0] as Map<String, dynamic>;
      
      print('📝 First measure data: $firstMeasure');
      
      return [
        Measure(
          index: firstMeasure['index'] as int? ?? 0,
          timeSignature: firstMeasure['timeSignature'] as String? ?? '4/4',
          strings: _extractStrings(firstMeasure['strings'] as List<dynamic>),
        )
      ];
    } catch (e) {
      print('❌ Error extracting measures: $e');
      return [];
    }
  }

  /// Helper method to extract strings from the nested array structure
  List<TabString> _extractStrings(List<dynamic> strings) {
    try {
      print('📝 Extracting strings: $strings');
      final firstString = strings[0] as Map<String, dynamic>;
      final notes = firstString['notes'] as List<dynamic>;
      final firstNote = notes[0] as Map<String, dynamic>;
      
      print('📝 First note data: $firstNote');
      
      return [
        TabString(
          string: firstString['string'] as int? ?? 1,
          notes: [
            Note(
              fret: firstNote['fret'] as int? ?? 0,
              duration: (firstNote['duration'] as num?)?.toDouble() ?? 1.0,
              position: firstNote['position'] as int? ?? 0,
            )
          ],
        )
      ];
    } catch (e) {
      print('❌ Error extracting strings: $e');
      return [];
    }
  }
} 