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
