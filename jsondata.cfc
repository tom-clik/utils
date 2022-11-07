<cfcomponent name="jsondata">
	
	<cffunction name="fnLoadJSONDataFile" output="false" returntype="any" hint="Loads a JSON file into a struct and returns it.">
			
			<cfargument name="filename" required="true" type="string" hint="Full path to JSON file.">
			<cfargument name="fields" required="false" type="struct" hint="Optionally pass in struct to return field defs">
			
			<cfset var filedata = false>
			<cfset var dataStruct = false>
			
			<cfset filedata = fileRead(arguments.filename)>

			<!--- not 100% sure why this is here. Possibly to make readable json files for moustache templates ?? 
			<cfset filedata = reReplace(filedata,"[\r\n]"," ","all")>
			--->
			
			<cftry>
				<cfset dataStruct = DeserializeJSON(filedata)>
				<cfcatch type="any">
					<cfthrow message="Problem deserialising JSON data from file #arguments.filename#" detail="#cfcatch.Message# - #cfcatch.Detail#">
				</cfcatch>
			</cftry>

			<cfif isStruct(dataStruct) AND structKeyExists(dataStruct,"fields")>
				<cfset local.dataDef = ParseJSONDataFields(dataStruct.fields)>
				<cfset structDelete(dataStruct,"fields")>
				<cfloop item="local.row"  collection="#dataStruct#">
					<!--- <cfset StructAppend(dataStruct[local.row],local.fields.defaults,0)> --->
					<cfset JSONDataValidate(dataStruct[local.row],local.dataDef)>
				</cfloop>
				<cfif IsDefined("arguments.fields")>
					<cfset StructAppend(arguments.fields,local.dataDef.fields)>
				</cfif>
			</cfif>
			
			<cfreturn dataStruct>
			
	</cffunction>

	<cffunction name="getJSONFields" output="false" returntype="struct" hint="Get field defs from JSON data file">
			
		<cfargument name="filename" required="true" type="string" hint="Full path to JSON file.">
		
		<cfset var filedata = false>
		<cfset var dataStruct = false>
		
		<cfset filedata = server.utils.fnReadFile(arguments.filename)>

		<!--- not 100% sure why this is here. Possibly to make readable json files for moustache templates ?? 
		<cfset filedata = reReplace(filedata,"[\r\n]"," ","all")>
		--->
		
		<cftry>
			<cfset dataStruct = DeserializeJSON(filedata)>
			<cfcatch type="any">
				<cfthrow message="Problem deserialising JSON data from file #arguments.filename#" detail="#cfcatch.Message# - #cfcatch.Detail#">
			</cfcatch>
		</cftry>

		<cfif isStruct(dataStruct) AND structKeyExists(dataStruct,"fields")>
			<cfset local.fields = ParseJSONDataFields(dataStruct.fields)>
		<cfelse>
			<cfthrow message="Problem deserialising JSON data from file #arguments.filename#" detail="#cfcatch.Message# - #cfcatch.Detail#">
		</cfif>

		<cfreturn local.fields.fields>

	</cffunction>

	<cffunction name="JSONDataValidate" output="false" access="private" returntype="void" hint="see fnLoadJSONDataFile(). Validate data using field definition">

		<cfargument name="data" required="true" type="struct" hint="Single data row.">
		<cfargument name="fieldDefs" required="true" type="struct" hint="Field definition struct NB not raw -- must be parsed by ParseJSONDataFields()">

		<cfset var field = false>
		<cfset var value = false>

		<cfset structAppend(arguments.data,arguments.fieldDefs.defaults,false)>

		<cfloop collection="#arguments.fieldDefs.fields#" item="local.fieldName">
			
			<cfset field = arguments.fieldDefs.fields[local.fieldName]>
			
			<cfif field.required AND (NOT structKeyExists(arguments.data,local.fieldName) OR arguments.data[local.fieldName] eq "")>
				<cfthrow type="jsonvalidate" message="Required field #local.fieldName# not specified">
			</cfif>

			<cfset value = arguments.data[local.fieldName]>
			
			<cfswitch expression="#field.type#">
				<cfcase value="text">
					<cfif structKeyExists(field, "max") AND NOT Len(value) lte field.max>
						<cfthrow type="jsonvalidate" message="Specified value for #local.fieldName# [#value#] too long (max #field.max#)">
					</cfif>
					<cfif structKeyExists(field, "min") AND NOT  Len(value) gte field.min>
						<cfthrow type="jsonvalidate" message="Specified value for #local.fieldName# [#value#] too short (min #field.min#)">
					</cfif>
					<cfif structKeyExists(field, "pattern") AND NOT REFindNoCase(field.pattern,value)>
						<cfthrow type="jsonvalidate" message="Specified value for #local.fieldName# [#value#] didn't match pattern #field.pattern#">
					</cfif>
				</cfcase>
				<cfcase value="boolean">
					<cfif NOT IsBoolean(value)>
						<cfthrow type="jsonvalidate" message="Specified value for #local.fieldName# [#value#] not boolean">
					</cfif>
				</cfcase>
				<cfcase value="int,numeric">
					<cfif value neq "">
						<cfif NOT IsNumeric(value) OR (field.type eq "int" AND NOT isValid("integer",value))>
							<cfthrow type="jsonvalidate" message="Specified value for #local.fieldName# [#value#] not #field.type#">
						</cfif>
						<cfif structKeyExists(field, "max") AND NOT value lte field.max>
							<cfthrow type="jsonvalidate" message="Specified value for #local.fieldName# [#value#] too high (max #field.max#)">
						</cfif>
						<cfif structKeyExists(field, "min") AND NOT  value gte field.min>
							<cfthrow type="jsonvalidate" message="Specified value for #local.fieldName# [#value#] too low (min #field.min#)">
						</cfif>
					</cfif>
				</cfcase>
				<cfcase value="list,multi">
					<cfif field.type eq "list" AND ListLen(value) gt 1>
						<cfthrow type="jsonvalidate" message="Specified value for #local.fieldName# [#value#] had multiple entries">
					</cfif>
					<cfloop index="local.val" list="#value#">
						<cfif NOT structKeyExists(field.list,local.val)>
							<cfthrow type="jsonvalidate" message="Specified value for #local.fieldName# [#value#] not in allowed list values">	
						</cfif>
					</cfloop>
				</cfcase>

			</cfswitch>

		</cfloop>

	</cffunction>

	<cffunction name="ParseJSONDataFields" output="false" access="private" returntype="struct" hint="see fnLoadJSONDataFile(). Parse the fields def for json data file">

		<cfargument name="fields" required="true" type="struct" hint="Field definition struct">

		<cfset var field = false>

		<cfset var retFields = {"fields"=arguments.fields,"defaults"={}}>
		<cfloop collection="#arguments.fields#" item="local.fieldID">
			<cfset field = retFields.fields[local.fieldID]>
			<cfif StructKeyExists(field,"default")>
				<cfset retFields.defaults[local.fieldID] = field.default>
			</cfif>
			<cfif NOT StructKeyExists(field,"label")>
				<cfset field["label"] = labelFormat(local.fieldID)>
			</cfif>
			<cfset structAppend(field,{"required"=0,"type"="text","description"="","sort_order"=0},false)>
			<cfif field.type eq "list">
				<cfif NOT structKeyExists(field, "list") OR NOT IsStruct(field.list)>
					<cfthrow message="List values incorrect for field #local.fieldID#">
				</cfif>
				<cfset local.sort_order = 10>
				<cfloop item="local.listID" collection="#field.list#">
					<cfif IsSimpleValue(field.list[local.listID])>
						<cfset field.list[local.listID] = {"display"= field.list[local.listID],"sort_order"=local.sort_order}>
					</cfif>
					<cfset local.sort_order += 10>
				</cfloop>
			</cfif>
		</cfloop>

		<cfreturn retFields>

	</cffunction>

	<cfscript>
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


	</cfscript>

</cfcomponent>