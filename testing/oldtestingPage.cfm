<!---

# TODO: convert to testbox
--->

<cfset utils = new utils.utils()>
<!---
<cfinclude template="/wps_settings/setServerConstants.cfm">
<cfset ini_file = ExpandPath("/wps_settings/clikpic.ini")>
<cfset settings = utils.fnParseIniFile(ini_file, server_name)>
<cfset utils.fnAddMapping("templateroot.clikpic.com",settings.templateroot)>
<cfset utils.fnAddMapping("contentsections.clikpic.com","#settings.templateroot#/_contentsections")>
<cfset utils.fnAddMapping("styles.clikpic.com",settings.siteroot & "\_common\_styles")>
<cfset utils.fnAddMapping("templates.clikpic.com","#settings.templateroot#/_templates_v_#settings["template_version"]#")>
<cfset utils.fnAddMapping("stylesheets.clikpic.com","#settings.templateroot#/_stylesheets_v_#settings["stylesheet_version"]#")>
<cfset utils.fnAddMapping("layouts.clikpic.com","#settings.templateroot#/_layouts")>
<cfset utils.fnAddMapping("testing.clikpic.com","#settings.templateroot#/_testing")>
<cfset utils.fnAddMapping("common.clikpic.com","#settings.siteroot#/_common")>
<cfset utils.fnAddMapping("sitetemplates.clikpic.com","#settings.templateroot#/_site_templates")>
<cfset utils.fnAddMapping("guides.clikpic.com","#settings.templateroot#/_guides")>
<cfset utils.fnAddMapping("data.clikpic.com",ExpandPath("/customtags/clikpic/_data"))>
<cfset utils.fnAddMapping("docs.clikpic.com","#settings.docsfolder#")>

<cfset mappings = structKeyArray(utils.fnGetAllMappings())>

<cfset start = getTickCount()>
<cfset end = arrayLen(mappings)>

<cfset dir = utils.fnGetFileMapping("contentsections.clikpic.com/css/forms.css")>
	<cfoutput>#dir#<br></cfoutput>
	<cfabort>

<cfloop index="i" from="1" to="1000">

	<cfset dir = utils.fnGetFileMapping("#mappings[randRange(1,end)]#/clikpic/clikpic#i#.xml")>
	<cfoutput>#dir#<br></cfoutput>
</cfloop>

<cfdump var="#utils.fnGetAllMappings()#">


<cfoutput><h3>Completed in #getTickCount() - start# mills</h3></cfoutput>

--->

<!--- <cfset dir = getDirectoryFromPath(getCurrentTemplatePath())>
<cfoutput>#dir#</cfoutput>

<cfset utils.fnAddMapping("utilstest.clikpic.com",dir)> --->

<!--- <cfdump var="#utils.fnGetAllMappings()#"> --->


<!---
<cfset utils.fnAddMapping("utils", ExpandPath("/customtags/cfscript"))>
<cfset mySettings = utils.fnLoadSettingsFromFile("utils/utilsTestData.txt")>
<cfdump var="#mySettings#">

<cfset mySettings = utils.fnGetMIMETypeFromExtension("xls")>
<cfdump var="#mySettings#">
--->


<!---
<cfset request.utils.fnAddMapping("utils", ExpandPath("/customtags/cfscript"))>
<cfset request.utils.fnAddMapping("templates.clikpic.com/v3_6","C:\ColdFusion9\CustomTags\Clikpic\_templates_v_3_06")>

<cfobject name="contentSections" component="clikpic.contentSections">

<cfset contentSections.fnParseXML("templates.clikpic.com/v3_6/_common/content_sections_defaults_defaults.xml")>
--->

<!---
<cfset myList = "1,2,3,4,5,1,3,4,6,7,7,8,9,4,6,5,7,4,3">
<cfset MyStruct = StructNew()>
<cfset MyStruct[5] = 0>
<cfset myNewList = utils.ListRemoveDuplicates(myList,",",MyStruct)>
<cfdump var="#myNewList#">
<cfdump var="#MyStruct#">


<cfset dodgyName = ExpandPath("test not safe$%!6ga" & RandRange(1,1000) & ".txt")>

<cffile action="copy" source="#ExpandPath("utilsTestData.txt")#" destination="#dodgyName#">

<cfset fileTest = request.utils.fnWebsafeFileName(dodgyName)>

<cfdump var="#fileTest#">
	
<cffile action="copy" source="#ExpandPath("utilsTestData.txt")#" destination="#dodgyName#">

<cfset fileTest = request.utils.fnWebsafeFileName(dodgyName)>

<cfdump var="#fileTest#">
	
<cfset fileTest = request.utils.fnWebsafeFileName(ExpandPath(fileTest.serverFile))>

<cfdump var="#fileTest#">

--->

<!--- 
<cfset mydata = "
<bridge>
[Deal ""S:.63.AKQ987.A9732 A8654.KQ5.T.QJT6 J973.J98742.3.K4 KQT2.AT.J6542.85""]
[scoring ""Matchpoints""]
[vulnerable ""NS""]
[North ""Peer""]
[West ""Nunes""]
[south ""Clow""]
[East ""Fantoni""]
[dealer ""S""]
[auction]
1h p 2h p
2nt =1= p 3c =2= p
3s ap
[note ""1:Forcing""]
[note ""2:Only 3S""]
</bridge>
">

<!--- <cfset mydata = "
[bridge]
sdfsf ;ksjdg ldskf gldksjf ;
[/bridge]
"> --->


<cfset tagContents = utils.fnParseTagValues(mydata,"bridge")>
<cfdump var="#tagContents#"> --->
<!--- 
<cfset myData = {}>

<table>
<cfloop from=1 to=1000 index="i">
	<cfset sort_order=(10*randRange(1,200)-1)>
	<cfset date=DateAdd("d",now(),randRange(1,300))>
	<cfif randRange(1,9) eq 1>
		<cfset sort_order="">
	</cfif>
	<cfset myData[i] = {id=i, sort_order=sort_order,date=date}>
	<cfoutput><tr><td>#i#</td><td>#myData[i].sort_order#</td><td>#myData[i].date#</td></tr></cfoutput>
</cfloop>
</table>


<cfset local.sortCrit = [
	{field="sort_order",type="numeric"},
	{field="date",type="date",direction="desc"},
	{field="id",type="numeric",direction="desc"}
]>

<cfset ticks = getTickCount()>
<cfset mySort = utils.structMultiSort(myData,local.sortCrit)> 

<cfset end = getTickCount() -ticks>

<cfoutput>Done in #end# mils<br></cfoutput>

<cfdump var="#mySort#"> --->

<!--- <cfset myTag = utils.fnParseTagAttributes("[link type=section code=index][/link]",1)>
<cfdump  var="#myTag#">
<cfset myTag = utils.fnParseTagAttributes("<a href='myhreh' nonsesne='adfh sdlkjf hs**' test=""test%"">content</a>")>
<cfdump  var="#myTag#">
<cfset myTag = utils.fnParseTagAttributes("[[ a href='myhreh' nonsesne='adfh sdlkjf hs**' test=""test%""]]content[/a]")>
<cfdump  var="#myTag#">

<cfset myTag = utils.fnParseTagAttributes("<a href='11_myhreh6' nonsesne='adfh sdlkjf_hs**' test=""t6est%"">",true)>
<cfdump  var="#myTag#">
 --->
