import 'tab_template.dart';

/// Renders a tab template in Ultimate Guitar visual format
class TabRenderer {
  /// Converts a tab template to visual string format
  static String renderTab(TabTemplate template) {
    print('\n🎸🎸🎸 STARTING TAB RENDER 🎸🎸🎸');
    print('Title: ${template.songInfo.title}');
    print('Content: ${template.content}');
    
    final buffer = StringBuffer();
    
    // Add title and metadata
    buffer.writeln('[${template.songInfo.title} - ${template.songInfo.artist}]');
    buffer.writeln();
    
    // Add tuning if non-standard
    if (!_isStandardTuning(template.songInfo.tuning)) {
      buffer.writeln('Tuning: ${template.songInfo.tuning.join(' ')}');
      buffer.writeln();
    }

    // Process each measure
    var currentSection = '';
    for (var i = 0; i < template.content.measures.length; i++) {
      final measure = template.content.measures[i];
      
      // Add section header if needed
      final section = _getSectionForMeasure(i);
      if (section != currentSection) {
        currentSection = section;
        buffer.writeln('[$section]');
        buffer.writeln();
      }
      
      // Convert measure to visual format
      final visualMeasure = _renderMeasure(measure);
      buffer.write(visualMeasure);
      
      // Add line breaks between groups of measures
      if ((i + 1) % 2 == 0) buffer.writeln();
    }
    
    return buffer.toString();
  }

  /// Renders a single measure in visual format
  static String _renderMeasure(Measure measure) {
    print('\n🎸 Rendering measure:');
    print('📊 Measure data: $measure');
    
    final stringBuffers = {
      1: StringBuffer('e|'),
      2: StringBuffer('B|'),
      3: StringBuffer('G|'),
      4: StringBuffer('D|'),
      5: StringBuffer('A|'),
      6: StringBuffer('E|'),
    };
    
    // Initialize with dashes
    final measureWidth = _calculateMeasureWidth(measure);
    print('📏 Measure width: $measureWidth');
    
    for (var string = 1; string <= 6; string++) {
      stringBuffers[string]!.write('-' * measureWidth);
    }
    
    // Place notes in correct positions
    for (var tabString in measure.strings) {
      print('🎵 Processing string ${tabString.string}:');
      final buffer = stringBuffers[tabString.string]!;
      for (var note in tabString.notes) {
        final position = _calculateVisualPosition(note.position, measureWidth);
        print('  - Note: fret ${note.fret} at position $position');
        _placeNote(buffer, note.fret, position);
        print('  - Buffer after placing note: ${buffer.toString()}');
      }
    }
    
    // Add measure ending bar
    for (var string = 1; string <= 6; string++) {
      stringBuffers[string]!.write('|');
    }
    
    // Combine all strings
    final result = StringBuffer();
    for (var string = 1; string <= 6; string++) {
      result.writeln(stringBuffers[string]!.toString());
    }
    
    print('📝 Final rendered measure:');
    print(result.toString());
    return result.toString();
  }

  /// Places a note in the string buffer at the correct position
  static void _placeNote(StringBuffer buffer, int fret, int position) {
    final fretStr = fret.toString();
    print('  - Placing note $fretStr at position $position');
    print('  - Buffer before: ${buffer.toString()}');
    
    // Get current content
    final content = buffer.toString();
    
    // Clear the buffer
    buffer.clear();
    
    // Write the updated content
    final newContent = content.replaceRange(
      position,
      position + 1, // Replace just one character
      fretStr,
    );
    buffer.write(newContent);
    
    print('  - Buffer after: ${buffer.toString()}');
  }

  /// Calculates the visual position for a note
  static int _calculateVisualPosition(int position, int measureWidth) {
    // Add 1 to account for the | at the start
    return position + 1;
  }

  /// Calculates the width needed for a measure
  static int _calculateMeasureWidth(Measure measure) {
    // Find the rightmost note position
    var maxPosition = 0;
    for (var string in measure.strings) {
      for (var note in string.notes) {
        maxPosition = maxPosition > note.position ? maxPosition : note.position;
      }
    }
    
    // Add some padding and account for measure bars
    return maxPosition + 4;
  }

  /// Determines section name based on measure index
  static String _getSectionForMeasure(int measureIndex) {
    if (measureIndex == 0) return 'Intro';
    return 'Section ${(measureIndex ~/ 4) + 1}';
  }

  /// Checks if tuning is standard EADGBE
  static bool _isStandardTuning(List<String> tuning) {
    const standardTuning = ['E', 'A', 'D', 'G', 'B', 'E'];
    if (tuning.length != standardTuning.length) return false;
    for (var i = 0; i < tuning.length; i++) {
      if (tuning[i] != standardTuning[i]) return false;
    }
    return true;
  }
}

/// Extension methods for tab template
extension TabTemplateVisual on TabTemplate {
  /// Converts this tab template to visual format
  String toVisualTab() {
    return TabRenderer.renderTab(this);
  }
} 