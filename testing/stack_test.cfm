<cfscript>
myStack = new utils.stack();
myStack.push("Balls");
writeOutput(myStack.peek() & "<br>");
myStack.push("Rackets");
writeOutput(myStack.peek() & "<br>");
writeOutput(myStack.pop() & "<br>");
writeOutput(myStack.pop() & "<br>");
writeOutput(myStack.count() & "<br>");
</cfscript>