<cfcomponent>
<cffunction name="xml2Data" hint="Parse XML into a Struct array of structs" description="An improvement on xml2struct which recognises whether a node needs to be an array. This allows for single records or multiple records without worrying about which is which. The results will be an array or a struct. Sub records within the data are similarly coped with so there's no need to go back and convert structs keyed by row number into arrays.">
		
	<cfargument name="xmlData" required="yes" hint="Either XML as produced by parseXML or else an array of XML nodes (the latter should only be used when recursing)">
	<cfargument name="addOrder"  required="false" default="0" hint="Add sort_order field to nodes to preserve order">
	<cfset var retData = false>
	<cfset var root = false>
	
	<cfset var root = arguments.xmlData.xmlRoot>

	<cfset var retData = parseXMLNode(root,arguments.addOrder)>
	
	<cfreturn retData>

</cffunction>

<cffunction name="parseXMLNode" hint="Parse an XML node into a struct or array. helper function for xml2Data. " access="public" returntype="any">
		
	<cfargument name="xmlElement" required="yes" hint="Either XML as produced by parseXML or else an array of XML nodes (the latter should only be used when recursing)">
	<cfargument name="addOrder" required="false" default="0" hint="Add sort_order field to nodes to preserve order">

	<cfset var retVal = false>
	<cfset var child = false>
	

	<cfif isArrayNode(arguments.xmlElement)>
		<cfset retVal = []>
		<cfloop index="child" array="#arguments.xmlElement.xmlChildren#">
			<cfset ArrayAppend(retVal,parseXMLNode(child,arguments.addOrder))>
		</cfloop>		
	<cfelse>
		<cfset retVal = [=]>
		<cfif arguments.addOrder>
			<cfset var order = 0>
		</cfif>
		<cfloop index="child" array="#arguments.xmlElement.xmlChildren#">
			
			<cfif Trim(child.xmlText) neq "" AND  ArrayLen(child.xmlChildren) gte 1>
				<!---assume mixed node is html--->
				<cfset local.text = reReplace(ToString(child),"([\n\r])\t+","\1","all")>
				<cfset local.text = reReplace(local.text,"\<\?xml.*?\>","")>
				<cfset local.text = reReplace(local.text,"\<\/?#child.XmlName#\>","","all")>
				<cfset addDataToNode(retVal,child.XmlName,local.text)>
			<cfelseif ArrayLen(child.xmlChildren) gte 1 OR NOT structIsEmpty(child.XmlAttributes)>
				<cfset local.data = parseXMLNode(child,arguments.addOrder)>
				<cfif IsStruct(local.data) AND arguments.addOrder>
					<cfset local.data["sort_order"] = order>
					<cfset order += 1>
				</cfif>
				<cfset addDataToNode(retVal,child.XmlName,local.data)>
			<cfelse>
				<cfset addDataToNode(retVal,child.XmlName,reReplace(child.xmlText,"([\n\r])\t+","\1","all"))>
			</cfif>	
		</cfloop>
		
		<!--- only append attribute values now. --->
		<cfset local.attrVals = this.xmlAttributes2Struct(arguments.xmlElement.XmlAttributes)>
		<cfset StructAppend(retVal,local.attrVals,false)>

		<!--- allow use of arbitrary text content as "value" attribute in mixed nodes 
		if value is already defined as attribute, use textValue, unless tag is <option> in which case use display
		--->
		<cfif NOT arrayLen(arguments.xmlElement.xmlChildren) AND Trim(arguments.xmlElement.xmlText) neq "" AND structCount(retVal)>
			<cfset local.tagName = "value">
			<cfif structKeyExists(retVal,"value")>
				<cfif arguments.xmlElement.XmlName eq "option">
					<cfset local.tagName = "display">
				<cfelse>
					<cfset local.tagName = "textValue">
				</cfif>
			</cfif>

			<cfset retVal[local.tagName] = reReplace(arguments.xmlElement.xmlText,"([\n\r])\t+","\1","all")>
		</cfif>

	</cfif>

	<cfreturn retVal>

</cffunction>

<cffunction name="addDataToNode" returntype="void" hint="helper function for parseXMLNode. Adds data to a struct. If the key already exists, appends to an array" access="private">
	
	<cfargument name="sNode" required="true">
	<cfargument name="key" required="true">
	<cfargument name="sData" required="true">

	<cfif NOT structKeyExists(arguments.sNode,arguments.key)>
		<!--- Guess data type. --->
		<cfif isNumeric(arguments.sData)>
			<cfset arguments.sNode[arguments.key] = Val(arguments.sData)>
		<cfelseif isBoolean(arguments.sData)>
			<cfset arguments.sNode[arguments.key] = NOT NOT arguments.sData>
		<cfelse>
			<cfset arguments.sNode[arguments.key]= arguments.sData>
		</cfif>
	<cfelse>
		<cfif NOT isArray(arguments.sNode[arguments.key])>
			<cfset local.tmpHolder = Duplicate(arguments.sNode[arguments.key])>
			<cfset arguments.sNode[arguments.key] = []>
			<cfset arrayAppend(arguments.sNode[arguments.key],local.tmpHolder)>
		</cfif>
		<cfset arrayAppend(arguments.sNode[arguments.key],arguments.sData)>
	</cfif>

</cffunction>

<cffunction name="isArrayNode" returntype="boolean" hint="helper function for parseXMLNode. Checks whether node should be an array of nodes" access="private">
	<!--- if all the children have the same name, then this is an array --->
	<cfargument name="xmlElement" required="yes">
	
	<cfset var isArray = 0>
	<cfset var childNames = {}>

	<cfif structIsEmpty(arguments.xmlElement.XMLAttributes) AND arrayLen(arguments.xmlElement.xmlChildren) gt 1>
		<cfloop index="local.child" array="#arguments.xmlElement.xmlChildren#">
			<cfset childNames[local.child.XMLName] = 1>
		</cfloop>
		<cfif structCount(childNames) eq 1>
			<cfset isArray = 1>
		</cfif>
	</cfif>

	<cfreturn isArray>

</cffunction>
<cffunction name="xmlAttributes2Struct">
		<cfargument name="xmlAttributes">

		<cfset var retStr = {}>

		<cfloop collection="#arguments.xmlAttributes#" item="local.key">
			<!--- Guess data type. --->
			<cfset local.value = arguments.xmlAttributes[local.key]>
			<cfif isNumeric(local.value)>
				<cfset local.value = Val(local.value)>
			<cfelseif isBoolean(local.value)>
				<cfset local.value = NOT NOT local.value>
			</cfif>

			<cfset retStr[local.key] = local.value>
		</cfloop>

		<cfreturn retStr>
	</cffunction>
	
</cfcomponent>