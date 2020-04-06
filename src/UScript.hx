import sys.io.File;
import Scanner;

class UScript {

	static final interpreter = new Interpreter();

	static var hadError = false;
	static var hadRuntimeError = false;
	static var shouldWarn = true;

	static function main() {
		switch Sys.args(){
			case []:
				runPrompt();
			case [path]:
				runFile(path);
			case _:
				Sys.println("Usage: UScript [script]");
				Sys.exit(64);
		}
	}

	static function runFile(path: String) {
		var content = File.getContent(path);
		run(content);
		if(hadError) Sys.exit(65);
		if(hadRuntimeError) Sys.exit(70);
	}

	static function runPrompt() {
		var stdin = Sys.stdin();
		shouldWarn = false;
		Sys.println("~~~~UScript REPL~~~~~");
		while(true) {
			Sys.print('> ');
			run(stdin.readLine());
			hadError = false;
		}
	}

	static function run(source:String) {
		var scanner = new Scanner(source);
		var tokens = scanner.scanTokens();
		var parser = new Parser(tokens);
		var statements = parser.parse();
		if(hadError) return;
		var resolver = new Resolver(interpreter);
		resolver.resolve(statements);
		if(hadError) return;
		interpreter.interpret(statements);
	}

	public static function error(data:ErrorData, message:String) {
		switch data {
			case Line(line):
				Sys.println("Error at [line " + line + "] Error" + "" + ": " + message);
			case Token(token) if(token.type ==  Eof):
				Sys.println("Error at end [EOF]" + ": " + message);
			case Token(token):
				Sys.println("Error at [line " + token.line + "]" + ', ${token.lexeme}' + ": " + message);
		}
		hadError = true;
	}

	public static function warn(data:ErrorData, message:String) {
		if(shouldWarn == false) return;
		switch data {
			case Line(line):
				Sys.println("Warning at [line " + line + "]" + "" + ": " + message);
			case Token(token) if(token.type ==  Eof):
				Sys.println("Warning at end [EOF]" + ": " + message);
			case Token(token):
				Sys.println("Warning at [line " + token.line + "]" + ', ${token.lexeme}' + ": " + message);
		}
	}

	public static function runtimeError(e:RuntimeError) {
		Sys.println('${e.message}\n[line ${e.token.line}]');
		hadRuntimeError = true;
	}

}

enum ErrorDataType {
	Line(v:Int);
	Token(v:Token);
}

abstract ErrorData(ErrorDataType) from ErrorDataType to ErrorDataType {
	@:from static inline function line(v:Int):ErrorData return Line(v);
	@:from static inline function token(v:Token):ErrorData return Token(v);
}
