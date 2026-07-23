//                           LICENSE

//    Copyright (C) 2019, HUSEYIN TOKPUNAR http://huseyintokpinar.com/

//    Download & Update Latest Version: https://github.com/hhtokpinar/sqfEntity

//    Licensed under the Apache License, Version 2.0 (the 'License');
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at

//     http://www.apache.org/licenses/LICENSE-2.0

//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an 'AS IS' BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

import 'dart:async' show Future;

import 'package:flutter/services.dart';
import 'package:sqfentity/sqfentity_connection_base.dart';
// Expõe o setter/getter GLOBAL `databaseFactory` e o tipo `Database`.
import 'package:sqflite_common/sqflite.dart';
import 'package:synchronized/synchronized.dart';

/// Conexão para **Flutter Web**.
///
/// As outras duas implementações não funcionam no navegador:
///  - [SqfEntityConnectionMobile] usa o plugin `sqflite_sqlcipher` (sem web);
///  - [SqfEntityConnectionFfi] hardcoda `databaseFactoryFfi` (`dart:ffi`, sem web).
///
/// Esta usa o **`databaseFactory` global** do `sqflite_common`, que o app
/// configura no bootstrap para `databaseFactoryFfiWebNoWebWorker`
/// (sqlite3.wasm + IndexedDB). Assim o mesmo modelo/ORM funciona na web.
///
/// Diferenças intencionais em relação ao nativo:
///  - **Sem `dart:io`**: nada de `File`/`Platform` (quebram na web).
///  - **Sem SQLCipher**: o navegador não tem o `PRAGMA KEY`; o banco em
///    IndexedDB fica NÃO criptografado. Não persistir segredos na web.
///  - **Sem bundledDatabasePath**: copiar um .db de asset depende de I/O de
///    arquivo; se configurado, falha explicitamente em vez de silenciar.
class SqfEntityConnectionWeb extends SqfEntityConnectionBase {
  SqfEntityConnectionWeb(SqfEntityConnection? connection) : super(connection);

  @override
  Future<void> writeDatabase(ByteData data) async {
    // Requer acesso a arquivo (dart:io), indisponível na web.
    throw UnsupportedError(
        'writeDatabase (bundledDatabasePath) não é suportado no Flutter Web.');
  }

  @override
  Future<Database> openDb() async {
    final lock = Lock();
    Database? _db;
    await lock.synchronized(() async {
      if (connection!.bundledDatabasePath != null &&
          connection!.bundledDatabasePath != '' &&
          connection!.bundledDatabasePath != 'null') {
        throw UnsupportedError(
            'bundledDatabasePath não é suportado no Flutter Web '
            '(banco: ${connection!.databaseName}).');
      }

      // Na web o "path" é apenas o identificador do banco no IndexedDB — não
      // há diretório. Por isso NÃO usamos getFinalDatabasePath (que tocaria em
      // Platform.isWindows) nem `join` de path.
      final path = connection!.databaseName;

      _db = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: connection!.dbVersion,
          onCreate: createDb,
          // Sem onConfigure/PRAGMA KEY: SQLCipher não existe na web.
        ),
      );
    });
    return _db!;
  }

  /// Creates db if not exist
  @override
  void createDb(Database db, int version) async {
    await db.execute(
        'Create table sqfentitytables (id integer primary key, tablename text, version int, properties text)');
    await db.execute(
        'Create table sqfentitysequences (id text UNIQUE, value integer)');
    print(
        'Your database ${connection!.databaseName} v:$version created successfully');
  }
}
