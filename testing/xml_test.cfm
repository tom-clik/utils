<!---

# utils.xml test page

Loads a sample XML page and dumps it

--->

<cfscript>
utils = new utils.utils();
xmlObj = new utils.xml();

myXML = utils.fnReadXML("testing/sample.xml");
myData = xmlObj.xml2Data(myXML);
writeDump(myData);
</cfscript>