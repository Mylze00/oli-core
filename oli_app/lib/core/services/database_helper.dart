import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('oli_chat.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      // Sur le web, on lève une erreur pour que le try/catch s'active
      // et que l'application utilise directement le réseau sans crasher avec les Workers WebAssembly manquants.
      throw UnsupportedError('SQLite offline mode is disabled on Web.');
    } else {
      // Configuration pour iOS / Android
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);

      return await openDatabase(path, version: 1, onCreate: _createDB);
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT';
    const integerType = 'INTEGER';

    // Table des conversations (Boîte de réception)
    await db.execute('''
CREATE TABLE conversations (
  id $idType,
  conversation_id $integerType,
  user_id $textType NOT NULL,
  other_user_id $textType NOT NULL,
  last_message_content $textType,
  last_message_time $textType,
  unread_count $integerType DEFAULT 0,
  is_pinned $integerType DEFAULT 0,
  raw_data $textType
)
''');

    // Table des messages
    await db.execute('''
CREATE TABLE messages (
  id $idType,
  message_id $textType UNIQUE,
  conversation_id $integerType,
  sender_id $textType,
  receiver_id $textType,
  content $textType,
  type $textType,
  status $textType,
  created_at $textType,
  raw_data $textType
)
''');

    // Déclencher la migration depuis SharedPreferences
    await _migrateFromSharedPreferences(db);
  }

  Future<void> _migrateFromSharedPreferences(Database db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('oli_cache_')).toList();
      
      for (final key in keys) {
        final jsonString = prefs.getString(key);
        if (jsonString == null) continue;
        
        try {
          final decoded = jsonDecode(jsonString);
          
          if (key.startsWith('oli_cache_inbox_cache_')) {
            // Migration des conversations
            final userId = key.replaceAll('oli_cache_inbox_cache_', '');
            final List<dynamic> conversations = jsonDecode(decoded); // Double decode due to setCache bug
            
            for (var conv in conversations) {
              await db.insert('conversations', {
                'conversation_id': conv['id'],
                'user_id': userId,
                'other_user_id': conv['other_user']?['id']?.toString() ?? '',
                'last_message_content': conv['last_message']?['content'] ?? '',
                'last_message_time': conv['last_message']?['created_at'] ?? '',
                'raw_data': jsonEncode(conv),
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          } 
          else if (key.startsWith('oli_cache_chat_messages_')) {
            // Migration des messages
            final Map<String, dynamic> data = decoded is String ? jsonDecode(decoded) : decoded;
            final messages = data['messages'] as List<dynamic>? ?? [];
            
            for (var msg in messages) {
              await db.insert('messages', {
                'message_id': msg['id']?.toString() ?? '',
                'conversation_id': msg['conversation_id'],
                'sender_id': msg['sender_id']?.toString() ?? '',
                'receiver_id': msg['receiver_id']?.toString() ?? '',
                'content': msg['content'] ?? '',
                'type': msg['type'] ?? 'text',
                'created_at': msg['created_at'] ?? '',
                'raw_data': jsonEncode(msg),
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur migration de la clé $key: $e');
        }
      }
      debugPrint('✅ Migration SQLite terminée.');
    } catch (e) {
      debugPrint('❌ Erreur générale lors de la migration SQLite: $e');
    }
  }
}
