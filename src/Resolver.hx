package;

class Resolver {
    final interpreter:Interpreter;

    final scopes = new Stack<Map<String, Variable>>();
    var currentFunction:FunctionType = None;

    public function new(interpreter) {
        this.interpreter = interpreter;
    }

    public inline function resolve(s) {
        beginScope();
        resolveStmts(s);
        endScope();
	}

	function resolveStmts(stmts:Array<Stmt>) {
        var returnToken = null;
		for(s in stmts){
            switch (s){
                case Return(keyword, value): returnToken = keyword;
                case _:
                    if (returnToken != null){
                        Lox.warn(returnToken, "Code is unreachable after 'return' statement.");
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
            case Var(name, init, mutable):
                var varStmt:Stmt = Var(name, init, mutable);
                declare(name, mutable, varStmt);
                if(init!=null) resolveExpr(init);
                define(name, mutable, false, varStmt);
            case Function(name, params, body):
                var func:Stmt = Function(name, params, body);
                declare(name, false, func);
                define(name, false, true, func);
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
            case For(name, from, to, steps, reverse, body):
                var forStmt:Stmt = For(name, from, to, steps, reverse, body);
                declare(name, true, forStmt);
                define(name, true, true, forStmt);
                resolveExpr(from);
                resolveExpr(to);
                resolveExpr(steps);
                resolveExpr(reverse);
                resolveStmts(body);
        }
    }

    function resolveExpr(expr:Expr) {
		return switch expr {
			case Assign(name, op, value):
                if(!scopes.isEmpty() && scopes.peek().exists(name.lexeme) && scopes.peek().get(name.lexeme).isReserved)
                    Lox.error(name, 'Variable ${name.lexeme} is reserved for ${scopes.peek().get(name.lexeme).stmt.getName()} statement.');
                if(!scopes.isEmpty() && scopes.peek().exists(name.lexeme) && !scopes.peek().get(name.lexeme).mutable)
					Lox.error(name, 'Cannot re-assign immutable variable.');
				resolveExpr(value);
				resolveLocal(expr, name, false);
			case Variable(name):
				if(!scopes.isEmpty() && scopes.peek().exists(name.lexeme) && scopes.peek().get(name.lexeme).state.match(Declared))
					Lox.error(name, 'Cannot read local variable in its own initializer');
				resolveLocal(expr, name, true);
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
			declare(param, true, Function(name, params, body));
			define(param, true, true, Function(name, params, body));
		}
		resolveStmts(body);
		endScope();
		currentFunction = enclosingFunction;
	}

    function beginScope() {
		scopes.push([]);
	}

	function endScope() {
        var scope = scopes.pop();
        for(name => variable in scope){
            if(variable.state.match(Defined)){
                Lox.warn(variable.name, 'Local ${variable.stmt.getName()} is not used');
            }
        }
    }
    
    function declare(name:Token, mutable:Bool = true, stmt:Stmt) {
		if(scopes.isEmpty()) return;
		var scope = scopes.peek();
		if(scope.exists(name.lexeme)){
            Lox.error(name, '${scope.get(name.lexeme).stmt.getName()} with this name already declared in this scope.');
        }
		scope.set(name.lexeme, {name: name, state: Declared, mutable: mutable, isReserved: false, stmt: stmt});
	}

	function define(name:Token, mutable:Bool = true, isReserved:Bool = false, stmt:Stmt) {
		if(scopes.isEmpty()) return;
		scopes.peek().set(name.lexeme, {name: name, state: Defined, mutable: mutable, isReserved: isReserved, stmt: stmt});
    }
    
    function resolveLocal(expr:Expr, name:Token, isRead:Bool) {
		var i = scopes.length - 1;
		while(i >= 0) {
			if(scopes.get(i).exists(name.lexeme)) {
                interpreter.resolve(expr, scopes.length - 1 - i);
                if(isRead){
                    scopes.get(i).get(name.lexeme).state = Read;
                }
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

typedef Variable = {
    var name:Token;
    var state: VariableState;
    var mutable:Bool;
    var isReserved:Bool;
    var stmt:Stmt;
}

enum VariableState {
    Declared;
	Defined;
	Read;
}