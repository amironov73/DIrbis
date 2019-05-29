### Класс Connection

Класс `Connection` - "рабочая лошадка". Он осуществляет связь с сервером и всю необходимую перепаковку данных из клиентского представления в сетевое.

Экземпляр клиента создается, как правило, конструктором:

```d
auto client = new Connection;
```

Также имеется конструктор, подключающийся к серверу:

```d
auto client = new Connection("host=myhost;login=librarian;password=secret");
if (!client.connected) {
    // Что-то пошло не так
}
```

При создании клиента можно указать (некоторые) настройки:

```d
auto client = new Connection;
client.host = "irbis.rsl.ru";
client.port = 5555; // нестандартный порт!
client.username = "ninja";
client.password = "i_am_invisible";
```

Поле|Тип|Назначение|Значение по умолчанию
----|---|----------|---------------------
host        |string  | Адрес сервера|"127.0.0.1"
port        |ushort  | Порт|6666
username    |string  | Имя (логин) пользователя|пустая строка
password    |string  | Пароль пользователя|пустая строка
database    |string  | Имя базы данных|"IBIS"
workstation |string  | Тип АРМа (см. таблицу ниже)| "C"

Типы АРМов

Обозначение|Тип
-----------|---
"R" | Читатель
"C" | Каталогизатор
"M" | Комплектатор
"B" | Книговыдача
"K" | Книгообеспеченность
"A" | Администратор

Можно использовать мнемонические константы:

```d
const ADMINISTRATOR = "A" // Адмнистратор
const CATALOGER     = "C" // Каталогизатор
const ACQUSITIONS   = "M" // Комплектатор
const READER        = "R" // Читатель
const CIRCULATION   = "B" // Книговыдача
const BOOKLAND      = "B" // Книговыдача
const PROVISITON    = "K" // Книгообеспеченность
```

Обратите внимание, что адрес сервера задается строкой, так что может принимать как значения вроде `192.168.1.1`, так и `irbis.yourlib.com`.

Если какой-либо из вышеперечисленных параметров не задан явно, используется значение по умолчанию.

#### Подключение к серверу и отключение от него

Клиент, созданный конструктором по умолчанию, еще не подключен к серверу. Подключаться необходимо явно с помощью метода `connect`, при этом можно указать параметры подключения:

```d
auto client = new Connection;
client.host = "myhost.com";
if !client.connect {
    writeln("Ошибка при подключении!");
}
```

Отключаться от сервера необходимо с помощью метода `disconnect`, желательно помещать вызов в блок scope(exit) сразу после подключения (чтобы не забыть):

```d
client.connect;
scope(exit) client.disconnect;
```

При подключении клиент получает с сервера INI-файл с настройками, которые могут понадобиться в процессе работы:

```d
client.connect;
scope(exit) client.disconnect;
// Получаем имя MNU-файла, хранящего перечень форматов
auto formatMenuName = client.ini.getValue("Main", "FmtMnu", "FMT31.MNU");
```

Полученный с сервера INI-файл хранится в поле `ini`.

Повторная попытка подключения с помощью того же экземпляра `Connection` игнорируется. При необходимости можно создать другой экземпляр и подключиться с его помощью (если позволяют клиентские лицензии). Аналогично игнорируются повторные попытки отключения от сервера.

Проверить статус "клиент подключен или нет" можно с помощью метода `connected`:

```d
if !client.connected {
    // В настоящее время мы не подключены к серверу
}
```

Вместо индивидуального задания каждого из полей `host`, `port`, `username`, `password` и `database`, можно использовать метод `parseConnectionString`:

```d
client.parseConnectionString("host=192.168.1.4;port=5555;" ~
         "username=itsme;password=secret;");
client.connect;
```

#### Многопоточность

Клиент написан в наивном однопоточном стиле, поэтому не поддерживает одновременный вызов методов из разных потоков.

Для одновременной отсылки на сервер нескольких команд необходимо создать соответствующее количество экземпляров подключений (если подобное позволяет лицензия сервера).

#### Подтверждение подключения

`Connection` самостоятельно не посылает на сервер подтверждений того, что клиент все еще подключен. Этим должно заниматься приложение, например, по таймеру.

Подтверждение посылается серверу методом `noOp`:

```d
client.noOp;
```

#### Чтение записей с сервера

```d
auto mfn = 123;
auto record = client.readRecord(mfn);
```

Можно прочитать несколько записей сразу:

```d
auto mfns = {12, 34, 56};
auto records := client.readRecords(mfns);
```

Можно прочитать определенную версию записи

```d
auto mfn = 123;
auto version = 3;
record := client.readRecord(mfn, version);
```

#### Сохранение записи на сервере

```d
// Любым образом создаём в памяти клиента
// или получаем с сервера запись.
auto record = client.readRecord(123);

// Производим какие-то манипуляции над записью
record.add(999, "123");

// Отсылаем запись на сервер
auto newMaxMfn = client.writeRecord(record);
writeln("New Max MFN=", newMaxMfn);
```

Сохранение нескольких записей (возможно, из разных баз данных):

```d
MarcRecord[10] records;
// каким-либо образом заполняем массив
...
if !client.WriteRecords(records) {
    log.Fatal("Failure!")
}
```

#### Удаление записи на сервере

```d
auto mfn = 123;
client.deleteRecord(mfn);
```

Восстановление записи:

```d
auto mfn = 123;
auto record = client.undeleteRecord(mfn);
```

#### Поиск записей

```d
auto found = client.search(`"A=ПУШКИН$"`);
writeln("Найдено записей: ", found.length);
```

Обратите внимание, что поисковый запрос заключен в дополнительные кавычки. Эти кавычки явлются элементом синтаксиса поисковых запросов ИРБИС64, и лучше их не опускать.

Вышеприведённый запрос вернёт не более 32 тыс. найденных записей. Сервер ИРБИС64 за одно обращение к нему может выдать не более 32 тыс. записей. Чтобы получить все записи, используйте метод `searchAll` (см. ниже), он выполнит столько обращений к серверу, сколько нужно.

Поиск с одновременной загрузкой записей:

```d
auto records = client.searchRead(`"A=ПУШКИН$"`, 50);
writeln("Найдено записей: ", records.length);
```

Поиск и загрузка единственной записи:

```d
auto record = client.searchSingleRecord(`"I=65.304.13-772296"`);
if (record is null) {
    writeln("Не нашли!");
}
```

Количество записей, соответствующих поисковому выражению:

```d
auto expression = `"A=ПУШКИН$"`;
auto count = client.searchCount(expression);
```

Расширенный поиск: можно задать не только количество возвращаемых записей, но и расформатировать их.

```d
SearchParameters parameters;
parameters.expression = `"A=ПУШКИН$"`;
parameters.format = BRIEF_FORMAT;
parameters.numberOfRecords = 5;
auto found = client.search(parameters);
if (found.empty) {
    writeln("Не нашли");
} else {
    // в found находится слайс структур FoundLine
    auto first = found[0];
    writeln("MFN=", first.mfn, "DESCRIPTION: ", first.description);
}
```

Поиск всех записей (даже если их окажется больше 32 тыс.):

```d
auto found = client.searchAll(`"A=ПУШКИН$"`);
writeln("Найдено записей=", count.length);
```

Подобные запросы следует использовать с осторожностью, т. к. они, во-первых, создают повышенную нагрузку на сервер, и во-вторых, потребляют очень много памяти на клиенте. Некоторые запросы (например, "I=$") могут вернуть все записи в базе данных, а их там может быть десятки миллионов.

#### Форматирование записей

```d
auto mfn = 123;
auto format = BRIEF_FORMAT;
auto text = client.formatRecord(format, mfn);
writeln("Результат форматирования: ", text);
```

При необходимости можно использовать в формате все символы UNICODE:

```d
auto mfn = 123;
auto format = "'Ἀριστοτέλης: ', v200^a";
auto text = client.formatRecord(format, mfn);
writeln("Результат форматирования: ", text);
```

Форматирование нескольких записей:

```d
auto mfns = {12, 34, 56};
auto format = BRIEF_FORMAT;
auto lines = client.formatRecords(format, mfns);
writeln("Результаты: ", lines);
```

#### Печать таблиц

```d
TableDefinition table;
table.database = "IBIS";
table.table = "@tabf1w";
table.searchQuery = `"T=A$"`;
auto text = client.printTable(table);
```

#### Работа с контекстом

Метод | Назначение
--------|-----------
listFiles | Получение списка файлов на сервере
readIniFile | Получение INI-файла с сервера
readMenuFile | Получение MNU-файла с сервера
readSearchScenario | Загрузка сценариев поиска с сервера
readTextFile | Получение текстового файла с сервера
readTextLines | Получение текстового файла в виде массива строк
readTreeFile | Получение TRE-файла с сервера
updateIniFile | Обновление строк серверного INI-файла
writeTextFile | Сохранение текстового файла на сервере

#### Работа с мастер-файлом

Метод | Назначение
--------|-----------
readRawRecord | Чтение указанной записи в "сыром" виде
writeRawRecord | Сохранение на сервере "сырой" записи

#### Работа со словарем

Метод | Назначение
--------|-----------
listTerms | Получение списка терминов с указанным префиксом
readPostings | Чтение постингов поискового словаря
readTerms | Чтение терминов поискового словаря
readTermsEx | Расширенное чтение терминов

#### Информационные функции

Метод | Назначение
--------|-----------
getDatabaseInfo | Получение информации о базе данных
getMaxMfn | Получение максимального MFN для указанной базы данных
getServerVersion | Получение версии сервера
listDatabases | Получение списка баз данных с сервера
toConnectionString | Получение строки подключения

#### Администраторские функции

Нижеперечисленные записи доступны лишь из АРМ "Администратор", поэтому подключаться к серверу необходимо так:

```d
auto client = new Connection();
client.username = "librarian";
client.password = "secret";
client.workstation = ADMINISTRATOR;
if !client.connect {
    writeln("Не удалось подключиться!");
}
```

Метод | Назначение
--------|-----------
actualizeDatabase | Актуализация базы данных
actualizeRecord | Актуализация записи
createDatabase | Создание базы данных
createDictionary | Создание словаря
deleteDatabase | Удаление базы данных
deleteFile | Удаление файла на сервере
getServerStat | Получение статистики с сервера
getUserList | Получение списка пользователей с сервера
listProcesses | Получение списка серверных процессов
reloadDictionary | Пересоздание словаря
reloadMasterFile | Пересоздание мастер-файла
restartServer | Перезапуск сервера
truncateDatabase | Опустошение базы данных
unlockDatabase | Разблокирование базы данных
unlockRecords | Разблокирование записей
updateUserList | Обновление списка пользователей на сервере

#### Глобальная корректировка

```d
GblSettings settings;
settings.database = "IBIS";
settings.mfnList = [1, 2, 3];
settings.statements = [...];
auto result = connection.globalCorrection(settings);
foreach (line; result) {
    writeln(line);
}
```

#### Расширение функциональности

**ExecuteAnyCommand(string $command, array $params)** -- выполнение произвольной команды с параметрами в кодировке ANSI.


[Предыдущая глава](chapter1.md) [Следующая глава](chapter3.md)


