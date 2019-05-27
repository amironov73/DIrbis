## Пакет irbis

### Введение

Пакет `irbis` представляет собой простую библиотеку для создания клиентских приложений для системы автоматизации библиотек ИРБИС64 на языке D.

Пакет не содержит ссылок на внешний код и не требует irbis64_client.dll. Успешно работает на 64-битных версиях операционных систем Windows и Linux.

Основные возможности пакета:

* Поиск и расформатирование записей.
* Создание и модификация записей, сохранение записей в базе данных на сервере.
* Работа с поисковым словарем: просмотр терминов и постингов.
* Административные функции: получение списка пользователей, его модификация, передача списка на сервер, создание и удаление баз данных.

Поддерживается компилятор DMD, начиная с версии 2.082 и сервер ИРБИС64, начиная с 2014.

### Установка

DMD

### Примеры программ

Ниже прилагается пример простой программы. Сначала находятся и загружаются 10 первых библиографических записей, в которых автором является А. С. Пушкин. Показано нахождение значения поля с заданным тегом и подполя с заданным кодом. Также показано расформатирование записи в формат `brief`.

```d
import std.stdio;
import irbis;

void main() {
    // Подключаемся к серверу
    auto client = new Connection;
    client.host = "localhost";
    client.username = "librarian";
    client.password = "secret";

    if (!client.connect) {
        writeln("Не удалось подключиться!");
        return;
    }

    // По выходу из функции произойдет отключение от сервера
    scope(exit) client.disconnect;

    // Общие сведения о сервере
    writeln("Версия сервера=", client.serverVersion);
    writeln("Интервал=", client.interval);
    
    // Из INI-файла можно получить настройки клиента
    auto ini = client.ini;
    auto dbnnamecat = ini.getValue("Main", "DBNNAMECAT", "???");
    writeln("DBNNAMECAT=", dbnnamecat);
    
    // Получение списка баз данных с сервера
    auto databases = client.listDatabases;
    writeln("DATABASES=", databases);

    // Получение с сервера содержимого файла
    auto content = client.readTextFile("3.IBIS.WS.OPT");
    writeln(content);

    // Получение MNU-файла с сервера
    auto menu = client.readMenuFile("3.IBIS.FORMATW.MNU");
    writeln(menu);

    // Список файлов на сервере
    auto files = client.listFiles("3.IBIS.brief.*", "3.IBIS.a*.pft");
    writeln(files);

    // Находим записи с автором "Пушкин"
    auto found = client.search(`"A=Пушкин$"`);
    writeln("Найдено: ", found);

    foreach(mfn; found) {
        // Считываем запись с сервера
        auto record = client.readRecord(mfn);

        // Получаем значение поля/подполя
        auto title = record.fm(200, 'a');
        writeln("Заглавие: ", title);

        // Расформатируем запись на сервере
        auto description = client.formatRecord("@brief", mfn);
        writeln("Биб. описание: ", description);
    }    
}
```

В следующей программе создается и отправляется на сервер 10 записей. Показано добавление в запись полей с подполями.

```d
import std.stdio;
import irbis;

void main() {
    // Подключаемся к серверу
    auto client = new Connection;
    client.host = "localhost";
    client.username = "librarian";
    client.password = "secret";

    if (!client.connect) {
        writeln("Не удалось подключиться!");
        return;
    }

    // По выходу из функции произойдет отключение от сервера
    scope(exit) client.disconnect;

    // Записи будут помещаться в базу SANDBOX
    client.database = "SANDBOX";
    
    foreach (i; 1..11) {
        // Создаем запись в памяти клиента
        auto record = new MarcRecord;
        
        // Наполняем ее полями: первый автор (поле с подполями)
        record.add(700)
            .add('a', "Миронов")
            .add('b', "А. В.")
            .add('g', "Алексей Владимирович");
            
        // заглавие (поле с подполями)
        record.add(200)
            .add('a', "Работа с ИРБИС64")
            .add('e', "руководстко пользователя");
            
        // выходные данные (поле с подполями)
        record.add(210)
            .add('a', "Иркутск")
            .add('c', "ИРНИТУ")
            .add('d', "2019");
            
        // рабочий лист (поле без подполей)
        record.add(920, "PAZK");
        
        // Отсылаем запись на сервер.
        // Обратно приходит запись,
        // обработанная AUTOIN.GBL
        client.writeRecord(record);
        
        writeln(record);
    }
}
```

[Следующая глава](chapter2.md)
