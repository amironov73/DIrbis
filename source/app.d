import std.stdio;
import irbis;

void testEncodings()
{
	writeln(toAnsi("Hello"));
	writeln(fromAnsi([72, 101, 108, 108, 111]));
	writeln(toUtf("Hello"));
	writeln(fromUtf([72, 101, 108, 108, 111]));
	writeln(toAnsi("Привет!"));
	writeln(fromAnsi([207, 240, 232, 226, 229, 242, 33]));
	writeln(toUtf("Привет!"));
	writeln(fromUtf([208, 159, 209, 128, 208, 184, 208, 178, 208, 181, 209, 130, 33]));
}

void main()
{
	testEncodings();

	auto client = new Connection();
	client.username = "librarian";
	client.password = "secret";

	if (!client.connect())
	{
		writeln("Can't connect!");
		return;
	}

	int maxMfn = client.getMaxMfn("IBIS");
	writeln("Max MFN=", maxMfn);

	client.noOp();

	client.disconnect();
}
