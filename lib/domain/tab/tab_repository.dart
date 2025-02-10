import 'package:cloud_firestore/cloud_firestore.dart';
import 'tab_template.dart';
import 'tab_ai_generator.dart';
import '../video/video_model.dart';

/// Repository for managing tab storage and retrieval
class TabRepository {
  final FirebaseFirestore _firestore;
  
  TabRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;
  
  /// Collection reference for tabs
  CollectionReference get _tabsCollection => 
      _firestore.collection('tabs');
  
  /// Gets or generates a tab for a video
  Future<TabTemplate> getTabForVideo(Video video) async {
    try {
      // Check if tab already exists
      final docRef = _tabsCollection.doc(video.id);
      final doc = await docRef.get();
      
      if (doc.exists) {
        // Return existing tab
        return TabTemplate.fromJson(doc.data() as Map<String, dynamic>);
      }
      
      // Generate new tab
      print('🎸 Generating new tab for video: ${video.id}');
      final tab = await TabAiGenerator.generateTabFromVideo(video);
      
      // Save the generated tab
      await docRef.set(tab.toJson());
      
      return tab;
    } catch (e) {
      print('❌ Error getting/generating tab: $e');
      rethrow;
    }
  }
  
  /// Saves a tab to Firestore
  Future<void> saveTab(String videoId, TabTemplate tab) async {
    try {
      await _tabsCollection.doc(videoId).set(tab.toJson());
    } catch (e) {
      print('❌ Error saving tab: $e');
      rethrow;
    }
  }
  
  /// Gets all tabs for a user
  Future<List<TabTemplate>> getTabsForUser(String userId) async {
    try {
      final querySnapshot = await _tabsCollection
          .where('userId', isEqualTo: userId)
          .get();
      
      return querySnapshot.docs
          .map((doc) => TabTemplate.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error getting user tabs: $e');
      rethrow;
    }
  }
} 