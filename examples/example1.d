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
