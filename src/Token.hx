package;

class Token {
    public final type:TokenType;
    public final lexeme:String;
    public final literal:Any;
    public final line:Int;

    public function new(type:TokenType, lexeme:String, literal:Any, line:Int) {
        this.type = type;
        this.lexeme = lexeme;
        this.literal = literal;
        this.line = line;
    }

    public function toString() {
        return type + " " + lexeme + " " + literal;
    }
}