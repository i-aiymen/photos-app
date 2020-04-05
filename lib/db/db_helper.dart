import 'dart:io';

import 'package:myapp/models/photo.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final _databaseName = "orma.db";
  static final _databaseVersion = 1;

  static final table = 'photos';

  static final columnLocalPath = 'local_path';
  static final columnThumbnailPath = 'thumbnail_path';
  static final columnUrl = 'url';
  static final columnHash = 'hash';
  static final columnSyncTimestamp = 'sync_timestamp';

  // make this a singleton class
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // only have a single app-wide reference to the database
  static Database _database;
  Future<Database> get database async {
    if (_database != null) return _database;
    // lazily instantiate the db the first time it is accessed
    _database = await _initDatabase();
    return _database;
  }

  // this opens the database (and creates it if it doesn't exist)
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(path,
        version: _databaseVersion, onCreate: _onCreate);
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $table (
            $columnLocalPath TEXT NOT NULL,
            $columnThumbnailPath TEXT NOT NULL,
            $columnUrl TEXT,
            $columnHash TEXT NOT NULL,
            $columnSyncTimestamp TEXT
          )
          ''');
  }

  Future<int> insertPhoto(Photo photo) async {
    Database db = await instance.database;
    return await db.insert(table, _getRowForPhoto(photo));
  }

  Future<List<dynamic>> insertPhotos(List<Photo> photos) async {
    Database db = await instance.database;
    var batch = db.batch();
    int batchCounter = 0;
    for (Photo photo in photos) {
      if (batchCounter == 400) {
        await batch.commit();
        batch = db.batch();
      }
      batch.insert(table, _getRowForPhoto(photo));
      batchCounter++;
    }
    return await batch.commit();
  }

  Future<List<Photo>> getAllPhotos() async {
    Database db = await instance.database;
    var results = await db.query(table);
    return _convertToPhotos(results);
  }

  Future<List<Photo>> getPhotosToBeUploaded() async {
    Database db = await instance.database;
    var results = await db.query(table, where: '$columnUrl IS NULL');
    return _convertToPhotos(results);
  }

  // We are assuming here that the hash column in the map is set. The other
  // column values will be used to update the row.
  Future<int> updateUrlAndTimestamp(
      String hash, String url, String timestamp) async {
    Database db = await instance.database;
    var row = new Map<String, dynamic>();
    row[columnUrl] = url;
    row[columnSyncTimestamp] = timestamp;
    return await db
        .update(table, row, where: '$columnHash = ?', whereArgs: [hash]);
  }

  Future<Photo> getPhotoByUrl(String url) async {
    Database db = await instance.database;
    var rows = await db.query(table, where: '$columnUrl =?', whereArgs: [url]);
    if (rows.length > 0) {
      return Photo.fromRow(rows[0]);
    } else {
      throw ("No cached photo");
    }
  }

  Future<bool> containsPhotoHash(String hash) async {
    Database db = await instance.database;
    return (await db.query(table, where: '$columnHash =?', whereArgs: [hash]))
            .length >
        0;
  }

  List<Photo> _convertToPhotos(List<Map<String, dynamic>> results) {
    var photos = List<Photo>();
    for (var result in results) {
      photos.add(Photo.fromRow(result));
    }
    return photos;
  }

  Map<String, dynamic> _getRowForPhoto(Photo photo) {
    var row = new Map<String, dynamic>();
    row[columnLocalPath] = photo.localPath;
    row[columnThumbnailPath] = photo.thumbnailPath;
    row[columnUrl] = photo.url;
    row[columnHash] = photo.hash;
    row[columnSyncTimestamp] = photo.syncTimestamp;
    return row;
  }
}
