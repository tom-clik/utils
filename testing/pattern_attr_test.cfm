<!---

# Pattern Matching Demo

Demonstrates Usage of Java patterns in ColdFusion

--->

<cfscript>
myTestString = "[[image anotheratt= ' single never' another=abcfeg oneattr = ""'quote yeah yea'h'"" ]]";
patternObj = createObject( "java", "java.util.regex.Pattern");
myPattern = "(\w+)(\s*=\s*(""(.*?)""|'(.*?)'|([^'"">\s]+)))";

pattern = patternObj.compile(myPattern);
tagObjs = pattern.matcher(myTestString);
fixEntities = [];

WriteOutput("<pre>");
while (tagObjs.find()){
    ArrayAppend(fixEntities, tagObjs.group());
    // writeOutput( tagObjs.group(javacast("int",2)) &  chr(13));
    tagVal = ReReplace(tagObjs.group(javacast("int",3)), "^(""|')(.*?)(""|')$", "\2");
    WriteOutput(tagObjs.group(javacast("int",1)) & " = " & tagVal & chr(13));
}
WriteOutput("</pre>");

WriteDump(fixEntities);
</cfscript>

