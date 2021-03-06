import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/api/store_ref.dart';
import 'package:sembast/src/api/v2/sembast.dart' as v2;
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/record_snapshot_impl.dart';
import 'package:sembast/src/utils.dart';

mixin RecordRefMixin<K, V> implements RecordRef<K, V> {
  @override
  StoreRef<K, V> store;
  @override
  K key;

  @override
  RecordSnapshot<K, V> snapshot(V value) => SembastRecordSnapshot(this, value);

  /// Update record
  ///
  /// value is sanitized first
  @override
  Future<V> update(DatabaseClient databaseClient, V value) async {
    var client = getClient(databaseClient);
    value = sanitizeInputValue<V>(value);
    return await client.inTransaction((txn) {
      return client.getSembastStore(store).txnUpdate(txn, value, key);
    }) as V;
  }

  /// Put record
  ///
  /// value is sanitized first
  @override
  Future<V> put(DatabaseClient databaseClient, V value, {bool merge}) async {
    var client = getClient(databaseClient);
    value = sanitizeInputValue<V>(value);
    return await client.inTransaction((txn) {
      return client
          .getSembastStore(store)
          .txnPut(txn, value, key, merge: merge);
    }) as V;
  }

  /// Add a record
  ///
  /// value is sanitized first
  @override
  Future<K> add(DatabaseClient databaseClient, V value) async {
    var client = getClient(databaseClient);
    value = sanitizeInputValue<V>(value);
    return await client.inTransaction((txn) {
      return client.getSembastStore(store).txnAdd(txn, value, key);
    });
  }

  /// Delete record
  @override
  Future delete(DatabaseClient databaseClient) {
    var client = getClient(databaseClient);
    return client.inTransaction((txn) {
      return client.getSembastStore(store).txnDelete(txn, key);
    });
  }

  /// Get record value
  @override
  Future<V> get(DatabaseClient databaseClient) async =>
      (await getSnapshot(databaseClient))?.value;

  /// Get record
  @override
  Future<RecordSnapshot<K, V>> getSnapshot(
      DatabaseClient databaseClient) async {
    var client = getClient(databaseClient);

    var record = await client
        .getSembastStore(store)
        .txnGetRecord(client.sembastTransaction, key);
    return record?.cast<K, V>();
  }

  ///
  /// Stream of record snapshot
  ///
  @override
  Stream<RecordSnapshot<K, V>> onSnapshot(v2.Database database) {
    var db = getDatabase(database);
    var ctlr = db.listener.addRecord(this);

    var completer = Completer<RecordSnapshot<K, V>>();
    // Add the existing snapshot
    db.notificationLock.synchronized(() async {
      var snapshot = await completer.future;
      ctlr.add(snapshot);
    });

    // Read right away
    () async {
      // Don't crash here, the database might have been closed
      try {
        var snapshot = await getSnapshot(database);
        completer.complete(snapshot);
      } catch (error, stackTrace) {
        completer.completeError(error);
        ctlr.addError(error, stackTrace);
      }
    }();
    return ctlr.stream;
  }

  @override
  Future<bool> exists(DatabaseClient databaseClient) {
    var client = getClient(databaseClient);
    return client
        .getSembastStore(store)
        .txnRecordExists(client.sembastTransaction, key);
  }

  @override
  String toString() => 'Record(${store?.name}, $key)';

  /// Cast if needed
  @override
  RecordRef<RK, RV> cast<RK, RV>() {
    if (this is RecordRef<RK, RV>) {
      return this as RecordRef<RK, RV>;
    }
    return store.cast<RK, RV>().record(key as RK);
  }

  @override
  int get hashCode => key.hashCode;

  @override
  bool operator ==(other) {
    if (other is RecordRef) {
      return other.store == store && other.key == key;
    }
    return false;
  }
}

/// Record ref implementation.
class SembastRecordRef<K, V> with RecordRefMixin<K, V> {
  /// Record ref implementation.
  SembastRecordRef(StoreRef<K, V> store, K key) {
    this.store = store;
    this.key = key;
  }
}
