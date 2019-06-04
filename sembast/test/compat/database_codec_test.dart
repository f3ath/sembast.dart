library sembast.database_codec_test;

import 'dart:async';
import 'dart:convert';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/sembast_fs.dart';

import '../encrypt_codec.dart';
import 'database_format_test.dart' as database_format_test;
import 'test_codecs.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryFileSystemContext);
}

void defineTests(FileSystemTestContext ctx) {
  FileSystem fs = ctx.fs;
  DatabaseFactory factory = DatabaseFactoryFs(fs);
  String getDbPath() => ctx.outPath + ".db";
  String dbPath;

  Future<String> prepareForDb() async {
    dbPath = getDbPath();
    await factory.deleteDatabase(dbPath);
    return dbPath;
  }

  Future<Database> _prepareOneRecordDatabase({SembastCodec codec}) async {
    await prepareForDb();
    var db = await factory.openDatabase(dbPath, codec: codec);
    await db.put('test');
    return db;
  }

  void _commonTests(SembastCodec codec) {
    test('open_a_non_codec_database', () async {
      // Create a non codec database
      var db = await _prepareOneRecordDatabase();
      await db.close();

      // Try to open it using the codec
      try {
        db = await factory.openDatabase(dbPath, codec: codec);
        fail('should fail');
      } on DatabaseException catch (e) {
        expect(e.code, DatabaseException.errInvalidCodec);
      }
    });

    test('open_a_codec database', () async {
      // Create a codec encrypted database
      var db = await _prepareOneRecordDatabase(codec: codec);
      await db.close();

      // Try to open it without the codec
      try {
        db = await factory.openDatabase(dbPath);
        fail('should fail');
      } on DatabaseException catch (e) {
        expect(e.code, DatabaseException.errInvalidCodec);
      }
    });
  }

  group('codec', () {
    group('json_codec', () {
      var codec = SembastCodec(signature: 'json', codec: MyJsonCodec());
      var codecAlt = SembastCodec(signature: 'json_alt', codec: MyJsonCodec());
      database_format_test.defineTests(ctx, codec: codec);
      _commonTests(codec);

      test('one_record', () async {
        var db = await _prepareOneRecordDatabase(codec: codec);
        await db.close();
        List<String> lines = await readContent(fs, dbPath);
        expect(lines.length, 2);
        var metaMap = json.decode(lines.first) as Map;
        expect(metaMap,
            {"version": 1, "sembast": 1, 'codec': '{"signature":"json"}'});
        expect(json.decode(lines[1]), {'key': 1, 'value': 'test'});
      });

      test('wrong_signature', () async {
        var db = await _prepareOneRecordDatabase(codec: codec);
        await db.close();
        try {
          await factory.openDatabase(dbPath, codec: codecAlt);
          fail('should fail');
        } on DatabaseException catch (e) {
          expect(e.code, DatabaseException.errInvalidCodec);
        }
      });
    });

    group('base64_random_codec', () {
      var codec = SembastCodec(
          signature: 'base64_random', codec: MyCustomRandomCodec());
      database_format_test.defineTests(ctx, codec: codec);
      _commonTests(codec);
    });

    group('base64_codec', () {
      var codec = SembastCodec(signature: 'base64', codec: MyCustomCodec());
      database_format_test.defineTests(ctx, codec: codec);
      _commonTests(codec);

      test('one_record', () async {
        var db = await _prepareOneRecordDatabase(codec: codec);
        await db.close();
        List<String> lines = await readContent(fs, dbPath);
        expect(lines.length, 2);
        expect(json.decode(lines.first), {
          "version": 1,
          "sembast": 1,
          "codec": 'eyJzaWduYXR1cmUiOiJiYXNlNjQifQ=='
        });
        expect(json.decode(utf8.decode(base64.decode(lines[1]))),
            {'key': 1, 'value': 'test'});

        // reopen
      });

      test('reopen_and_compact', () async {
        var db = await _prepareOneRecordDatabase(codec: codec);
        await db.close();

        db = await factory.openDatabase(dbPath, codec: codec);
        expect(await db.get(1), 'test');

        await (db as SembastDatabase).compact();

        List<String> lines = await readContent(fs, dbPath);
        expect(lines.length, 2);
        expect(json.decode(lines.first), {
          "version": 1,
          "sembast": 1,
          'codec': 'eyJzaWduYXR1cmUiOiJiYXNlNjQifQ=='
        });
        expect(json.decode(utf8.decode(base64.decode(lines[1]))),
            {'key': 1, 'value': 'test'});

        await db.close();
      });
    });

    group('encrypt_codec', () {
      var codec = getEncryptSembastCodec(password: 'user_password');
      database_format_test.defineTests(ctx, codec: codec);
      _commonTests(codec);

      test('read existing', () async {
        dbPath = getDbPath();
        await writeContent(fs, dbPath, [
          '{"version":1,"sembast":1,"codec":"Lmsi2D1AhIU=8/Y32H5ykIQBkoIeI38Hwz9F4v5ONPc="}',
          'oxByFZ3B284=frnBGGbUlyg5s+4jFv90v7wjmdpZTvj8'
        ]);
        var db = await factory.openDatabase(dbPath, codec: codec);
        expect(await db.get(1), 'test');
        await db.close();
      });
      test('one_record', () async {
        var db = await _prepareOneRecordDatabase(codec: codec);
        await db.close();
        List<String> lines = await readContent(fs, dbPath);
        print(lines);
        expect(lines.length, 2);
        expect(codec.codec.decode(json.decode(lines.first)['codec'] as String),
            {'signature': 'encrypt'});
        expect(codec.codec.decode(lines[1]), {'key': 1, 'value': 'test'});
      });

      test('reopen_and_compact', () async {
        var db = await _prepareOneRecordDatabase(codec: codec);
        await db.close();

        db = await factory.openDatabase(dbPath, codec: codec);
        expect(await db.get(1), 'test');

        await (db as SembastDatabase).compact();

        List<String> lines = await readContent(fs, dbPath);
        expect(lines.length, 2);
        expect((json.decode(lines.first) as Map)..remove('codec'), {
          "version": 1,
          "sembast": 1,
        });
        expect(codec.codec.decode(json.decode(lines.first)['codec'] as String),
            {'signature': 'encrypt'});

        expect(codec.codec.decode(lines[1]), {'key': 1, 'value': 'test'});

        await db.close();
      });

      test('open with wrong password', () async {
        var db = await _prepareOneRecordDatabase(codec: codec);
        await db.close();

        try {
          var codecWithABadPassword =
              getEncryptSembastCodec(password: "bad_password");
          // Open again with a bad password
          db = await factory.openDatabase(dbPath, codec: codecWithABadPassword);

          fail('should fail');
        } on DatabaseException catch (e) {
          expect(e.code, DatabaseException.errInvalidCodec);
        }

        // Open again with the proper password
        db = await factory.openDatabase(dbPath, codec: codec);
        expect(await db.get(1), 'test');
        await db.close();
      });
    });

    test('invalid_codec', () async {
      try {
        await _prepareOneRecordDatabase(
            codec: SembastCodec(signature: 'test', codec: null));
        fail('should fail');
      } on DatabaseException catch (e) {
        expect(e.code, DatabaseException.errInvalidCodec);
      }
      try {
        await _prepareOneRecordDatabase(
            codec: SembastCodec(signature: null, codec: MyJsonCodec()));
        fail('should fail');
      } on DatabaseException catch (e) {
        expect(e.code, DatabaseException.errInvalidCodec);
      }
    });
  });
}
