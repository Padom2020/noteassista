import 'package:flutter_test/flutter_test.dart';
import 'package:noteassista/widgets/create_folder_dialog.dart';
import 'package:noteassista/widgets/rename_folder_dialog.dart';
import 'package:noteassista/widgets/move_folder_dialog.dart';
import 'package:noteassista/widgets/folder_tree_view.dart';
import 'package:noteassista/models/folder_model.dart';

void main() {
  test('Folder management widgets can be imported', () {
    // This test verifies that all folder management widgets are properly defined
    // and can be imported without errors

    expect(CreateFolderDialog, isNotNull);
    expect(RenameFolderDialog, isNotNull);
    expect(MoveFolderDialog, isNotNull);
    expect(FolderTreeView, isNotNull);
    expect(FolderModel, isNotNull);
  });

  test('FolderModel has all required fields', () {
    final folder = FolderModel(
      id: 'test',
      name: 'Test Folder',
      color: '#2196F3',
    );

    expect(folder.id, 'test');
    expect(folder.name, 'Test Folder');
    expect(folder.color, '#2196F3');
    expect(folder.noteCount, 0);
    expect(folder.isFavorite, false);
    expect(folder.parentId, null);
  });
}
