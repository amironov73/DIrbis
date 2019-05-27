import std.stdio;
import irbis;

void main() {
    // ������������ � �������
    auto client = new Connection;
    client.host = "localhost";
    client.username = "librarian";
    client.password = "secret";

    if (!client.connect) {
        writeln("�� ������� ������������!");
        return;
    }

    // �� ������ �� ������� ���������� ���������� �� �������
    scope(exit) client.disconnect;

    // ������ ����� ���������� � ���� SANDBOX
    client.database = "SANDBOX";
    
    foreach (i; 1..11) {
        // ������� ������ � ������ �������
        auto record = new MarcRecord;
        
        // ��������� �� ������: ������ ����� (���� � ���������)
        record.add(700)
            .add('a', "�������")
            .add('b', "�. �.")
            .add('g', "������� ������������");
            
        // �������� (���� � ���������)
        record.add(200)
            .add('a', "������ � �����64")
            .add('e', "����������� ������������");
            
        // �������� ������ (���� � ���������)
        record.add(210)
            .add('a', "�������")
            .add('c', "������")
            .add('d', "2019");
            
        // ������� ���� (���� ��� ��������)
        record.add(920, "PAZK");
        
        // �������� ������ �� ������.
        // ������� �������� ������,
        // ������������ AUTOIN.GBL
        client.writeRecord(record);
        
        writeln(record);
    }
}
