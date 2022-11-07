// A stack object for ColdFusion 

component {

	public stack function new() {
		variables.stack = ArrayNew(1);
		return this;
	}

	public void function push(required any obj) {
		ArrayAppend(variables.stack,arguments.obj);
	}

	public any function pop() {
		local.val = variables.stack[ArrayLen(variables.stack)];
		arrayDeleteAt(variables.stack,ArrayLen(variables.stack));
		return local.val;
	}

	public any function peek() {
		local.val = variables.stack[ArrayLen(variables.stack)];
		return local.val;
	}

	public numeric function count() {
		return ArrayLen(variables.stack);
	}
}