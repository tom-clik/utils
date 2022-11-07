<!--- some useful functions to have in the server scope --->
<cfcomponent name="utils">

	<cffunction name="init" hint="Optional pseudo constructor. You need this if you are going to use mappings or caching
		for file paths in functions like load settings">
		
		<cfset variables.mappings = {}>
		
		<!--- where we have a mapping for customtags, add that mapping to this object --->
		<cfset local.path = ExpandPath("/customtags/cfscript")>
			
		<cfif DirectoryExists(local.path)>
			<cfset fnAddMapping("utils", local.path)>
		</cfif>
		
	    <cfset this.collections =  createObject( "java", "java.util.Collections" )>
	        
		<cfset fnSetLog(0)>

		<cfreturn this>
			
	</cffunction>

	<cffunction name="fnGetFileMapping" output="false" returntype="string" hint="Test whether the file path passed in has a mapping associated with it. Returned the mapped filepath or blank if no mapping is found."
		notes="E.g. if you have a mapping of dev.clikpic.com/testing => C:\inetpub\wwwroot\clikpic\testing then dev.clikpic.com/testing/test.html
		will return C:\inetpub\wwwroot\clikpic\testing\test.html<br><br>">
			
		<cfargument name="filepath" type="string" required="true">
		<cfargument name="returnOriginal" type="boolean" default="false" hint="Annoyingly the original function returned blank(??) set this to true to return original entry if it isn't in a mapping. Much more useful.">
		<cfargument name="cache" type="boolean" required="false" default="1" hint="optionally maintain a cache">

		<cfif arguments.cache AND NOT StructKeyExists(this,"fileMappingCache")>
			<cfset this.fileMappingCache = {}>
		</cfif>

		<cfif NOT arguments.cache OR NOT structKeyExists(this.fileMappingCache,arguments.filepath)>
			<cfset local.retVal = arguments.returnOriginal ? arguments.filepath : "">

			<cfif IsDefined("variables.mappings")>
				<cfset local.root = ListFirst(arguments.filepath,"/\")>
				<cfif structKeyExists(variables.mappings, local.root)>
					<cfset local.retVal = variables.mappings[local.root] & "/" & ListRest(arguments.filepath,"/\")>
				</cfif>
			</cfif>
			
			<cfif arguments.cache>
				<cflock name="filepathCache" type="exclusive" timeout="5">
					<cfset this.fileMappingCache[arguments.filepath] = local.retVal>
				</cflock>
			</cfif>
		<cfelse>
			<cfset local.retVal =this.fileMappingCache[arguments.filepath]>
		</cfif>
		
		<cfreturn local.retVal>
		
	</cffunction>

	<cffunction name="fnCheckDirectory" output="false" returntype="boolean" hint="Check a directory exists and try to create it if it doesn't">
		
		<cfargument name="filepath" type="string" required="true">
		
		<cfset var mapping = fnGetFileMapping(arguments.filepath)>
		<cfset mapping = mapping eq "" ? arguments.filepath : mapping>
		
		<cfset var retVal = directoryExists(mapping)>

		<cfif NOT retVal>
			<cfdirectory action="create" directory="#mapping#">
		</cfif>
		
		<cfreturn retVal>
		
	</cffunction>


	<cffunction name="fnGetFileName" output="false" returntype="string" hint="Calls getFileMapping but returns original name if none found">
			
		<cfargument name="filepath" type="string" required="true">
		
		<cfset var sLocal = {}>
		
		<cfset local.filename = fnGetFileMapping(arguments.filepath)>

		<cfreturn (local.filename eq "" ? arguments.filepath : local.filename)>

		
	</cffunction>

	<cffunction name="fnGetAllMappings" output="true" returntype="Struct" hint="Return all mappings"
		notes="Found some of our stuff e.g. settingsObj had its own mappings functionality. To make sure the mapping definitions
		are consistent, we can get them out of here and add them to those.

		Ideally we will remove all this individual stuff in time and just use these standard methods.">
		
		<cfreturn Duplicate(variables.mappings)>
		
	</cffunction>
		
	<cffunction name="fnAddMapping" output="false" returntype="boolean" hint="Add a mapping for file path. Returns true on success.">
			
		<cfargument name="mapping" type="string" required="true">
		<cfargument name="filePath" type="string" required="true">
			
		<cfset Local.retVal = 0>
		
		<cfif IsDefined("variables.mappings")>
			<cfset variables.mappings[arguments.mapping] = arguments.filePath>
			<cfset Local.retVal = 1>
		</cfif>

		
		<cfreturn Local.retVal>
		
	</cffunction>

	<cffunction name="fnGetDirectoryFromFile" output="false" returntype="string" hint="Return the directory from a path">
			
		<cfargument name="filePath" type="string" required="true">
		
		<cfset var sLocal = {}>

		<cfset local.path = fnGetFileMapping(arguments.filePath)>
		<cfif local.path neq "">
			<cfset arguments.filePath = local.path>
		</cfif>

		<cfset local.dir = Reverse(ListRest(Reverse(arguments.filePath),"/\"))>
		
		<cfreturn local.dir>
		
	</cffunction>

	<cffunction name="fnFileExists" output="false" hint="FileExists that checks in mappings">
		<cfargument name="filepath" type="string" required="true">
		
		<cfset local.filepath = fnGetFileMapping(arguments.filepath)>
		<cfif local.filepath eq "">
			<cfset local.filepath = arguments.filepath>
		</cfif>

		<cfreturn fileExists(local.filepath)>
		
	</cffunction>

	<!--- note about remote download.

	This was the start of an attempt at building a proper distributed resource system, where a reload would update any resources like this that had been
	updated. The idea would be that there would be another set of mappings for URLs, and that the system would check the cache times on all these --->

	<cffunction name="fnReadFile" output="false"  hint="Load a file from disk. Can load a local file, a mapped file (see fnGetFileMapping()) or a URL.
		A URL can be supplied either with http:// which will force a remote load, or as mapping to a URL which will download the file to
		the mapped location if it doesn't already exist. Eg. if docs.clikpic.com is mapped to c:\docs\clikpic and you specify docs.clikpic.com/development/rubbish.doc, it will
		check the local file system for c:\docs\clikpic\development\rubbish.doc, and if it doesn't exist, will try to download it from http://docs.clikpic.com/development/rubbish.doc (see note above)">
			
		<cfargument name="filepath" type="string" required="true">
		<cfargument name="charset" type="string" required="false" default="utf-8">
		<cfargument name="binary" type="boolean" required="false" default="0">

		
		<cfif Left(arguments.filepath,4) eq "http">
			<!--- no local mapping. get remote file straight via http --->
			<cftry>
			
				<cfhttp url="#arguments.filepath#" throwonerror="yes"></cfhttp>
				<cfset sLocal.fileData = CFHTTP.FileContent>
				<cfcatch>
					<cfthrow type="FileNotFound" message="Unable to get remote file #arguments.filepath#" detail="#cfcatch.message#<br><br>#cfcatch.detail#">
				</cfcatch>
			
			</cftry>
		<cfelse>
			<cfset local.tickCount = getTickCount()>
			<cfset sLocal.filepath = fnGetFileMapping(arguments.filepath,1)>

			<cfset local.mappingTime = getTickCount() - local.tickCount>
			<!--- <cfif local.mappingTime gt 200>
				<cfoutput>utils.fnGetFileMapping() Took #local.mappingTime# to load #arguments.filepath# (see fnReadFile())</cfoutput>
				<cfabort>
			</cfif> --->
			<cfif NOT FileExists(sLocal.filepath)>
				<cftry>
					<cfhttp url="http://#arguments.filepath#" file="#sLocal.filepath#" throwonerror="yes"></cfhttp>
					<cfcatch>
						<cfthrow type="FileNotFound" message="Unable to download remote file #arguments.filepath# [#sLocal.filepath#]" detail="#cfcatch.message#<br><br>#cfcatch.detail#">
					</cfcatch>
				</cftry>
			</cfif>

			<cfif arguments.charset neq "" AND NOT arguments.binary>
				<cffile action="READ" file="#sLocal.filepath#" variable="sLocal.fileData" charset="#arguments.charset#">
			<cfelse>
				<cfset local.readAction = (arguments.binary ? "readbinary" : "read")>
				<cffile action="#local.readAction#" file="#sLocal.filepath#" variable="sLocal.fileData">
			</cfif>
			
		</cfif>
		
		<cfreturn sLocal.fileData>
		
	</cffunction>

	<cffunction name="fnReadXML" output="false" returntype="string" hint="Load an XML file from disk and parse it.">
			
		<cfargument name="filepath" type="string" required="true" hint="file path.  See notes for fnReadFile()">
		
		<cfset var sLocal = {}>
			
		<cfset sLocal.fileData = fnReadFile(arguments.filePath)>
		<!--- unicode 0x1f 'Unit Separator' is not valid in XML - replace with tab --->
		<!--- http://stackoverflow.com/questions/6693153/what-is-character-0x1f --->
		<cfset sLocal.fileData = reReplace(sLocal.fileData, "\x1f", "	", "all")>
		<cftry>
			<cfset sLocal.XMLData = XmlParse(sLocal.fileData)>
			<cfcatch>
				<cfthrow message="Unable to parse XML file" detail="fnReadXML():Unable to parse file #arguments.filepath#<br><br>#cfcatch.message#<br><br>#cfcatch.detail#">
			</cfcatch>
	     </cftry>
				
		<cfreturn sLocal.XMLData>
		
	</cffunction>

	<cffunction name="fileSizeFormat" output="false" hint="Return a formatted file size given an integer number of bytes (e.g. 80000 -> 80kb)" returntype="string">
		<cfargument required="yes" name="size" type="numeric" hint="Size in bytes">
		<cfargument required="no" name="sf" default="3" type="numeric" hint="Significant figures for result">
		
		<cfscript>
			if (size lt 1000) {
				return "#SigFigs(size,sf)#b";
			}
			else if (size lt 1000000) {
				size = size / 1000;
				return "#SigFigs(size,sf)#Kb";
			}
			
			else if (size lt 1000000000) {
				size = size / 1000000;
				return "#SigFigs(size,sf)#Mb";
			}
			else {
				size = size / 1000000000;
				return "#SigFigs(size,sf)#Gb";
			}
		</cfscript>

	</cffunction>

	<cffunction name="SigFigs" output="false" hint="Return a number with only given number of significant figures" returntype="string">
		<cfargument required="yes" name="number" type="numeric" hint="Size in bytes">
		<cfargument required="yes" name="sf" type="numeric" hint="Significant figures for result">
		
		<cfscript>
		var result = "";
		var afterpoint = 0;
		var digit = "";
		var i = 1;
		
		for (; i lte Len(arguments.number); i = i + 1) {
			
			digit = Mid(arguments.number,i,1);
			if (digit eq ".") {
				result = result & ".";
				afterpoint = 1;
			}
			else {
				if (arguments.sf gt 0) {
					result = result & digit;
					arguments.sf = arguments.sf - 1;
				}
				else if (NOT afterpoint) {
					result = result & "0";
				}
			}
		}
		
		return result;
		</cfscript>
	</cffunction>

	<cffunction name="convertStructToLower" access="public" returntype="any">
	    <cfargument name="st" required="true" type="any" hint="in practice: struct or array">

	    <cfset var aKeys = false>
	    <cfset var stN = false>
	    <cfset var i= 0>
	    <cfset var ai= 0>

	    <cfif isArray(arguments.st)>
	    	<cfset stN = []>
	    	<cfloop array="#arguments.st#" index="i">
	    		<cfset arrayAppend(stN, convertStructToLower(i))>
	    	</cfloop>
	    <cfelseif isStruct(arguments.st)>
	    	<cfset aKeys = structKeyArray(arguments.st)>
	    	<cfset stN = structNew()>

		    <cfloop array="#aKeys#" index="i">
		        <cfif isStruct(arguments.st[i])>
		            <cfset stN['#lCase(i)#'] = convertStructToLower(arguments.st[i])>
		        <cfelseif isArray(arguments.st[i])>
		            <cfloop from=1 to="#arraylen(arguments.st[i])#" index="ai">
		                <cfif isStruct(arguments.st[i][ai])>
		                    <cfset arguments.st[i][ai] = convertStructToLower(arguments.st[i][ai])>
		                <cfelse>
		                    <cfset arguments.st[i][ai] = arguments.st[i][ai]>
		                </cfif>
		            </cfloop>
		            <cfset stN['#lcase(i)#'] = arguments.st[i]>
		        <cfelse>
		            <cfset stN['#lcase(i)#'] = arguments.st[i]>
		        </cfif>
		    </cfloop>
	    <cfelse>
	    	<cfthrow message="Must provide array or struct for convertStructToLower">
	    </cfif>
	    <cfreturn stn>
	</cffunction>


		
	<cfscript>
	/**
	* Makes a row of a query into a structure.
	*
	* @param query      The query to work with.
	* @param row      Row number to check. Defaults to row 1.
	* @return Returns a structure.
	* @author Nathan Dintenfass (nathan@changemedia.com)
	* @version 1, December 11, 2001
	*/
	function queryRowToStruct(query){
	    //by default, do this to the first row of the query
	    var row = 1;
	    //a var for looping
	    var ii = 1;
	    //the cols to loop over
	    var cols = listToArray(arguments.query.columnList);
	    //the struct to return
	    var stReturn = structnew();
	    //if there is a second argument, use that for the row number
	    if(arrayLen(arguments) GT 1)
	        row = arguments[2];
	    //loop over the cols and build the struct from the query row    
	    for(ii = 1; ii lte arraylen(cols); ii = ii + 1){
	        stReturn[cols[ii]] = arguments.query[cols[ii]][row];
	    }        
	    //return the struct
	    return stReturn;
	}

	/**
	* Converts a query object into a structure of structures accessible by its primary key.
	* 
	* Ifthere is cust one other column, returns simple values as keys
	*
	* @param theQuery      The query you want to convert to a structure of structures.
	* @param primaryKey      Query column to use as the primary key.
	* @return Returns a structure.
	* @author Shawn Seley (shawnse@aol.com)
	* @version 1, March 27, 2002
	*/
	function QueryToStructOfStructures(theQuery, primaryKey,removeKey=0){
	var theStructure = structnew();

	var cols = [];

	var row = 1;
	var thisRow = "";
	var col = 1;

	for (local.check in getMetaData(arguments.theQuery)) {
		// remove primary key from cols listing
		if (NOT Arguments.removeKey OR  (local.check.name neq arguments.primaryKey)) {
			ArrayAppend(cols, local.check.name);	
		}
	}

	for(row = 1; row LTE theQuery.recordcount; row = row + 1){
		if (arraylen(cols) gt 1) {
			thisRow = structnew();
			for(col = 1; col LTE arraylen(cols); col = col + 1){
				thisRow[cols[col]] = theQuery[cols[col]][row];
			}
			theStructure[theQuery[primaryKey][row]] = duplicate(thisRow);
		}
		else {
			theStructure[theQuery[primaryKey][row]] = theQuery[cols[1]][row];
		}
	}
	return(theStructure);
	}



	/**
	* Recursive functions to compare structures and arrays.
	* Fix by Jose Alfonso.
	*
	* @param LeftStruct      The first struct. (Required)
	* @param RightStruct      The second structure. (Required)
	* @return Returns a boolean.
	* @author Ja Carter (ja@nuorbit.com)
	* @version 2, October 14, 2005
	*/
	function structCompare(LeftStruct,RightStruct) {
	    var result = true;
	    var LeftStructKeys = "";
	    var RightStructKeys = "";
	    var key = "";
	    
	    //Make sure both params are structures
	    if (NOT (isStruct(LeftStruct) AND isStruct(RightStruct))) return false;

	    //Make sure both structures have the same keys
	    LeftStructKeys = ListSort(StructKeyList(LeftStruct),"TextNoCase","ASC");
	    RightStructKeys = ListSort(StructKeyList(RightStruct),"TextNoCase","ASC");
	    if(LeftStructKeys neq RightStructKeys) return false;    
	    
	    // Loop through the keys and compare them one at a time
	    for (key in LeftStruct) {
	        //Key is a structure, call structCompare()
	        if (isStruct(LeftStruct[key])){
	            result = structCompare(LeftStruct[key],RightStruct[key]);
	            if (NOT result) return false;
	        //Key is an array, call arrayCompare()
	        } else if (isArray(LeftStruct[key])){
	            result = arrayCompare(LeftStruct[key],RightStruct[key]);
	            if (NOT result) return false;
	        // A simple type comparison here
	        } else {
	            if(LeftStruct[key] IS NOT RightStruct[key]) return false;
	        }
	    }
	    return true;
	}

	/**
	 * Recursive functions to compare arrays and nested structures.
	 * 
	 * @param LeftArray 	 The first array. (Required)
	 * @param RightArray 	 The second array. (Required)
	 * @return Returns a boolean. 
	 * @author Ja Carter (ja@nuorbit.com) 
	 * @version 1, September 23, 2004 
	 */
	function arrayCompare(LeftArray,RightArray) {
		var result = true;
		var i = "";
		
		//Make sure both params are arrays
		if (NOT (isArray(LeftArray) AND isArray(RightArray))) return false;
		
		//Make sure both arrays have the same length
		if (NOT arrayLen(LeftArray) EQ arrayLen(RightArray)) return false;
		
		// Loop through the elements and compare them one at a time
		for (i=1;i lte arrayLen(LeftArray); i = i+1) {
			//elements is a structure, call structCompare()
			if (isStruct(LeftArray[i])){
				result = structCompare(LeftArray[i],RightArray[i]);
				if (NOT result) return false;
			//elements is an array, call arrayCompare()
			} else if (isArray(LeftArray[i])){
				result = arrayCompare(LeftArray[i],RightArray[i]);
				if (NOT result) return false;
			//A simple type comparison here
			} else {
				if(LeftArray[i] IS NOT RightArray[i]) return false;
			}
		}
		
		return true;
	}

</cfscript>

<cffunction name="fnDeepStructAppend" output="false" returntype="void" hint="Appends the second struct to the first.">
	
	<cfargument name="struct1" type="struct" hint="Struct to which values from struct2 are appended.">
	<cfargument name="struct2" type="struct" hint="Append these values to struct1.">
	<cfargument name="overwrite" default="true" required="false" hint="Whether to overwrite keys that already exist in struct1">
	<!--- NB overwrite=false used to only work at first level - if this behaviour is required, use overwrite=false,overwriteDeep=false --->
	<cfargument name="overwriteDeep" default="#arguments.overwrite#" required="false" hint="Whether to overwrite keys that already exist in struct1 when recursing">
	
	<cfset var sLocal = StructNew()>
	
	<cfscript>
	for(sLocal.key IN arguments.struct2){
		if(StructKeyExists(arguments.struct1,sLocal.key) AND 
			IsStruct(arguments.struct2[sLocal.key]) AND 
			IsStruct(arguments.struct1[sLocal.key])){
			fnDeepStructAppend(arguments.struct1[sLocal.key],arguments.struct2[sLocal.key],arguments.overwriteDeep);
		}
		else if (arguments.overwrite OR NOT StructKeyExists(arguments.struct1,sLocal.key)){
			arguments.struct1[sLocal.key] = Duplicate(arguments.struct2[sLocal.key]);
		}
	}
	</cfscript>

</cffunction>

<cffunction name="fnStructOR" output="false" returntype="void" hint="Takes two structs with boolean values and does an OR operation on the keys. One deep only. REMOVES NON Boolean">
	
	<cfargument name="struct1" hint="Struct to which values from struct2 are compared.">
	<cfargument name="struct2" hint="Compare these values to struct1.">
	
	<cfset var sLocal = StructNew()>
	
	<cfscript>
	for(sLocal.key IN arguments.struct2){
		if (isBoolean(arguments.struct2[sLocal.key])) {
			if(NOT StructKeyExists(arguments.struct1,sLocal.key)) {
				arguments.struct1[sLocal.key] = 1 AND arguments.struct2[sLocal.key];
			}
			else if (isBoolean(arguments.struct1[sLocal.key])) {
				arguments.struct1[sLocal.key] = arguments.struct1[sLocal.key] OR arguments.struct2[sLocal.key];
			}
			else {
				StructDelete(arguments.struct1,sLocal.key);
			}
		}
		else {
			StructDelete(arguments.struct1,sLocal.key);
		}
	}
	</cfscript>

</cffunction>

<cffunction name="fnStructClean" output="false" returntype="void" hint="Remove keys from one struct that aren't in a second one">
	
	<cfargument name="struct1" hint="Struct to be cleaned">
	<cfargument name="struct2" hint="These keys can be present in struct one">
	
	<cfset var sLocal = StructNew()>
	
	<cfscript>
	for(sLocal.key IN arguments.struct1){
		if(NOT StructKeyExists(arguments.struct2,sLocal.key)) {
			StructDelete(arguments.struct1,sLocal.key);
		}
	}
	</cfscript>

</cffunction>

<cffunction name="StructRefresh" output="false" returntype="void" hint="Struct append but only uses existing keys.">
	
	<cfargument name="struct1" hint="Struct to be updated">
	<cfargument name="struct2" hint="Values to overwrite originals">
	
	<cfset var sLocal = StructNew()>
	
	<cfscript>
	for(sLocal.key IN arguments.struct1){
		if(StructKeyExists(arguments.struct2,sLocal.key)) {
			if( isStruct(arguments.struct1[sLocal.key]) AND isStruct(arguments.struct2[sLocal.key]) ) {
				StructRefresh(arguments.struct1[sLocal.key], arguments.struct2[sLocal.key]);
			} else {
				arguments.struct1[sLocal.key] = Duplicate(arguments.struct2[sLocal.key]);
			}
		}
	}
	</cfscript>

</cffunction>

<!--- 
	* Author: Ben Nadel (http://www.bennadel.com)
 --->
<cffunction name="StructCreate"
	access="public"
	returntype="struct"
	output="false"
	hint="Creates a struct based on the argument pairs.">
 
	<!--- Define the sLocal scope. --->
	<cfset var sLocal = StructNew()>
 
	<!--- Create the target struct. --->
	<cfset sLocal.Struct = StructNew()>
 
	<!--- Loop over the arguments. --->
	<cfloop collection="#ARGUMENTS#" item="sLocal.Key">
		
		<!--- Set the struct pair values. --->
		<cfset sLocal.Struct[ sLocal.Key ] = ARGUMENTS[ sLocal.Key ]>
		
	</cfloop>
 
	<!--- Return the resultant struct. --->
	<cfreturn sLocal.Struct />
	
</cffunction>
<cffunction name="ListRemoveDuplicates" returntype="string" output="false" hint="Takes a list argument and returns that list with the duplicates removed.">
	
	<cfargument name="list" type="string" required="true" hint="A list to remove the duplicates from.">
	<cfargument name="delimiters" type="string" required="false" default=",">
	<cfargument name="processedVals" type="struct" required="false" default="#StructNew()#" hint="You can pass in an empty struct to return counts of items in list or even pass in some values - any item defined in the struct will be omitted from the returned list">
	
	<cfset var i = 0>
	<cfset var retVal = "">
	
	<cfloop list="#arguments.list#" index="i" delimiters="#arguments.delimiters#">
		<cfif NOT StructKeyExists(arguments.processedVals,i)>
			<cfset retVal = ListAppend(retVal,i)>
			<cfset arguments.processedVals[i]= 1>
		<cfelse>
			<cfset arguments.processedVals[i] += 1>
		</cfif>
		
	</cfloop>
	
	<cfreturn retVal>
	
</cffunction>

<cffunction name="fnParseIniFile" returntype="struct" output="false" hint="Parses an ini file and returns values in a struct (or struct of struct keyed by section name if no section attribute is specified)">
	
	<cfargument name="ini_file" type="string" required="true" hint="File to parse">
	<cfargument name="section" type="string" required="no" hint="Section to parse values for. If no section is specified, the return struct is a struct of structs keyed by the section names">
	
    <cfset var settings = StructNew()>
	<cfset var sections = false>
	<cfset var sectionList = false>
	<cfset var sectionName = false>
	<cfset var dataNames = false>
	<cfset var key = false>	
	<cfset var tmpSettings = StructNew()>
	
	<cfif NOT FileExists(arguments.ini_file)>
		<cfthrow message="Unable to find ini file #arguments.ini_file#">
	</cfif>

	<cfset local.rawtext = fnReadFile(arguments.ini_file)>

	<cfset local.section = "">
	<cfloop index="local.line" list="#local.rawText#" delimiters="#chr(13)##chr(10)#">
		<cfif Left(trim(local.line),1) eq ";" or Left(trim(local.line),1) eq "##">
			<cfcontinue>
		<cfelseif Left(trim(local.line),1) eq "[">
			<cfset local.section = ListFirst(local.line,"[]")>
		<cfelse>
			<cfif local.section eq "">
				<cfthrow message="Incorrect ini file definition #arguments.ini_file#">
			</cfif>
			<cfif NOT structKeyExists(settings,local.section)>
				<cfset settings[local.section] = {}>
			</cfif>
			
			<cfset settings[local.section][ListFirst(trim(local.line),"=")] = ListRest(local.line,"=")>
		</cfif>
	</cfloop>

	<cfloop item="sectionName" collection="#settings#">
		<cfset checkSettingsInheritance(settings[sectionName],settings)>
		
	</cfloop>
    
    <cfif IsDefined("arguments.section")>
    	<cfif NOT StructKeyExists(settings, arguments.section)>
            <cfthrow message="Section ## not found in file #arguments.ini_file#">
        </cfif>
        <cfset settings  = settings[arguments.section]>
    </cfif>
    
	<cfreturn settings>

</cffunction>

<cffunction name="checkSettingsInheritance">
	<cfargument name="section">
	<cfargument name="settings">
	<cfif StructKeyExists(arguments.section, "inherit")>
        <cfloop index="local.sectionName" list="#arguments.section["inherit"]#">
            <cfset checkSettingsInheritance(arguments.settings[local.sectionName],arguments.settings)>
            <cfset StructAppend(arguments.section,settings[local.sectionName],false)>
            <cfset StructDelete(arguments.section, "inherit")>
        </cfloop>
    </cfif>
</cffunction>


<cffunction name="fnListDelete" returntype="string" output="false" hint="Takes a list and a list element and deletes the first instance of that element from the list.">
	
	<cfargument name="list" type="string" required="true" hint="List from which to delete the element.">
	<cfargument name="list_element" type="string" required="true" hint="The element to delete from the list.">
	<cfargument name="delimiters" type="string" required="false" default=",">
	
	<cfset var position = false>
	
	<cfset position = ListFind(arguments.list,arguments.list_element,arguments.delimiters)>
	<cfif position>
		<cfset arguments.list = ListDeleteAt(arguments.list,position,arguments.delimiters)>
	</cfif>
	
	<cfreturn arguments.list>
	
</cffunction>

<cffunction name="fnListAlter" output="false" returntype="string" hint="Takes two lists, one with '+' or '-' in front of the properties, and appends or deletes entries and returns the ammended list.">
	
	<cfargument name="list1" type="string">
	<cfargument name="list2" type="string">
	<cfargument name="appendFlag" type="string" required="false" default="+">
	<cfargument name="deleteFlag" type="string" required="false" default="-">
	<cfargument name="delimiters" type="string" required="false" default=",">
	
	<cfset var i = "">
	
	<cfloop list="#arguments.list2#" index="i" delimiters="#arguments.delimiters#">
	
		<cfif Left(i,1) EQ arguments.appendFlag>
			<cfset i = ReplaceNoCase(i,arguments.appendFlag,"")>
			<cfset arguments.list1 = ListAppend(arguments.list1,i,arguments.delimiters)>
		<cfelseif Left(i,1) EQ arguments.deleteFlag>
			<cfset i = ReplaceNoCase(i,arguments.deleteFlag,"")>
			<cfset arguments.list1 = this.fnListDelete(arguments.list1,i)>
		</cfif>
	
	</cfloop>
	
	<cfreturn arguments.list1>
	
</cffunction>

<cffunction name="fnListNextVal" output="false" returntype="string" hint="Get next value from a list given a current value. NB returns blank string if there are no more records (can return first value with wrap = 1)">
	
	<cfargument name="list" type="string" required="true">
	<cfargument name="val" type="string" required="true">
	<cfargument name="wrap" type="boolean" required="false" default="0" hint="Return first ID instead of blank if no more records">
	
	<cfset var sLocal = StructNew()>
	<cfset  local.res = "">

	<cfset local.pos = ListFind(arguments.list,arguments.val)>

	<cfif local.pos>
		
		<cfif local.pos eq ListLen(arguments.list)>
			<cfif arguments.wrap>
				<cfset local.nextpos = 1>
			<cfelse>
				<cfset local.nextpos = 0>
			</cfif>
		<cfelse>
			<cfset local.nextpos = local.pos + 1>
		</cfif>
	<cfelse>
		<cfset local.nextpos = 0>
	</cfif>

	<cfif local.nextpos>
		<cfset local.res = ListGetAt(arguments.list,local.nextpos)>
	</cfif>

	<cfreturn local.res>

</cffunction>

<cffunction name="fnListPrevVal" output="false" returntype="string" hint="Get previous value from a list given a current value. NB returns blank string if there are no more records (can return first value with wrap = 1)">
	
	<cfargument name="list" type="string" required="true">
	<cfargument name="val" type="string" required="true">
	<cfargument name="wrap" type="boolean" required="false" default="0" hint="Return first ID instead of blank if no more records">
	
	<cfset var sLocal = StructNew()>
	<cfset  local.res = "">

	<cfset local.pos = ListFind(arguments.list,arguments.val)>

	<cfif local.pos>
		
		<cfif local.pos eq 1>
			<cfif arguments.wrap>
				<cfset local.nextpos = ListLen(arguments.list)>
			<cfelse>
				<cfset local.nextpos = 0>
			</cfif>
		<cfelse>
			<cfset local.nextpos = local.pos - 1>
		</cfif>
	<cfelse>
		<cfset local.nextpos = 0>
	</cfif>

	<cfif local.nextpos>
		<cfset local.res = ListGetAt(arguments.list,local.nextpos)>
	</cfif>

	<cfreturn local.res>

</cffunction>

<cffunction name="fnQueryNextKey" output="true" returntype="string" hint="Given a query, a fieldname and a field value, determines the value of the field in the next row
 after the row in which the current value matches. Obviously the field is intended to be the primary key but it will work on any unique, not null
 and non blank column. NB returns blank string if there are no more records (can return first value with wrap = 1)">
	
	<cfargument name="sQuery" type="query" required="true">
	<cfargument name="fieldname" type="string" required="true">
	<cfargument name="fieldValue" type="string" required="true">
	<cfargument name="wrap" type="boolean" required="false" default="0" hint="Return first ID instead of blank if no more records">
	
	<cfset var sLocal = StructNew()>
	
	<cfset sLocal.rowNum = 0>
	
	<cfloop query="arguments.sQuery">
		<cfif 	arguments.sQuery[arguments.fieldname][currentrow] eq arguments.fieldValue>
			<cfset sLocal.rowNum = currentRow>
			<cfbreak>
		</cfif>
	</cfloop>
		
	<cfif NOT sLocal.rowNum>
		<cfthrow message="Field value #arguments.fieldValue# not found for field #arguments.fieldname# in query ">
	</cfif>
	
	<cfif sLocal.rowNum eq arguments.sQuery.recordcount>
		<cfif arguments.wrap>
			<cfset sLocal.nextRow = 1>
		<cfelse>
			<cfset sLocal.nextRow = 0>
		</cfif>
	<cfelse>
		<cfset sLocal.nextRow = sLocal.rowNum + 1>
	</cfif>
	
	<cfif sLocal.nextRow>
		<cfset sLocal.nextVal = arguments.sQuery[arguments.fieldname][sLocal.nextRow]>
	<cfelse>
		<cfset sLocal.nextVal = "">
	</cfif>
	
	
	<cfreturn sLocal.nextVal>
	
</cffunction>

<cffunction name="fnQueryPreviousKey" output="true" returntype="string" hint="Given a query, a fieldname and a field value, determines the value of the field in the next row
 before the row in which the current value matches. Obviously the field is intended to be the primary key but it will work on any unique, not null
 and non blank column. NB returns blank string if there are no more records (can return last value with wrap = 1)">
	
	<cfargument name="sQuery" type="query" required="true">
	<cfargument name="fieldname" type="string" required="true">
	<cfargument name="fieldValue" type="string" required="true">
	<cfargument name="wrap" type="boolean" required="false" default="0" hint="Return first ID instead of blank if no more records">
	
	<cfset var sLocal = StructNew()>
	
	<cfset sLocal.rowNum = 0>
	
	<cfloop query="arguments.sQuery">
		<cfif 	arguments.sQuery[arguments.fieldname][currentrow] eq arguments.fieldValue>
			<cfset sLocal.rowNum = currentRow>
			<cfbreak>
		</cfif>
	</cfloop>
		
	<cfif NOT sLocal.rowNum>
		<cfthrow message="Field value #arguments.fieldValue# not found for field #arguments.fieldname# in query ">
	</cfif>
	
	<cfif sLocal.rowNum eq 1>
		<cfif arguments.wrap>
			<cfset sLocal.nextRow = arguments.sQuery.recordcount>
		<cfelse>
			<cfset sLocal.nextRow = 0>
		</cfif>
	<cfelse>
		<cfset sLocal.nextRow = sLocal.rowNum - 1>
	</cfif>
	
	<cfif sLocal.nextRow>
		<cfset sLocal.nextVal = arguments.sQuery[arguments.fieldname][sLocal.nextRow]>
	<cfelse>
		<cfset sLocal.nextVal = "">
	</cfif>
	
	
	<cfreturn sLocal.nextVal>
	
</cffunction>

<cffunction name="fnSqlServerTypeToColdfusionSqlType" output="false" returntype="string" hint="Returns a string for a Coldfusion datatype given an SQL server data type. Defaults to VARCHAR.">
	
	<cfargument name="DATA_TYPE">
	
	<cfswitch expression="#arguments.DATA_TYPE#">
		<cfcase value="int">
			<cfreturn "cf_sql_integer">
		</cfcase>
		<cfcase value="bit">
			<cfreturn "cf_sql_bit">
		</cfcase>
		<cfdefaultcase>
			<cfreturn "cf_sql_varchar">
		</cfdefaultcase>
	</cfswitch>
	
</cffunction>

<cffunction name="fnGetMIMETypeFromExtension" output="false"  returntype="string" hint="Return mime type for given extension. Uses data configured in mimeTypes.txt">

	<cfargument name="extension" required="yes">
		
	<cfset var mimeType = "">

	<!--- remove . from front of extensions --->
	<cfset arguments.extension = ListLast(arguments.extension,".")>	
		
    <cfif NOT ISDefined("this.mimeMappings")>
		<cfif NOT (IsDefined("variables.mappings") AND StructKeyExists(variables.mappings,"utils"))>
			<cfthrow message = "Object must be initialised with a mapping for 'utils' to use this function">
		</cfif>
		
		<cfset this.mimeMappings = fnLoadSettingsFromFile("utils/mimeTypes.txt")>
		
	</cfif>
			
	<cfif StructKeyExists(this.mimeMappings,arguments.extension)>
		<cfset mimeType = this.mimeMappings[arguments.extension]>
	</cfif>

	<cfreturn mimeType>
	
</cffunction>

<cffunction name="fnGetLogSettings" output="false" returntype="Struct">
	<cfset var logSettings = {}>
	<cfset var s = ''>

	<cfloop list="log,logCategories,log_mode,logLineInfo,log_dsn" index="s">
		<cfif structKeyExists(variables, s)>
			<cfset logSettings[s] = variables[s]>
		</cfif>
	</cfloop>
	<cfreturn logSettings>
</cffunction>

<cffunction name="fnLog" output="yes" returntype="void" hint="Write to log (if this.log is true) or just trace if in debug mode."> 

	<cfargument name="text" required="Yes" hint="Text to log">
	<cfargument name="type" required="No" default="Information" hint="The type of logging">
	<cfargument name="category" required="No" default="" hint="List of categories to log. See fnAddLogCategory. Blank will log if all is on.">
	
	<cfset var context = []>
	
	<!--- log all errors and warnings --->
	<cfswitch expression="#arguments.type#">
		<cfcase value="warning,w,error,e">
			<cfset local.log = 1>
		</cfcase>
		<cfdefaultcase>
			<cfset local.log = 0>
		</cfdefaultcase>
	</cfswitch>

	<!--- are we loggin all categories? --->
	<cfset local.log = local.log OR (variables.log AND StructKeyExists(variables.logCategories,"all"))>

	<cfif NOT local.log>
		<cfif variables.log>
			<cfloop index="local.cat" list="#arguments.category#">
				<cfif structKeyExists(variables.logCategories, local.cat)>
					<cfset local.category = local.cat>
					<cfset local.log = 1>
					<cfbreak>
				</cfif>
			</cfloop>
		</cfif>
	<cfelse>
		<cfset local.category = ListFirst(arguments.category)>
	</cfif>

	<cfif local.log>
		<!--- If in debug mode, get a stack trace so we can add file/line information to the logging --->
		<cfif IsDebugMode() AND variables.logLineInfo>
			<cftry>
				<cfthrow message="Get stack trace">
				<cfcatch>
					<cfset context = cfcatch.tagcontext>
				</cfcatch>
			</cftry>
			
			<cfif arrayLen(context) gt 1>
				<cfset arguments.text &= "(#context[2].template#:#context[2].line#)">
			</cfif>
		</cfif>
		
		<cfif variables.log_mode eq "db">

			<!--- request_id allows all log entries from the same request to be viewed --->
			<cfparam name="request.logrunID" default="#createUUID()#">

			<cfif arguments.category eq "">
				<cfset local.categoryNULL = 1>
			<cfelse>
				<cfset local.categoryNULL = 0>
			</cfif>
			<cfquery datasource="#variables.log_dsn#" name="local.insertLog">
			INSERT INTO [cflog]
           ([logtype]
           ,[cflog_category]
           ,[log_text]
           ,[server_name]
           ,request_id)
     		VALUES
           (<cfqueryparam cfsqltype="cf_sql_char" value="#UCASE(Left(arguments.type,1))#">
           ,<cfqueryparam cfsqltype="cf_sql_varchar" value="#local.category#" null="#local.categoryNULL#">
           ,<cfqueryparam cfsqltype="cf_sql_varchar" value="#Left(arguments.text,8000)#">
           ,<cfqueryparam cfsqltype="cf_sql_varchar" value="#cgi.server_name#">
           ,<cfqueryparam cfsqltype="cf_sql_varchar" value="#request.logrunID#">)
           </cfquery>

		<cfelseif isDebugMode() AND (NOT IsDefined("_cf_nodebug") OR NOT (_cf_nodebug))>
			<cftrace text="#arguments.text#">
		<cfelseif variables.log>
			<cflog file="#application.ApplicationName#_debug" type="#arguments.type#" text="#arguments.text#">
		</cfif>
	</cfif>
    
</cffunction>

<cffunction name="fnSetLog" output="No" returntype="void" hint="Set the boolean variable to turn file logging on or off. Use fnAddLogCategory() be preference"> 

	<cfargument name="log" required="no" type="boolean" default="true" hint="Boolean to turn logging on or off.">
	<cfargument name="categories" required="no" default="all"  hint="Categories to filter on (supply a list of catgeories here and a category param to fnLog to
	filter log requests">
	<cfargument name="lineInfo" required="no" default="false" hint="Turn on addition of lineInfo (calling file and line number) to traces">
	<cfargument name="mode" required="no" default="text" hint="text|db">
	<cfargument name="dsn" required="no" default="" hint="Required if mode = db">
	
	
	<cfset variables.log = arguments.log>
	<cfset variables.logCategories = {}>

	<cfif variables.log>
		<cfloop index="local.cat" list="#arguments.categories#">
			<cfset variables.logCategories[local.cat] = 1>
		</cfloop>
	</cfif>

	<cfset variables.logLineInfo = arguments.lineInfo>
	
	<cfif variables.log AND arguments.mode eq "db" AND arguments.dsn eq "">
		<cfthrow message="No dsn defined for log mode">
	</cfif>

	<cfset variables.log_mode = arguments.mode>
	<cfset variables.dsn = arguments.dsn>

</cffunction>

<cffunction name="fnSetDBLogMode" output="no" returntype="void" hint="Turn on logging to database. Requires DSN - and sql log tables (see create_log_tables.sql)"> 

	<cfargument name="DBLogMode" required="no" type="boolean" default="true" hint="Boolean to turn DB logging on or off.">
	<cfargument name="dsn" required="no" hint="required if turning on" >

	<cfif arguments.DBLogMode>
		<cfif NOT IsDefined("arguments.dsn") OR arguments.dsn eq "">
			<cfthrow message="DSN required if turning on DB log mode">
		</cfif>
		<cfset variables.log_dsn = arguments.dsn>
		<cfset variables.log_mode = "db">
		<cfset variables.log = 1>
	<cfelse>
		<cfset variables.log_mode = "text">
	</cfif>
		
</cffunction>

<cffunction name="fnAddLogCategory" output="No" returntype="void" hint="Add a category to logging. If logging is off, we turn it on. If category is all, leave this."> 

	<cfargument name="category" required="yes" hint="Categories to add">
	
	<cfloop index="local.cat" list="#arguments.category#">
		<cfif len(local.cat) gt 20>
			<cfthrow message="Category must be 20 chars or less">
		</cfif>
		<cfset variables.logCategories[local.cat] = 1>
	</cfloop>
	
	<cfset variables.log = 1>
		
</cffunction>

<cffunction name="fnRemoveLogCategory" output="No" returntype="boolean" hint="Remove a category from logging. If last category, turn logging off. Returns false if not found"> 

	<cfargument name="category" required="yes" hint="Categories to add">
	
	<cfset local.loggingFound = 0>

	<cfloop index="local.cat" list="#arguments.category#">
		<cfset local.loggingFound = local.loggingFound OR StructDelete(variables.logCategories,local.cat)>
	</cfloop>

	<cfif NOT StructCount(variables.logCategories)>
		<cfset variables.log = 0>
	</cfif>


	<cfreturn local.loggingFound>
		
</cffunction>

<cffunction name="fnViewLog" output="true" hint="Output log entries for current request"> 

	<cfargument name="category" default="">
	<cfargument name="server" required="false">
	
	<cfif NOT StructKeyExists(request,"logrunID") AND NOT structKeyExists(arguments, "server")>
		<p>No log entries for this request</p>
	<cfelse>	
	
		<cfquery datasource="#variables.log_dsn#" name="local.qLog">
		SELECT [logtime]
	          ,[logtype]
	          ,[cflog_category]
	          ,[log_text]
	          ,[server_name]
     	FROM     cflog WITH (NOLOCK)
     	<cfif structKeyExists(arguments, "server")>
     	WHERE	server_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.server#">
     	<cfelse>
     	WHERE    request_id = <cfqueryparam cfsqltype="cf_sql_varchar" value="#request.logrunID#">
     	</cfif>
     	<cfif arguments.category neq "">
     	AND     cflog_category IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.category#" list="yes">)
     	</cfif>
     	ORDER by logtime_exact
        </cfquery>

		<table class="info" border="1" cellpadding="2" cellspacing="0" style="background-color: white; color: black;">
			<tr>
				<th>Time</th>
				<th>Type</th>
				<th>Cat</th>
				<th>Text</th>
			</tr>
		<cfloop query="local.qLog">
			<tr>
				<td>#logtime#</td>
				<td>#logtype#</td>
				<td>#cflog_category#</td>
				<td style="padding-left:5px; text-align:left;">#log_text#</td>
			</tr>
		</cfloop>
		</table>
    </cfif>

</cffunction>

<cffunction name="fnWritePackageCompressionFile" output="false" returntype="void" hint="write a file to compress packages on servers">
	<cfargument name="batchFile" type="string" required="true" hint="Path to the batch file.">
	<cfargument name="servers_roles_ids" type="string" default="1,2,3,4" required="false" hint="Servers roles to include in this script">

	<cfset var local = {}>

	<cfset local.serversList = ''>

	<cfquery datasource="#application.settings.dsn#" name="local.qServers">
	SELECT		s.servers_id, s.name
	FROM		servers s WITH (NOLOCK)
	INNER JOIN 	servers_servers_roles_join SSJ
	ON			S.servers_id = SSJ.servers_id
	WHERE		SSJ.servers_roles_id in (<cfqueryparam value="#arguments.servers_roles_ids#" list="true" cfsqltype="cf_sql_integer">)
	GROUP BY 	s.servers_id, s.name
	ORDER BY	s.name
	</cfquery>

	<cfloop query="local.qServers">
		<cfset local.serversList = listAppend(local.serversList, '"#ListFirst(name,'.')#"', ',')>
	</cfloop>
<cfsavecontent variable="local.fileContent">
' This script will compress JS and CSS packages on all production servers.
' It is intended to be run after servers_copy.
' USAGE:
'  	simply provide a list of servers below. Then run from the comman line using `cscript compressPackages.vbs`

' Provide list of servers to compress scripts on. This should be the server prefixes only!
servers = Array (<cfoutput>#local.serversList#</cfoutput>)
' servers = Array ("tpc22")

' Unfortunately VB doesn't know try-catch, so have to employ some other magic to cope with unavailable servers ...
On Error Resume Next
Err.Clear ' make sure we are starting with an empty slate
' initialize some counters
errors = 0
total = 0
' We will set this to true if we need compression
needJsComp = false
needCssComp = false

Wscript.Echo "+-----------------------------------+"
Wscript.Echo "| COMPRESS PACKAGES FILES IF NEEDED |"
Wscript.Echo "+-----------------------------------+"
Wscript.Echo ""

' Check _common/_scripts and _common/_styles folder (and sub folder) for files: We only want to selectively compress as needed

Set objFSO = CreateObject("Scripting.FileSystemObject")

Wscript.Echo "Checking _scripts folder"
Call CheckFolder(".\wwwroot\_common\_scripts")

Wscript.Echo "Checking _styles folder"
Call CheckFolder(".\wwwroot\_common\_styles")

Wscript.Echo ""
Wscript.Echo "Need JS compression:  " & needJsComp 
Wscript.Echo "Need Css compression: " & needCSSComp

If needJsComp OR needCssComp Then

	' Loop over the servers
	for each s in servers
		total = total+1
		
		'set URL (append a randum number to avoid caching)
		reloadURL = "https://"& s &".clikpic.com/manage/reload.cfm?cache="&Rnd

		' now append arguments to compress as needed
		If needJsComp Then
			reloadURL = reloadURL & "&compressScripts=1"
		End If

		If needCssComp Then
			reloadUrl = reloadUrl & "&compressCss=1"
		End If

		WScript.Echo ""
		WScript.Echo "Compressing Packages on " & s
		' WScript.Echo "URL: " & reloadURL

		' Download the specified URL
		Set objHTTP = CreateObject( "WinHttp.WinHttpRequest.5.1" )
		objHTTP.Open "GET", reloadURL, False
		objHTTP.Send

		' check if request was successfull, otherwise show error
		If Err.Number <> 0 Then
		    WScript.Echo "   Error: " &  Err.Description
			Err.Clear ' clear errors
			errors = errors + 1
		Else
			' Output what happened
			' WScript.Echo objHTTP.ResponseText
			If objHTTP.Status = 200 Then
			  WScript.Echo "    OK    (" & objHTTP.Status & ")"
			Else
			  WScript.Echo "    ERROR (" & objHTTP.Status & ": '"& objHTTP.StatusText &"')"
			  errors = errors + 1
			End If
		End If
	next

	WScript.Echo ""
	WScript.Echo "Done compressing Packages on "&total&" server(s) with "&errors&" errors"
End If


' Check a folder for existence, and then check if it or its sub folders contain any JS or CSS files
Sub CheckFolder(path)
	If objFSO.FolderExists(path) Then
		Set objSuperFolder = objFSO.GetFolder(path)
		Call checkSubForFiles (objSuperFolder)
	Else
		Wscript.Echo " ! Folder '"&path&"' doesn't exist"
	End If
End Sub

' Loop recursively through a folder to see if it contains CSS or JS files
Sub checkSubForFiles(fFolder)
    Set objFolder = objFSO.GetFolder(fFolder.Path)
    Set colFiles = objFolder.Files
    For Each objFile in colFiles
        If UCase(objFSO.GetExtensionName(objFile.name)) = "JS" Then
            needJsComp = true
        ElseIf UCase(objFSO.GetExtensionName(objFile.name)) = "CSS" Then
            needCssComp = true
        End If
    Next

    For Each Subfolder in fFolder.SubFolders
        checkSubForFiles(Subfolder)
    Next
End Sub
</cfsavecontent>
<cffile action="WRITE" file="#arguments.batchFile#" output="#local.fileContent#">

</cffunction>


<cffunction name="fnWriteDistributionBatchFile" output="false" returntype="void" hint="Write a batch file to distribute content between servers in the workgroup.">
	
	<cfargument name="servers" type="struct" required="true" hint="Struct of server details e.g. from Clikpic object.">
	<cfargument name="serverSettings" type="struct" required="true" hint="Struct of settings for different servers e.g. from clikpic.ini">
	<cfargument name="batchFile" type="string" required="true" hint="Path to the batch file.">
	<cfargument name="pathMapping" type="struct" required="false" hint="Struct mapping directories in the distribution root to paths on the servers.">
	<cfargument name="addPrompt" type="boolean" required="false" default="false" hint="Write a prompt into the file?">
	<cfargument name="packageCompressionScript" type="string" required="false" hint="file name of package compression script to call">
	<cfset var local = {}>
	
	<!--- Start the file. --->
	<cfoutput>
		<cfsavecontent variable="local.fileContent">
REM	#DateFormat(now(),"medium")#
REM Copy files from the directory structure to all other servers
		</cfsavecontent>
	</cfoutput>
	
	<cffile action="WRITE" file="#arguments.batchFile#" output="#local.fileContent#">
	
	<!--- Add a prompt to the start of the script. --->
	<cfsavecontent variable="local.fileContent">
		<cfif arguments.addPrompt>
SET /P ANSWER=Continue with distribution (Y/N)?
if /i {%ANSWER%}=={y} (goto :yes)
if /i {%ANSWER%}=={yes} (goto :yes)
goto :no
:yes
		</cfif>
echo Starting distribution...
	</cfsavecontent>
	
	<cffile action="APPEND" file="#arguments.batchFile#" output="#local.fileContent#">
	
	<cfset local.thisServerSettings = arguments.serverSettings[server.server_name]>
	
	<!--- Loop over the list of servers loaded into the object. --->
	<cfloop collection="#arguments.servers#" item="local.servers_id">
	
		<!--- Set a struct of settings for the server, either from the Clikpic object or create a blank one. --->
		<cfif StructKeyExists(arguments.serverSettings,arguments.servers[local.servers_id].name)>
			
			<cfset local.tmpSettings = arguments.serverSettings[arguments.servers[local.servers_id].name]>
			
			<!--- Combine the settings for the server with the common ones. --->
			<cfset local.success = StructAppend(tmpSettings,arguments.serverSettings.common)>
			
			<!--- Set a variable for the netbios name - just convenience. --->
			<cfset local.netbios_name = arguments.servers[local.servers_id].netbios_name>
			
			<!--- If there's a netbios name then we can copy files over to it. --->
			<cfif local.netbios_name NEQ "">
				<cfoutput>
					<!--- Add in xcopy directives for the webroot, the customtags and the settings for each server. --->
					<cfsavecontent variable="local.fileContent">
						<cfif StructKeyExists(arguments,"pathMapping")>
							<cfloop collection="#arguments.pathMapping#" item="local.dataRoot">
								<cfif StructKeyExists(local.tmpSettings,arguments.pathMapping[local.dataRoot])>
									<cfset local.location = local.tmpSettings[arguments.pathMapping[local.dataRoot]]>
								<cfelse>
									<cfset local.location = arguments.pathMapping[local.dataRoot]>
								</cfif>
								<cfif arguments.servers[local.servers_id].name EQ server.server_name>
xcopy #local.thisServerSettings.dataroot#\#local.dataRoot#\*.*  #local.location# /E /I /R /Y								
								<cfelse>
xcopy #local.thisServerSettings.dataroot#\#local.dataRoot#\*.*  \\#local.netbios_name#\#ReplaceNoCase(local.location,":","$")# /E /I /R /Y
								</cfif>
								
							</cfloop>
							
						<cfelse>
							<cfif arguments.servers[local.servers_id].name EQ server.server_name>
xcopy #local.thisServerSettings.dataroot#\wwwroot\*.*  #local.thisServerSettings.siteroot# /E /I /R /Y
xcopy #local.thisServerSettings.dataroot#\customtags\*.*  #local.thisServerSettings.customtags# /E /I /R /Y
xcopy #local.thisServerSettings.dataroot#\settings\*.*  #local.thisServerSettings.settings# /E /I /R /Y
							<cfelse>
xcopy #local.thisServerSettings.dataroot#\wwwroot\*.*  \\#local.netbios_name#\#ReplaceNoCase(local.tmpSettings.siteroot,":","$")# /E /I /R /Y
xcopy #local.thisServerSettings.dataroot#\customtags\*.*  \\#local.netbios_name#\#ReplaceNoCase(local.tmpSettings.customtags,":","$")# /E /I /R /Y
xcopy #local.thisServerSettings.dataroot#\customtags\*.*  \\#local.netbios_name#\#ReplaceNoCase(local.tmpSettings.settings,":","$")# /E /I /R /Y
							</cfif>
						</cfif>						
					</cfsavecontent>
				</cfoutput>
				
				<!--- Append the script to the batch file. --->
				<cffile action="APPEND" file="#arguments.batchFile#" output="#local.fileContent#">
			</cfif>
		
		<cfelse>
			<cfset this.fnLog("No settings found for #local.servers_id#: #arguments.servers[local.servers_id].name#")>
		</cfif>
		
	</cfloop>
	
	<!--- append call for compression script --->
	<cfif structKeyExists(arguments, "packageCompressionScript") AND arguments.packageCompressionScript neq ''>
		<cffile action="APPEND" file="#arguments.batchFile#" output="#chr(10)##chr(13)#cscript #arguments.packageCompressionScript#">
	</cfif>
	
	<cfif arguments.addPrompt>
		<!--- Add the end of the prompt logic to the end of the file. --->
		<cfsavecontent variable="local.fileContent">
exit /b 0

:no
echo Distribution cancelled.
exit /b 1
		</cfsavecontent>
		
		<cffile action="APPEND" file="#arguments.batchFile#" output="#local.fileContent#">
	</cfif>
		
</cffunction>

<cffunction name="fnHTMLAttrFormat" output="No" returntype="string" hint="Format a string to be displayed in a tag attribute - escape quotes, strip out html tags etc">
	
	<cfargument name="string" type="string" required="true" hint="The string to format">
	<cfset var local = {}>
	
	<cfif find("<",arguments.string)>
		<cfset arguments.string = rereplace(arguments.string, "<[^>]+>", "", "all")>
	</cfif>
	
	<cfset local.out = HTMLEditFormat(arguments.string)>
	
	<cfreturn local.out>

</cffunction>

<cffunction name="fnUploadFile" output="No" returntype="struct" hint="Upload a file">
	
	<cfargument name="formFile" type="string" required="true" hint="Field of upload">
	<cfargument name="directory" type="string" required="true" hint="Directory to upload to">
	<cfargument name="accept" type="string" required="no" default="jpg,gif,png,pdf" hint="EXTENSIONS of mime types to accept (see fnGetMIMETypeFromExtension)">
	<cfargument name="nameConflict" type="string" required="no" default="MakeUnique" hint="Action to take on name conflict Error|Skip|overwrite|makeUnique">
	
	<cfset var local = {}>
	<cfset local.file = {}>
		
	<cfset local.MimeTypes = "">
	<cfloop index="local.ext" list="#arguments.accept#">
		<cfset local.MimeTypes = ListAppend(local.MimeTypes,fnGetMIMETypeFromExtension(local.ext))>
	</cfloop>
		
	<cftry>
		<cffile action="upload" fileField="#arguments.formField#"
								destination="#arguments.directory#"
								accept="#local.MimeTypes#"
								nameConflict="#arguments.nameConflict#"
								result="local.file">
		
		<cfcatch>
			<cfset local.file.fileWasSaved = 0>
			<cfset local.file.error = Duplicate(cfcatch)>	
		</cfcatch>
	</cftry>
	
	<cfreturn local.file>
	
</cffunction>

<cffunction name="fnRenameFile" output="No" returntype="struct" hint="Rename a file.">
	
	<cfargument name="source" type="string" required="true" hint="File to rename">
	<cfargument name="destination" type="string" required="true" hint="Destination file or directory.">
			
	<cfset var local = {}>
	<cfset local.file = {}>
		
	<cfif NOT FileExists(arguments.source)>
		<cfset local.file.fileWasSaved = 0>
		<cfset local.file.error.message = "File #arguments.source# not found">
	<cfelse>
		
		<cftry>
			<cffile action="rename" source="#arguments.source#"
									destination="#arguments.destination#">
			
			<cfcatch>
				<cfset local.file.fileWasSaved = 0>
				<cfset local.file.error = Duplicate(cfcatch)>	
			</cfcatch>
		</cftry>
	</cfif>
	
	<cfreturn local.file>
	
</cffunction>

<cffunction name="alphanumeric" output="No" returntype="string" hint="Replace non alphanumeric chars in a filename">
	<cfargument name="filename" type="string" required="true" hint="Filename to check">
	
	<cfset local.tempName = ListFirst(arguments.filename,".")>
	<cfset local.tempExt = ListLast(arguments.filename,".")>
	<cfset local.tempName = Replace(local.tempName," ","_","all")>
	<cfset local.checkName = REReplace(local.tempName,"[^\w_\-\.]","","all") & "." & local.tempExt>
	
	<cfreturn local.checkName>

</cffunction> 

<cffunction name="websafeFileName" output="No" returntype="struct" hint="Make filename websafe. Will append numeric value if the resultant string is not unique.">
	
	<cfargument name="source" type="string" required="true" hint="File to check and rename if required.">
			
	<cfset var i = false>
	<cfset local.file = {}>
	
	<cfset local.file.fileOk = 1>
	<cfset local.file.fileExisted = 0>
	<cfset local.file.fileWasRenamed = 0>
		
	<cfif NOT FileExists(arguments.source)>
		<cfset local.file.fileOk = 0>	
		<cfset local.file.error.message = "File #arguments.source# not found">
	<cfelse>
		
		<cfset local.sourceFile = ListLast(arguments.source,"\/")>
		<cfset local.checkName = alphanumeric(local.sourceFile)>
		
		<cfset this.fnLog(text="fnWebsafeFileName= checkName is #local.checkName#")>
		
		<cfif (local.sourceFile neq local.checkName)>
			
			<cfset local.destinationDir = GetDirectoryFromPath(arguments.source)>
				
			<cfif FileExists("#local.destinationDir#\#local.checkName#")>
				<cfset local.file.fileExisted = 1>
				<cfloop index="i" from="1" to="10000">
					<cfset local.checkName2 = Replace(local.checkName,".","#i#.")>
					<cfif NOT FileExists("#local.destinationDir#\#local.checkName2#")>
						<cfset local.checkName = local.checkName2>
						<cfbreak>
					</cfif>
				</cfloop>
			</cfif>
					
			<cftry>
				<cffile action="rename" source="#arguments.source#"
									destination="#local.checkName#">
				<cfset local.file.fileWasRenamed = 1>
				<cfcatch>
					<cfset local.file.fileOk = 0>
					<cfset local.file.error = Duplicate(cfcatch)>	
				</cfcatch>
			</cftry>		
					
			
		</cfif>
		
		<cfif local.file.fileOk>
			<cfset local.file.serverFile = local.checkName>
		</cfif>				
	</cfif>
	
	<cfreturn local.file>
	
</cffunction>	

<!--- fnFileSize deprecated, use fileInfo --->

<cffunction name="pad" hint="Pad a string to a given length (and trim)">
	<cfargument required="yes" name="str">
	<cfargument required="yes" name="length">
	<cfargument required="no" name="trim" type="boolean" default="1" hint="trim if too long">
	
	<cfscript>
	var retval = Lpad(arguments.str,arguments.length);
	if (len(arguments.str) gt arguments.length AND arguments.trim) {
		retval = left(retval,arguments.length);
	}	
	return retVal;
	</cfscript>
</cffunction>

<cffunction name="fnParseTagAttributes" output="No" returntype="Struct" hint="Parse attributes into a struct from a single tag string (e.g. [image id=xx]). Tag can be < or << or [ or [[ enclosed. Attributes can be single quoted, double quote or alpha numeric">
		
	<cfargument name="text" type="string" required="Yes" hint="The full tag string (start tag only, tag name ignored).">
		
	<cfscript>
	var temp = StructNew();
	var stext = ReplaceList(arguments.text,"����","',',','");
	var stext = ListFirst(Trim(stext),"[]<>");
	var attrVals = ListRest(sText," ");

	if (NOT IsDefined("variables.attrPattern")) {
		local.patternObj = createObject( "java", "java.util.regex.Pattern");
		local.myPattern = "(\w+)(\s*=\s*(""(.*?)""|'(.*?)'|([^'"">\s]+)))";
		variables.attrPattern = local.patternObj.compile(local.myPattern);
	}

	local.tagObjs = variables.attrPattern.matcher(attrVals);

	while (local.tagObjs.find()){
	    temp[tagObjs.group(javacast("int",1))] = reReplace(tagObjs.group(javacast("int",3)), "^(""|')(.*?)(""|')$", "\2");
	}

	return temp;
	</cfscript>

</cffunction>

<cffunction name="fnParseTagValues" output="No" returntype="string" hint="Parse value of a tag">
	
	<cfargument name="text" type="string" required="Yes" hint="The text to search">
	<cfargument name="tagName" type="string" required="No">
	
	<cfscript>
	var retVal = "";
	var SearchVals = false;
	arguments.text = Trim(arguments.text);
	
	// if (left(arguments.text,1) neq "[") {
	// 	writeDump(arguments.text);
	// 	writeOutput("not ok");
	// 	abort;
	// }
	// else {
	// 	writeOutput("ok");
	// 	abort;
	// }

	if (NOT StructKeyExists(arguments,"tagName")){
	 	SearchVals = REMatch("^(\[{1,2}|<)\w+",arguments.text);
	 	if (ArrayLen(SearchVals)) {
	 		arguments.tagName = SearchVals[1];
	 		arguments.tagName = ListFIrst(arguments.tagName,"[]>");
		}
		else {
			throw(message="Unable to parse tag name");
		}
	 	
	}
	// don't bother trying to do this with forward look ups -- they're too buggy (cf9)
	arguments.text = reReplaceNoCase(arguments.text, "(\[{1,2}|<)\/?#arguments.tagName#.*?(\]{1,2}|>)", "", "all");
	
	return arguments.text;
	</cfscript>
	
</cffunction>

<cffunction name="fnGetSqlContainsString" output="no" returntype="struct" hint="Convert google-esque search string to sql contains_search_condition">

	<cfargument name="q" type="string" required="true" hint="Search string">

	<cfset var local = {}>
	
	<!--- add a space at beginning if first item is quoted, so that list splitting works correctly --->
	<cfset local.q = reReplace(trim(arguments.q),"^"""," """)>
	<cfset local.q = reReplace(local.q, "[\(\)]", " ", "all")>
	<cfset local.q = lCase(local.q)>
	<cfset local.searchString = "">
	<cfset local.searchStringNegatives = "">
	<cfset local.nextIsNegative = 0>
	<cfset local.nextIsInclusive = 0>
	<cfset local.nextIsNotFirst = 0>
	<!--- loop quote-delimited list - even items are within quotes, odd not --->
	<cfloop from="1" to="#listLen(local.q,"""")#" index="local.i">
		<cfset local.searchItem = trim(listGetAt(local.q,local.i,""""))>
		<cfif local.searchItem neq "">
			<cfif local.i%2>
				<!--- un-quoted string --->
				<cfset local.nextIsInclusive = 0>
				<cfset local.nextIsNegative = 0>
				<!--- remove negatives, and put into separate string for later --->
				<cfset local.neg = "((^|\s+)(-\s*|(and\s+)?not\s+)|\s*&!\s*)">
				<cfset local.searchNegatives = reMatch(local.neg & "\w+",local.q)>
				<cfloop array="#local.searchNegatives#" index="local.negative">
					<cfset local.negativeS = reReplace(local.negative,local.neg,"")>
					<cfif local.negativeS neq "">
						<cfset local.searchStringNegatives &= """" & local.negativeS & """&!">
					</cfif>
					<cfset local.searchItem = replace(local.searchItem,local.negative,"")>
				</cfloop>
				<!--- if string ends with negation, set flag for next item --->
				<cfset local.endNeg = "(\s+\-|\s+(and)?not|\s*&!)$">
				<cfif reFind(local.endNeg,local.searchItem)>
					<cfset local.nextIsNegative = 1>
					<cfset local.searchItem = reReplace(local.searchItem,local.endNeg,"")>
				</cfif>
				<!--- and similar for inclusivity --->
				<cfset local.endInc = "(\s+and|\s*[&\+])$">
				<cfif reFind(local.endInc,local.searchItem)>
					<cfset local.nextIsInclusive = 1>
					<cfset local.searchItem = reReplace(local.searchItem,local.endInc,"")>
				</cfif>
				<cfif local.searchItem neq "">
					<cfset local.searchItem = """" & local.searchItem>
					<!--- put and/or between each word as appropriate --->
					<cfset local.searchItem = reReplace(local.searchItem, "(^|\b)([^\w\s]*)\s*(and\s+|[&\+]\s*)","\1\2""&""","all")>
					<cfset local.searchItem = reReplace(local.searchItem,"\s+(or\s+)?","""|""","all")>
					<!--- and at the beginning if necessary --->
					<cfset local.searchItem = reReplace(local.searchItem, "^""(&|\|)", "\1")>
					<cfif local.nextIsNotFirst>
						<cfif NOT reFind("^(&|\|)",local.searchItem)>
							<cfif local.nextIsInclusive>
								<cfset local.searchItem = "&" & local.searchItem>
							<cfelse>
								<cfset local.searchItem = "|" & local.searchItem>
							</cfif>
						</cfif>
					<cfelse>
						<cfset local.searchItem = reReplace(local.searchItem, "^(&|\|)", "")>
					</cfif>
					<cfset local.nextIsNotFirst = 1>
					<cfset local.searchString &= local.searchItem & """">
				</cfif>
			<cfelse>
				<!--- quoted string - just put in quotes, with appropriate operators --->
				<cfif local.nextIsNegative>
					<cfset local.searchStringNegatives &= """" & local.searchItem & """&!">
				<cfelse>
					<cfif local.nextIsNotFirst>
						<cfif local.nextIsInclusive>
							<cfset local.searchString &= "&">
						<cfelse>
							<cfset local.searchString &= "|">
						</cfif>
					</cfif>
					<cfset local.nextIsNotFirst = 1>
					<!--- quoted items go straight in, inside quotes --->
					<cfset local.searchString &= """" & local.searchItem & """">
				</cfif>
			</cfif>
		</cfif>
	</cfloop>
	
	<!--- remove trailing &! from negatives string --->
	<cfset local.searchStringNegatives = reReplace(local.searchStringNegatives,"&!$","")>
	
	<cfset local.searchInvert = 0>
	<cfif local.searchStringNegatives neq "">
		<cfif local.searchString eq "">
			<cfset local.searchString = reReplace(local.searchStringNegatives,"&!","|","all")>
			<cfset local.searchInvert = 1>
		<cfelse>
			<cfset local.searchString = "(#local.searchString#)&!#local.searchStringNegatives#">
		</cfif>
	</cfif>
	
	<cfset local.ret = {string=local.searchString,invert=local.searchInvert}>
	
	<cfreturn local.ret>

</cffunction>

<cffunction name="fnGetFromStructByKeyValue" output="no" hint="Get a struct from a struct of structs, based on the value of a specific key in the substructs">
	
	<cfargument name="struct" type="struct" required="true">
	<cfargument name="key" type="string" required="true">
	<cfargument name="value" type="string" required="true">
	<cfargument name="all" type="boolean" default="no" hint="Whether to return all occurences as array, or just first">
	
	<cfscript>
	var local = {};
	local.retVal = [];
	
	local.keys = structFindValue(arguments.struct, arguments.value, "all");
	for (local.j = 1; local.j lte arrayLen(local.keys); local.j++) {
		if (listFindNoCase(arguments.key,local.keys[local.j].key)) {
			arrayAppend(local.retVal, local.keys[local.j].owner);
			if (NOT arguments.all) {
				return local.retVal[1];
			}
		}
	}
	return local.retVal;
	</cfscript>

</cffunction>

<cffunction name="fnGetAlphaCodes" output="no" hint="Return unique (nearly) alphanumeric codes">
	
	<cfargument name="length" type="numeric" required="false" default="8" hint="number of characters in code">
	<cfargument name="quantity" type="numeric" required="false" default="1" hint="Number to return. Returned as list">
	
	<cfscript>
	var local = {};
	if (NOT IsDefined("variables.alphaCodes")) {
		variables.alphaCodes = ListToArray("A,B,C,D,E,F,G,H,J,K,M,N,P,Q,R,S,T,U,V,W,X,Y,1,2,3,4,5,6,7,8,9");
	}
	
	local.retVal = ArrayNew(1);
		
	local.charTotal = ArrayLen(variables.alphaCodes);
	local.y = 0;
	for (local.j = 1; local.j lte arguments.quantity; local.j++) {
		local.num = "";
		for (local.z= 1; local.z lte arguments.length; local.z++) {
			do {
				local.k = RandRange(1,local.charTotal);
			}
			while (local.k eq local.y);
			local.num &= variables.alphaCodes[local.k];
			local.y = local.k;
		}
			ArrayAppend(local.retVal,local.num);
		
	}
	
	// convert back to simple scalar.
	if (arguments.quantity eq 1) {
		local.retVal = local.retVal[1]; 
	}
		
	return local.retVal;
	</cfscript>

</cffunction>

<cffunction name="fnIsAjaxRequest" output="false" returntype="boolean" hint="Checks the incoming request headers to see if it is an Ajax request.">
		
	<cfset var requestData = getHTTPRequestData()>
	
	<cfif StructKeyExists(requestData.headers,"X-Requested-With") 
			AND requestData.headers["X-Requested-With"] EQ "XMLHttpRequest"
			OR isDefined("request.isAjax") AND request.isAjax>
				
		<cfreturn true>
		
	<cfelse>
	
		<cfreturn false>
		
	</cfif>		
	
</cffunction>

<cffunction name="SerializeJson" output="false" returntype="string" hint="Fix a few bugs in CF's buggy native SerializeJson">
	<cfargument name="data">

	<cfset var string = SerializeJson(arguments.data)>
	<!--- Coldfusion9 returns invalid JSON - leading 0's are retained, which is not a valid JSON number value --->
	<cfset string = reReplace(string, """:\s*(0\d[\d.]*)",""":""\1""","all")>
	<!--- it also return numbers with trailing period as number which is equally invalid --->
	<cfset string = reReplace(string, "\""\:\s*(\d+\.)\s*([\,\}])",""":""\1""\2","all")>

	<cfreturn string>
</cffunction>

<!---- seems very clik specific.  You probably want to set forceReturn to true. --->
<cffunction name="fnReturnJSON" returntype="void" hint="Outputs the content as a JSON request response if an Ajax request">
	<cfargument name="data" required="true" hint="Data to return">
	<cfargument name="continue" required="false" type="boolean" default="0" hint="Do nothing if not ajax. Otherwise debug and abort (NB default is false will abort)">
	<cfargument name="content_type" required="false" type="string" default="application/json;charset=utf-8" hint="Specify a different MIME type if you want to">
    <cfargument name="forceReturn" required="false" type="boolean" default="0" hint="Always return json no matter whether ajax request or debug or whatever.">

	<cfif arguments.forceReturn OR fnIsAjaxRequest()>
		<cfset local.returnData = this.SerializeJson(arguments.data)>

		<cfcontent reset="true" type="#arguments.content_type#"> <!---   --->
		<cfoutput>#local.returnData#</cfoutput>
        <cfabort>
	<cfelseif NOT arguments.continue>
		<cfsetting showdebugoutput="true" enablecfoutputonly="true">
		<cfif IsDebugMode()>
			<cfoutput>Not Ajax request.</cfoutput>
			<cfdump var="#arguments.data#">
		</cfif>
        <cfabort>
	</cfif>
	
</cffunction>


<cffunction name="fnJsonQuery" output="false" returntype="array" hint="Takes a json serialized cf query and converts it into an array of structs">
		
		<cfargument name="data" required="true" type="struct" hint="Struct with keys columns and data">
		
		<cfset var columns = {}>
		<cfset var retdata = []>
		
		
		<cfloop index="local.row" Array="#arguments.data.data#">
			<cfset local.record = {}>

			<cfloop index="local.i" from="1" to="#ArrayLen(arguments.data.columns)#">
				<cfif ArrayIsDefined(local.row,local.i)>
					<cfset local.record[data.columns[local.i]] = local.row[local.i]>
				<cfelse>
					<cfset local.record[data.columns[local.i]] = "">
				</cfif>
			</cfloop>

			<cfset arrayAppend(retdata,local.record)>

		</cfloop>

		<cfreturn retdata>
		
</cffunction>

<cffunction name="dspTickMark" output="no" returntype="string" hint="Evaluates a condition and shows a tick mark if true or a blank if not">
	<cfargument name="condition" required="true" hint="A condition - shows tick if true, blank if not">
	<cfargument name="size" required="no" default="small" hint="Return a slightly bigger tick with 'big'">
	
	<cfset var retData = "&nbsp;">
	
	<cfif arguments.condition>
		<cfswitch expression="#arguments.size#">	
			<cfcase value="big">
			<cfset retData ="&##10004;">
			</cfcase>
			<cfdefaultcase>
			<cfset retData = "&##10003;">
			</cfdefaultcase>
		</cfswitch>
	</cfif>
	<cfreturn retData>
</cffunction>

<cffunction name="hmacEncrypt" returntype="binary" access="public" output="false">
   <cfargument name="signKey" type="string" required="true" />
   <cfargument name="signMessage" type="string" required="true" />

   <cfset var jMsg = JavaCast("string",arguments.signMessage).getBytes("iso-8859-1") />
   <cfset var jKey = JavaCast("string",arguments.signKey).getBytes("iso-8859-1") />

   <cfset var key = createObject("java","javax.crypto.spec.SecretKeySpec") />
   <cfset var mac = createObject("java","javax.crypto.Mac") />

   <cfset key = key.init(jKey,"HmacSHA1") />

   <cfset mac = mac.getInstance(key.getAlgorithm()) />
   <cfset mac.init(key) />
   <cfset mac.update(jMsg) />

   <cfreturn mac.doFinal() />
</cffunction>

<cffunction name="oauthEncodedFormat" returntype="string" output="false" hint="Encode a string for oauth (RFC3986)">
	<cfargument name="string" type="string" required="true">
	<cfreturn replacelist(urlencodedformat(string), "%2D,%2E,%5F,%7E", "-,.,_,~")>
</cffunction>

<cffunction name="parseQueryString" returntype="struct" output="false" hint="Parse a query string">
	<cfargument name="string" type="string" required="true">
	
	<cfset var local = {}>
	<cfset local.retVal = {}>
	
	<cfloop list="#arguments.string#" delimiters="&" index="local.item">
		<cfif listLen(local.item,"=") gt 1>
			<cfset local.retVal[urlDecode(listFirst(local.item,"="))] = urlDecode(listLast(local.item,"="))>
		<cfelse>
			<cfset local.retVal[urlDecode(listFirst(local.item,"="))] = "">
		</cfif>
	</cfloop>
	
	<cfreturn local.retVal>
</cffunction>

<cffunction name="structKeyListFind" output="false" returntype="boolean" hint="Check whether any of a list of keys exist in a struct">
	<cfargument name="keys" type="string" required="true">
	<cfargument name="struct" type="struct" required="true">
	<cfset var key = {}>
	<cfloop list="#arguments.keys#" index="key">
		<cfif structKeyExists(arguments.struct, key)>
			<cfreturn true>
		</cfif>
	</cfloop>
	<cfreturn false>
</cffunction>

<cffunction name="fnStructToQuery" output="false" returntype="query" hint="Convert a struct to a one-row query">
	<cfargument name="struct" type="struct" required="true">
	<cfargument name="query" default="#queryNew("")#">
	
	<cfset var local = {}>
	
	<cfloop collection="#arguments.struct#" item="local.key">
		<cfif isSimpleValue(arguments.struct[local.key])>
			<cfif isDefined("arguments.query.#local.key#")>
				<cfset local.fieldVal = arguments.struct[local.key]>
				<cfif local.fieldVal eq "NULL">
					<cfset local.fieldVal = "">
				</cfif>
				<cfset querySetCell(arguments.query, local.key, local.fieldVal)>
			<cfelse>
				<cfset local.cell = []>
				<cfset local.cell[arguments.query.recordCount+1] = arguments.struct[local.key]>
				<cfset queryAddColumn(arguments.query, local.key, iif(isNumeric(arguments.struct[local.key]) OR isBoolean(arguments.struct[local.key]), "'INTEGER'", "'VARCHAR'"), local.cell)>
			</cfif>
		</cfif>
	</cfloop>
	
	<cfreturn arguments.query>
</cffunction>

<cffunction name="fnStructToQueryCols" output="false" returntype="query" hint="Convert a struct to a two column query">
	<cfargument name="struct" type="struct" required="true">
	<cfargument name="columns" default="value,display">
	
	<cfset var local = {}>
	<cfset var tmpQuery = {}>

	<cfset local.arrKey =  Arraynew(1)>
	<cfset local.arrVal =  Arraynew(1)>

	<cfloop collection="#arguments.struct#" item="local.key">
		
		<cfset ArrayAppend(local.arrKey,local.key)>
		<cfset ArrayAppend(local.arrVal,arguments.struct[local.key])>
		
	</cfloop>
	
	<cfset local.keyType = "VarChar">
	<cfset local.valType = "VarChar">
	<cfif ListLast(ListFirst(arguments.columns),"_") eq "id">
		<cfset local.keyType = "Integer">
	</cfif>

	<cfset tmpQuery = QueryNew("")>
	<cfset queryAddColumn(tmpQuery, ListFirst(arguments.columns), local.keyType, local.arrKey)>
	<cfset queryAddColumn(tmpQuery, ListLast(arguments.columns), local.valType, local.arrVal)>	

	<cfquery name="local.bugFix" dbtype="query">
	SELECT  [#ListFirst(arguments.columns)#], [#ListLast(arguments.columns)#]
	FROM    tmpQuery
	</cfquery> 

	<cfreturn local.bugFix>

</cffunction>


<cffunction name="fnStructOfStructsToQuery" output="false" returntype="query" hint="Convert a struct of similar structs to a multi-row query (required same keys for each substruct)">
	<cfargument name="struct" type="struct" required="true">
	
	<cfset var local = {}>
	<!--- use first struct to construct query, then discard that data --->
	<cfset local.sampleRow = arguments.struct[listFirst(structKeyList(arguments.struct))]>
	
	<cfset local.query = fnStructToQuery(local.sampleRow)>
	
	<cfquery dbtype="query" name="local.query">
	SELECT	'' as ID, *
	FROM	[local].query
	WHERE	1 = 0
	</cfquery>
	
	<cfloop collection="#arguments.struct#" item="local.rowID">
		<cfset queryAddRow(local.query)>
		<cfset local.row = Duplicate(arguments.struct[local.rowID])>
		<cfset local.row.ID = local.rowID>
		<cfset fnStructToQuery(local.row, local.query)>
	</cfloop>
	
	<cfreturn local.query>

</cffunction>

<cffunction name="fnDataFileToQuery" output="false" returntype="query" hint="Convert tabbed text data file with header row to query.">

	<cfargument name="filename" required="true">	

	<cfset var local = {}>
	<cfset local.fileData = fnReadFile(arguments.filename)>
	<cfset local.strData = {}>
	<cfset local.rowNum = 1>
	<cfloop index="local.line" list="#local.fileData#"  delimiters="#chr(13)##chr(10)#">
		<cfif local.rowNum eq 1>
			<cfset local.fieldNames = ArrayNew(1)>
			<cfloop index="local.field" list="#local.line#"  delimiters="#chr(9)#">
				<cfset ArrayAppend(local.fieldNames,local.field)>
			</cfloop>
		<cfelse>
			<cfset local.Row = {}>
			<cfset local.fieldNum = 1>
			<cfloop index="local.field" list="#local.line#"  delimiters="#chr(9)#">
				<cfset local.Row[local.fieldNames[local.fieldNum]] = local.field>
				<cfset local.fieldNum += 1>
			</cfloop>
			<cfset local.strData[local.rowNum]= local.Row>
		</cfif>
		<cfset local.rowNum += 1>
	</cfloop>

	<cfset local.retQuery = fnStructOfStructsToQuery(local.strData)>

	<cfreturn local.retQuery>
</cffunction>

<cffunction name="randomRows" hint="return x different random numbers between 1 and maxrows">
	<cfargument name="maxrows" required="yes" hint="Total number of rows">	
	<cfargument name="numrows" required="yes" hint="Number of rows to return">	
	
	<cfscript>
	var i = StructNew();
	randomize(timeFormat(now(),"ssmmhh"),"SHA1PRNG");
	if (arguments.numrows gt arguments.maxrows) arguments.numrows = arguments.maxrows;
	while (StructCount(i) lt arguments.numrows) {
		i[RandRange(1,arguments.maxrows)] = 1;
	}
	return StructKeyList(i);
	</cfscript>

</cffunction>

<cffunction name="reEscape" output="no" returntype="string" hint="Escape a string for use in regex">
	<cfargument name="string" type="string" required="true">
	
	<cfreturn reReplace(string, "[.*+?^${}()|[\]/\\]", "\\\0", "ALL")>
</cffunction>

<cffunction name="trackLink" output="no" returntype="string" hint="Generate an A tag with javascript for tracking a download in Google Analytics">
	<cfargument name="link" type="string" required="true">
	<cfargument name="text" type="string" required="no" hint="Text of link - default is URL">
	<cfargument name="category" type="string" required="no" hint="A name that you supply as a way to group objects that you want to track. Default is extensions of filename">
	<cfargument name="action" type="string" required="no" default="download" hint="Use the action parameter to name the type of event or interaction you want to track for a particular web object.">
	<cfargument name="label" type="string" required="no" hint="With labels, you can provide additional information for events that you want to track, such as the movie title. Default is href attribute">
	<cfargument name="target" type="string" required="no" hint="Link target - use none or _blank">
	<cfargument name="class" type="string" required="no" hint="CSS class to apply to A tag">
	<cfargument name="title" type="string" required="no" hint="Title attribute to apply to A tag">
	<cfargument name="tracklink" type="any" required="no" default="Yes" hint="Supply false or blank value to just return normal link. Used when not tracking (e.g. dev server)">
	
	<cfset var retVal = "<a href=""#arguments.link#""">
	<cfset var local = {}>

	<cfif NOT IsDefined("arguments.text")>
		<cfset arguments.text = ReReplace(arguments.link,"https?\:\/\/","")>
	</cfif>
	<cfif NOT IsDefined("arguments.category")>
		<cfset arguments.category = ListLast(arguments.link,".")>
	</cfif>

	<!--- tracklink can be blank or non-blank for false or true --->
	<cfif Trim(arguments.tracklink) eq "">
		<cfset  arguments.trackLink= 0>
	<cfelseif NOT IsBoolean(arguments.tracklink)>
		<cfset  arguments.trackLink= 1>
	</cfif>
	
	<cfif arguments.tracklink>

		<!--- default for label is to dynamically get href at runtime --->
		<cfif IsDefined("arguments.label")>
			<cfset local.labelAttr = "'#arguments.label#'">
		<cfelse>
			<cfset local.labelAttr = "this.href">
		</cfif>

		<cfset local.script = "_gaq.push(['_trackEvent','#arguments.category#','#arguments.action#',#local.labelAttr#]);">
		

		<cfif NOT IsDefined("arguments.target")>
			<!--- delay link request to give analytics time to run --->
			<cfset local.script = "var that=this;#local.script#setTimeout(function(){location.href=that.href;},200);return false;">
		<cfelse>
			<cfset retVal &= " target=""#arguments.target#""">
		</cfif>

		<cfset retVal &= " onclick=""#local.script#""">
	<!---cfelse>
		<cftrace text="tracklink is off"--->
	<cfelseif isDefined("arguments.target")>
		<cfset retVal &= " target=""#arguments.target#""">
	</cfif>
	
	<cfif IsDefined("arguments.class")>
		<cfset retVal &= " class=""#arguments.class#""">
	</cfif>

	<cfif IsDefined("arguments.title")>
		<cfset retVal &= " title=""#arguments.title#""">
	</cfif>

	<cfset retVal &= ">#arguments.text#</a>">

	<!---cftrace text="retval=#HTMLEditFormat(retval)#"--->

	<cfreturn retVal>

</cffunction>

<cffunction name="hasValue" returntype="boolean" hint="Test struct Keys for for existence and non blankness (or emptiness). Values can be simple, arrays or structs">
	
	<cfargument name="sStr" type="struct" required="true" hint="Struct">
	<cfargument name="key" type="string" required="true" hint="Struct">	

	<cfset var retVal = true>

	<cfif NOT StructKeyExists(arguments.sStr, arguments.key)>
		<cfset retVal = false>
	<cfelse>
		<cfif isSimpleValue(arguments.sStr[arguments.key]) AND arguments.sStr[arguments.key] eq "">
			<cfset retVal = false>
		<cfelseif isStruct(arguments.sStr[arguments.key])  AND StructIsEmpty(arguments.sStr[arguments.key])>
			<cfset retVal = false>
		<cfelseif isArray(arguments.sStr[arguments.key])  AND NOT ArrayLen(arguments.sStr[arguments.key])>
			<cfset retVal = false>
		</cfif>	
	</cfif>

	<cfreturn retVal>

</cffunction>

<cffunction name="listToStruct" returntype="struct" hint="Convert list to struct (values are 1)">
	
	<cfargument name="sList" type="string" required="true" hint="List to convert">
	<cfargument name="delimiters" type="string" required="false" default=",">

	<cfset var i = 0>
	<cfset var retVal = {}>

	<cfloop list="#arguments.sList#" index="i" delimiters="#arguments.delimiters#">
		<cfset retVal[i] = 1>
	</cfloop>

	<cfreturn retVal>

</cffunction>

<cffunction name="listReverse" returntype="string" hint="Reverse a list">
	<cfargument name="slist" required="yes">
	<cfargument name="delimiter" required="no" default=",">

	<cfset var local = {}>
	<cfset var myList = "">
	<cfloop from="#ListLen(arguments.slist,arguments.delimiter)#" to="1" step="-1" index="local.i">
		<cfset local.val = ListGetAt(arguments.slist,local.i,arguments.delimiter)>
		<cfset myList=ListAppend(myList,local.val,arguments.delimiter)>
	</cfloop>
	
	<cfreturn myList>

</cffunction>

<cffunction name="internetDomain" returntype="struct" hint="Parse TLD [TLD], top private domain and [TPD], and sub domain [SUB] from an internet domain">
	
	<cfargument name="domainName" required="yes">

	<cfset var local = {}>
	<cfset var retVal = {}>
	
	<cfset arguments.domainName = ReReplace(arguments.domainName,"http\:\/\/(s)?","")>
	<cfoutput>#arguments.domainName#</cfoutput><br>

	<cfif NOT StructKeyExists(server,"TLDs")>
		<cfset local.tlds = {}>
		<cffile action="read" file="#GetDirectoryFromPath(getCurrentTemplatePath())#/effective_tld_names.dat" variable="local.data">

		<cfloop index="local.line" list="#local.data#" delimiters="#chr(13)##chr(10)#">
			<cfif NOT Left(trim(local.line),2) eq "//">
				<cfif ListLen(local.line,".") eq 1>
					<cfset local.currentAuthority = Trim(ListFirst(local.line,"."))>
					<cfif NOT StructKeyExists(local.tlds, local.currentAuthority)>
						<cfset local.tlds[local.currentAuthority] = {}>
					</cfif>
				</cfif>
				
				<cfset local.tlds[local.line] = local.currentAuthority>
			</cfif>
		</cfloop>

		<cfset server.TLDs = local.TLDs>
	</cfif>

	<cfset local.top = "">
	<cfset local.urlReverse = ListReverse(arguments.domainName,".")>
	<cfoutput>#local.urlReverse#</cfoutput>
	
	<cfloop index="local.i" from="1" to="#ListLen(arguments.domainName,".") - 1#">
		<cfset local.top = ListPrepend(ListGetAt(local.urlReverse,local.i,"."),".")>
		<cfif StructKeyExists(server.TLDs,local.top)>
			<cfset retVal.TLD = local.top>
			<cfset retVal.TPD = ListGetAt(local.urlReverse,local.i + 1)>
			<cfset retVal.sub = "">
			<cfif local.i + 1 lt ListLen(local.urlReverse,".")>
				<cfloop  from = "1" to="#ListLen(local.domainName,".")-local.i-1#" index="local.j">
					<cfset retVal.sub = ListAppend(ListGetAt(local.domainName,local.j),".")>
				</cfloop>
			</cfif>
		</cfif>

	</cfloop>
	
	<cfreturn retVal>

</cffunction>

<cffunction name="fnArraySplice">
	
	<cfargument name="vArray" required="true">
	<cfargument name="start" required="true" hint="positive int to get elements from start to end or negative into to get last x elements">
	<cfargument name="end" required="false" hint="positive int to get elements from start to end or negative into to get last x elements">

	<cfscript>
	local.retList = ArrayNew(1);
	
	local.arrLen = ArrayLen(arguments.vArray);
	if (NOT local.arrLen) return local.retList;
	 
	if (arguments.start lt 1) {
		arguments.start = local.arrLen - arguments.start;
	}
	if (NOT StructKeyExists(arguments,"end") OR arguments.end gt local.arrLen) {
		arguments.end = local.arrLen;
	}
	else {
		if (arguments.end lt 1) {
			arguments.end = local.arrLen - arguments.end;
		}
	}
	if (arguments.end lt arguments.start) {
		throw("End #arguments.end# is lt start #arguments.start# for arraySplice");
	}
	for (local.i = arguments.start; local.i lte arguments.end; local.i += 1) {
		ArrayAppend(local.retList,arguments.vArray[local.i]);
	}
	return local.retList;
	</cfscript>
	
</cffunction>

<!---
 Serialize native ColdFusion objects into a JSON formated string.
 
 @param arg      The data to encode. (Required)
 @return Returns a string. 
 @author Jehiah Czebotar (jehiah@gmail.com) 
 @version 2, June 27, 2008 
--->
<cffunction name="jsonencode" access="remote" returntype="string" output="No"
        hint="Converts data from CF to JSON format">
    <cfargument name="data" type="any" required="Yes" />
    <cfargument name="queryFormat" type="string" required="No" default="query" /> <!-- query or array -->
    <cfargument name="queryKeyCase" type="string" required="No" default="lower" /> <!-- lower or upper -->
    <cfargument name="stringNumbers" type="boolean" required="No" default=false >
    <cfargument name="formatDates" type="boolean" required="No" default=false >
    <cfargument name="columnListFormat" type="string" required="No" default="string" > <!-- string or array -->
    
    <!--- VARIABLE DECLARATION --->
    <cfset var jsonString = "" />
    <cfset var tempVal = "" />
    <cfset var arKeys = "" />
    <cfset var colPos = 1 />
    <cfset var i = 1 />
    <cfset var column = ""/>
    <cfset var datakey = ""/>
    <cfset var recordcountkey = ""/>
    <cfset var columnlist = ""/>
    <cfset var columnlistkey = ""/>
    <cfset var dJSONString = "" />
    <cfset var escapeToVals = "\\,\"",\/,\b,\t,\n,\f,\r" />
    <cfset var escapeVals = "\,"",/,#Chr(8)#,#Chr(9)#,#Chr(10)#,#Chr(12)#,#Chr(13)#" />
    
    <cfset var _data = duplicate(arguments.data) />

    <!--- BOOLEAN --->
    <cfif IsBoolean(_data) AND NOT IsNumeric(_data) AND NOT ListFindNoCase("Yes,No", _data)>
        <cfreturn LCase(ToString(_data)) />
        
    <!--- NUMBER --->
    <cfelseif NOT arguments.stringNumbers AND IsNumeric(_data) AND NOT REFind("^0+[^\.]",_data)>
        <cfreturn ToString(_data) />
    
    <!--- DATE --->
    <cfelseif IsDate(_data) AND arguments.formatDates>
        <cfreturn '"#DateFormat(_data, "medium")# #TimeFormat(_data, "medium")#"' />
    
    <!--- STRING --->
    <cfelseif IsSimpleValue(_data)>
        <cfreturn '"' & ReplaceList(_data, escapeVals, escapeToVals) & '"' />
    
    <!--- ARRAY --->
    <cfelseif IsArray(_data)>
        <cfset dJSONString = createObject('java','java.lang.StringBuffer').init("") />
        <cfloop from="1" to="#ArrayLen(_data)#" index="i">
            <cfset tempVal = jsonencode( _data[i], arguments.queryFormat, arguments.queryKeyCase, arguments.stringNumbers, arguments.formatDates, arguments.columnListFormat ) />
            <cfif dJSONString.toString() EQ "">
                <cfset dJSONString.append(tempVal) />
            <cfelse>
                <cfset dJSONString.append("," & tempVal) />
            </cfif>
        </cfloop>
        
        <cfreturn "[" & dJSONString.toString() & "]" />
    
    <!--- STRUCT --->
    <cfelseif IsStruct(_data)>
        <cfset dJSONString = createObject('java','java.lang.StringBuffer').init("") />
        <cfset arKeys = StructKeyArray(_data) />
        <cfloop from="1" to="#ArrayLen(arKeys)#" index="i">
            <cfset tempVal = jsonencode( _data[ arKeys[i] ], arguments.queryFormat, arguments.queryKeyCase, arguments.stringNumbers, arguments.formatDates, arguments.columnListFormat ) />
            <cfif dJSONString.toString() EQ "">
                <cfset dJSONString.append('"' & arKeys[i] & '":' & tempVal) />
            <cfelse>
                <cfset dJSONString.append("," & '"' & arKeys[i] & '":' & tempVal) />
            </cfif>
        </cfloop>
        
        <cfreturn "{" & dJSONString.toString() & "}" />
    
    <!--- QUERY --->
    <cfelseif IsQuery(_data)>
        <cfset dJSONString = createObject('java','java.lang.StringBuffer').init("") />
        
        <!--- Add query meta data --->
        <cfif arguments.queryKeyCase EQ "lower">
            <cfset recordcountKey = "recordcount" />
            <cfset columnlistKey = "columnlist" />
            <cfset columnlist = LCase(_data.columnlist) />
            <cfset dataKey = "data" />
        <cfelse>
            <cfset recordcountKey = "RECORDCOUNT" />
            <cfset columnlistKey = "COLUMNLIST" />
            <cfset columnlist = _data.columnlist />
            <cfset dataKey = "data" />
        </cfif>
        
        <cfset dJSONString.append('"#recordcountKey#":' & _data.recordcount) />
        <cfif arguments.columnListFormat EQ "array">
            <cfset columnlist = "[" & ListQualify(columnlist, '"') & "]" />
            <cfset dJSONString.append(',"#columnlistKey#":' & columnlist) />
        <cfelse>
            <cfset dJSONString.append(',"#columnlistKey#":"' & columnlist & '"') />
        </cfif>
        <cfset dJSONString.append(',"#dataKey#":') />
        
        <!--- Make query a structure of arrays --->
        <cfif arguments.queryFormat EQ "query">
            <cfset dJSONString.append("{") />
            <cfset colPos = 1 />
            
            <cfloop list="#_data.columnlist#" delimiters="," index="column">
                <cfif colPos GT 1>
                    <cfset dJSONString.append(",") />
                </cfif>
                <cfif arguments.queryKeyCase EQ "lower">
                    <cfset column = LCase(column) />
                </cfif>
                <cfset dJSONString.append('"' & column & '":[') />
                
                <cfloop from="1" to="#_data.recordcount#" index="i">
                    <!--- Get cell value; recurse to get proper format depending on string/number/boolean data type --->
                    <cfset tempVal = jsonencode( _data[column][i], arguments.queryFormat, arguments.queryKeyCase, arguments.stringNumbers, arguments.formatDates, arguments.columnListFormat ) />
                    
                    <cfif i GT 1>
                        <cfset dJSONString.append(",") />
                    </cfif>
                    <cfset dJSONString.append(tempVal) />
                </cfloop>
                
                <cfset dJSONString.append("]") />
                
                <cfset colPos = colPos + 1 />
            </cfloop>
            <cfset dJSONString.append("}") />
        <!--- Make query an array of structures --->
        <cfelse>
            <cfset dJSONString.append("[") />
            <cfloop query="_data">
                <cfif CurrentRow GT 1>
                    <cfset dJSONString.append(",") />
                </cfif>
                <cfset dJSONString.append("{") />
                <cfset colPos = 1 />
                <cfloop list="#columnlist#" delimiters="," index="column">
                    <cfset tempVal = jsonencode( _data[column][CurrentRow], arguments.queryFormat, arguments.queryKeyCase, arguments.stringNumbers, arguments.formatDates, arguments.columnListFormat ) />
                    
                    <cfif colPos GT 1>
                        <cfset dJSONString.append(",") />
                    </cfif>
                    
                    <cfif arguments.queryKeyCase EQ "lower">
                        <cfset column = LCase(column) />
                    </cfif>
                    <cfset dJSONString.append('"' & column & '":' & tempVal) />
                    
                    <cfset colPos = colPos + 1 />
                </cfloop>
                <cfset dJSONString.append("}") />
            </cfloop>
            <cfset dJSONString.append("]") />
        </cfif>
        
        <!--- Wrap all query data into an object --->
        <cfreturn "{" & dJSONString.toString() & "}" />
    
    <!--- UNKNOWN OBJECT TYPE --->
    <cfelse>
        <cfreturn '"' & "unknown-obj" & '"' />
    </cfif>
</cffunction>

<cfscript>
// generate an MD5 checksum for binary content
// typically you would fnReadFile(...,binary=true) and pass result to here
string function generateContentMD5( required any content ) {
    
	var digest = false;
    // Get our instance of the digest algorithm.
    if (NOT IsDefined("variables.messageDigest")) {
   		variables.messageDigest = createObject( "java", "java.security.MessageDigest" )
        .getInstance( javaCast( "string", "MD5" ) );
    }
    // Create the MD5 hash (as a byte array).
    digest = variables.messageDigest.digest( content );
    // Return the hashed bytes as Base64.
    return(
        binaryEncode( digest, "hex" )
    );
}


/**
* an ASCII string to hexadecimal.
*
* @param str      String to convert to hex. (Required)
* @return Returns a string.
* @author Chris Dary (umbrae@gmail.com)
* @version 1, May 8, 2006
*/
function stringToHex(str) {
    var hex = "";
    var i = 0;
    for(i=1;i lte len(str);i=i+1) {
        hex = hex & right("0" & formatBaseN(asc(mid(str,i,1)),16),2);
    }
    return hex;
}



// make first letter of a string lower case
function camelCase(textStr) {
	 return Lcase(Left(arguments.textStr,1)) & Right(arguments.textStr,Len(arguments.textStr)-1);
}
/**
 * Capitalise first letter and replace underscors with spaces.
 */
function labelFormat(textStr) {
	arguments.textStr = Replace(arguments.textStr,"_"," ","all");
	arguments.textStr = Ucase(Left(arguments.textStr,1)) & Right(arguments.textStr,Len(arguments.textStr)-1);
	if (right(arguments.textStr,3) eq " id") {
		arguments.textStr = Left(arguments.textStr,len(arguments.textStr) - 3) & " ID";
	}
	return arguments.textStr;
}

/**
 * Replace not alpha numeric, lower case and replace underscors with spaces.
 */
function idFormat(textStr) {
	arguments.textStr = Replace(arguments.textStr,"_"," ","all");
	arguments.textStr = REReplaceNoCase(arguments.textStr, "[^a-z0-9\_]", "","ALL");
	arguments.textStr = Lcase(arguments.textStr);
	
	return arguments.textStr;
}


array function structMultiSort(required struct data, required array sortCriteria, boolean dump = false, string pk_type = "integer") {

	if (ArrayLen(sortCriteria) lt 2) throw("Don't use this for single sort criteria. Use StructSort(). Only makes sense for multiple criteria");
	if (structIsEmpty(arguments.data)) return [];

	var sql="";

	for (local.crit in arguments.sortCriteria) {
		structAppend(local.crit,{type="varchar",direction="asc"},0);
		if (local.crit.type eq "text") local.crit.type = "varchar";
		if (local.crit.type eq "numeric") local.crit.type = "Double";
		// ascending, descending -> asc,desc
		local.crit.direction = ReplaceNoCase(local.crit.direction,"ending","");
		sql = ListAppend(sql,'q.[#local.crit.field#] #local.crit.direction#');
	}

	// create list of columns and column types
	local.colList = '';
	local.typeList = '';
	for (local.crit in arguments.sortCriteria) {
		local.colList = listAppend(local.colList, local.crit.field);
		local.typeList = listAppend(local.typeList, local.crit.type);
	}
	local.colList = listAppend(local.colList, "key");
	local.typeList = listAppend(local.typeList, arguments.pk_type);

	var q = QueryNew(local.colList, local.typeList);

	// populate query data
	for (local.i in arguments.data) {
		queryAddRow(local.q, 1);
		for (local.crit in arguments.sortCriteria) {
			local.val = arguments.data[local.i][local.crit.field];
			querySetCell(q, local.crit.field, local.val);
			if( local.val eq '' ) {
				querySetCell(q, local.crit.field, javacast("null", 0));
			}
		}
		querySetCell(q, "key", local.i);
	}

	var queryService = new query(q=q); 
	queryService.setDBType('query');
		sql="SELECT * from q ORDER BY " & sql;

	if( arguments.dump ) {
		writeDump(arguments.data);
		writeDump(arguments.sortCriteria);
		writeDump(q);
		writeDump(sql);
		abort;
	}

	result = queryService.execute(sql=sql).getResult();

	var sorted = ListToArray(ValueList(result.key)); 
	
	return sorted;
}

/**
 * sort a struct on a key that might contain empty data
 * @param   required     struct        data             The data to sort
 * @param   required     string        sortType         sort type
 * @param   required     string        sortorder        asc | desc
 * @param   required     string        pathtosubelement The key to sort on
 * @param   defaultValue The value to give to any empty elements
 * @return {array}
 */
array function structSortEmpty( required struct data, required string sortType, required string sortorder, required string pathtosubelement, defaultValue ) {
	var tempData = duplicate(arguments.data);
	switch( arguments.sortType ) {
		case 'numeric':
			arguments.defaultValue = -9*10^14;
		break;
		default:
			throw('structSortEmpty called with sortType="#arguments.sortType#" without specifying defaultValue');
		break;
	}
	for ( local.key in tempData ) {
		if(NOT structKeyExists(tempData[local.key],arguments.pathtosubelement) OR tempData[local.key][arguments.pathtosubelement] eq '' ) {
			tempData[local.key][arguments.pathtosubelement] = arguments.defaultValue;
		}
	}
	return structSort(tempData, arguments.sortType, arguments.sortorder, arguments.pathtosubelement);
}

/**
 * Sorts an array of structures based on a key in the structures.
 * 
 * @param aofS 	 Array of structures. (Required)
 * @param key 	 Key to sort by. (Required)
 * @param sortOrder 	 Order to sort by, asc or desc. (Optional)
 * @param sortType 	 Text, textnocase, or numeric. (Optional)
 * @param delim 	 Delimiter used for temporary data storage. Must not exist in data. Defaults to a period. (Optional)
 * @return Returns a sorted array. 
 * @author Nathan Dintenfass (nathan@changemedia.com) 
 * @version 1, April 4, 2013 
 */
function arrayOfStructsSort(aOfS,key){
		//by default we'll use an ascending sort
		var sortOrder = "asc";		
		//by default, we'll use a textnocase sort
		var sortType = "textnocase";
		//by default, use ascii character 30 as the delim
		var delim = ".";
		//make an array to hold the sort stuff
		var sortArray = arraynew(1);
		//make an array to return
		var returnArray = arraynew(1);
		//grab the number of elements in the array (used in the loops)
		var count = arrayLen(aOfS);
		//make a variable to use in the loop
		var ii = 1;
		//if there is a 3rd argument, set the sortOrder
		if(arraylen(arguments) GT 2)
			sortOrder = arguments[3];
		//if there is a 4th argument, set the sortType
		if(arraylen(arguments) GT 3)
			sortType = arguments[4];
		//if there is a 5th argument, set the delim
		if(arraylen(arguments) GT 4)
			delim = arguments[5];
		//loop over the array of structs, building the sortArray, while allowing for a key not to be present in all structs
		for(ii = 1; ii lte count; ii = ii + 1)
			sortArray[ii] = (structKeyExists(aOfS[ii],key) ? aOfS[ii][key] : ' ') & delim & ii;
		//now sort the array
		arraySort(sortArray,sortType,sortOrder);
		//now build the return array
		for(ii = 1; ii lte count; ii = ii + 1)
			returnArray[ii] = aOfS[listLast(sortArray[ii],delim)];
		//return the array
		return returnArray;
}
/**
 * Convert a struct to a plain text string. Use to dump structs when writing text e.g. css when dump won't work
 * @param  Struct sData       Struct to dump
 * @return String        Plain text sting
 */
public string function structToString(Struct sData) {
	var max = 5;
	var key = false;
	var retVal = "";

	for (key in arguments.sData) {
		if (Len(key) gt max) max = len(key);
	}
	max += 2;
	for (key in arguments.sData) {
		retVal &= LJustify(key,max) & arguments.sData[key] & chr(13) & chr(10);
	}
	return retVal;

}

/**
 * Display a help button for use with doClikHelp() in clikUtils js
 *
 * @ID      Unique ID
 * @content Text of help item
 * @title   Title of help dialogue
 */
public string function helpButton(required string  ID, required  string content, string title = "Help") {

	var retVal = "<span id='#arguments.ID#_helpicon' class='helpicon noprint' title='#arguments.title#'>";

	retVal &= "<span class='icon-stack'>";
   	retVal &= "<i class='icon-stack-base icon-sign-blank noprint'></i>";
   	retVal &= "<i class='icon-question icon-light noprint'></i>";
   	retVal &= "</span>";
   	retVal &= "<div class='clikHelpTitle'>#arguments.title#</div>";
   	retVal &= "<div class='clikHelpContent'>#arguments.content#</div>";
   	retVal &= "</span>";

	return  retVal;

}
	
</cfscript>

	<cffunction name="getRemoteFile" output="no" hint="Save a remote file to the specified directory">
		
		<cfargument name="url" type="string" required="true">
		<cfargument name="path" type="string" required="true">
		
		<cfhttp url="#arguments.url#" path="#arguments.path#">
		
	</cffunction>

	

	<cffunction name="EncodeURL" output="No" returntype="string" hint="Encode certain characters for the Google sitemaps">
		
		<cfargument name="in_url" required="Yes">
		
		<cfset var characters_to_replace = "&,',"",<,>">
		<cfset var replacement_characters = "&amp;,&apos;,&quot;,&lt;,&gt;">
		
		<cfset var out_url = ReplaceList(arguments.in_url, characters_to_replace, replacement_characters)>
		
		<cfreturn out_url>
	</cffunction>

	<cffunction name="W3cDateTimeFormat" output="No" returntype="string" hint="format a date time in w3c format">

		<cfargument name="dateObj">
		
		<cfset var timeZone = GetTimeZoneInfo()>
		<cfset var retVar = DateFormat(arguments.dateObj,"yyyy-mm-dd")>
		<cfset retVar = retVar & "T" & TimeFormat(arguments.dateObj,"HH:mm:ss")>
		<cfset retVar = retVar & NumberFormat(timeZone.utcHourOffset,"+09") & ":00">
		
		<cfreturn retVar>
	
	</cffunction>

	

	<cffunction name="fnFieldReplace" hint="Replace fields in format {$filename} with values from struct" output="no" returntype="string">
		<cfargument name="text" type="string" required="yes">
		<cfargument name="fields" type="struct" required="yes">
		
		<cfset var retStr = arguments.text>
		<cfset var sfield = false>
		<cfset var matches = false>
		<cfset var match = false>
		
		
		<cfset matches = reMatchNoCase("\{\$*.+?\}",arguments.text)>
		<cfif arrayLen(matches)>
			<cfloop index="match" array="#matches#">
				<cfset sfield = ListFirst(match,"{$}")>
				<cfif StructKeyExists(arguments.fields,sfield)>
					<cfset retStr = REReplaceNoCase(retStr, "\{\$*#sfield#\}", arguments.fields[sfield], "all")>
				</cfif>
			</cfloop>			
		</cfif>
		
		<cfreturn retStr>
		
	</cffunction>

	<cffunction name="parseCSV" output="true" returntype="array" hint="Parse CSV data into array of arrays. NB Doesn't really work, field delims sort of hardwired as """>
		<cfargument name="data" type="string" required="true">
		<cfargument name="rowdelim" required="false" default="#chr(10)##chr(9)#">
		<cfargument name="fielddelim" required="false" default="""">

		<cfscript>
		var retval = [];
		var rows = listToArray(arguments.data,rowdelim);
		var nextDelim = false;
		var patt = ",(?=([^\""]*\""[^\""]*\"")*[^\""]*$)";
		var rowArr = false;
		var jArray = false;
		var fieldVal = false;

		var hasDelims = arguments.fieldDelim neq "";
		for (var row in rows) {
			jArray =  row.ToString().Split(patt);
			// jArray = CreateObject(
			// "java",
			// "java.util.Arrays"
			// ).AsList(
			//     ToString(row).Split(patt)
			//     );
			rowArr = [];
			
			for (var field in jArray) {
					fieldVal =  field;
					if (hasDelims) {
						if (listFind(arguments.fieldDelim, Left(fieldVal,1))) {
							fieldVal = listFirst(field,arguments.fieldDelim);
						}
					}
					ArrayAppend(rowArr,fieldVal);
			}
			ArrayAppend(retval,rowArr);
		}

		return retVal;
		</cfscript>

	</cffunction>

</cfcomponent>