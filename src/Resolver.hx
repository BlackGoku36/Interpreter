package;

class Resolver {
    final interpreter:Interpreter;

    final scopes = new Stack<Map<String, Bool>>();
    var currentFunction:FunctionType = None;

    public function new(interpreter) {
        this.interpreter = interpreter;
    }

    public inline function resolve(s) {
		resolveStmts(s);
	}

	function resolveStmts(stmts:Array<Stmt>) {
        var returnToken = null;
		for(s in stmts){
            switch (s){
                case Return(keyword, value): returnToken = keyword;
                case _:
                    if (returnToken != null){
                        Lox.error(returnToken, 'Unreachable code after return statement.');
                        returnToken = null;
                    }
            }
            resolveStmt(s);
        }
	}

    function resolveStmt(stmt:Stmt) {
        switch (stmt){
            case Block(statements):
                beginScope();
                resolveStmts(statements);
                endScope();
            case Var(name, init):
                declare(name);
                if(init!=null) resolveExpr(init);
                define(name);
            case Function(name, params, body):
                declare(name);
                define(name);
                resolveFunction(name, params, body, Function);
            case Expression(e) | Print(e):
                resolveExpr(e);
                case If(cond, then, el):
                resolveExpr(cond);
                resolveStmt(then);
                if(el != null) resolveStmt(el);
            case Return(kw, val):
                if(currentFunction == None) Lox.error(kw, 'Cannot return from top-level code.');
                if(val != null) resolveExpr(val);
            case While(cond, body):
                resolveExpr(cond);
                resolveStmt(body);
            case Break(keyword):
            case Continue(keyword):
            case For(name, from, to, body):
                declare(name);
                define(name);
                resolveExpr(from);
                resolveExpr(to);
                resolveStmts(body);
        }
    }

    function resolveExpr(expr:Expr) {
		return switch expr {
			case Assign(name, op, value):
				resolveExpr(value);
				resolveLocal(expr, name);
			case Variable(name):
				if(!scopes.isEmpty() && scopes.peek().get(name.lexeme) == false)
					Lox.error(name, 'Cannot read local variable in its own initializer');
				resolveLocal(expr, name);
			case Binary(left, _, right) | Logical(left, _, right):
				resolveExpr(left);
				resolveExpr(right);
			case Call(callee, paren, arguments):
				resolveExpr(callee);
				for(arg in arguments) resolveExpr(arg);
			case Grouping(e) | Unary(_, e):
				resolveExpr(e);
			case Literal(_):
				// skip

		}
	}

    function resolveFunction(name:Token, params:Array<Token>, body:Array<Stmt>, type:FunctionType) {
		var enclosingFunction = currentFunction;
		currentFunction = type;
		beginScope();
		for(param in params) {
			declare(param);
			define(param);
		}
		resolveStmts(body);
		endScope();
		currentFunction = enclosingFunction;
	}

    function beginScope() {
		scopes.push([]);
	}

	function endScope() {
		scopes.pop();
    }
    
    function declare(name:Token) {
		if(scopes.isEmpty()) return;
		var scope = scopes.peek();
		if(scope.exists(name.lexeme)){
            Lox.error(name, 'Variable with this name already declared in this scope.');
        }
		scope.set(name.lexeme, false);
	}

	function define(name:Token) {
		if(scopes.isEmpty()) return;
		scopes.peek().set(name.lexeme, true);
    }
    
    function resolveLocal(expr:Expr, name:Token) {
		var i = scopes.length - 1;
		while(i >= 0) {
			if(scopes.get(i).exists(name.lexeme)) {
				interpreter.resolve(expr, scopes.length - 1 - i);
				return;
			}
			i--;
		}
    }
}

@:forward(push, pop, length)
abstract Stack<T>(Array<T>) {
    public function new() this = [];
	public inline function isEmpty() return this.length == 0;
	public inline function peek() return this[this.length - 1];
	public inline function get(i:Int) return this[i];
}

private enum FunctionType {
	None;
	Function;
} 