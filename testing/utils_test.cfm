<!---

# utils.cfc test page

Used when needed


--->

<cfscript>


abort;
request.utils = new utils.utils();

param name="url.test" default="tags";

switch (url.test) {
	case "tags":
	tests = ["[image oneattr = ""'quote yeah yea'h'"" anotheratt= ' single never' another=abcfeg]]",
	"<image id=467464764>","<cliktag type=""type"">"];
	for (testString in tests) {
		start = GetTickCount();
		test2 = request.utils.fnParseTagAttributes(testString);
		end = GetTickCount();
		WriteOutput("Parsed: " & HtmlEditFormat(testString) & " in #end-start# ticks<br>");
		WriteDump(test2);
	}
	break;
}
	
</cfscript>