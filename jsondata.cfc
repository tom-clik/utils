/**
 * Load records from a json file with field definitions also defined in JSON.
 *
 * ## Background
 *
 * A simple field definition language is used to validate and supply defaults for data records.
 *
 * This can be stored in a separa file and passed 
 * 
 */
component name="jsondata" {

	/**
	 * Loads a JSON file into a struct and returns it.
	 */
	public any function loadJSONDataFile(required string filename, struct fields={}) output=false {
		
		var filedata = false;
		var dataStruct = false;
		filedata = fileRead(arguments.filename);
		/*  not 100% sure why this is here. Possibly to make readable json files for mustache templates ?? 
			filedata = reReplace(filedata,"[\r\n]"," ","all");
		*/
		try{
			dataStruct = DeserializeJSON(filedata);
			if ( !isStruct(dataStruct)) {
				throw(message="incorrectly formatted data file",detail="Must be a struct -- see documentation");
			}
		} 
		catch (any e) {
			local.extendedinfo = {"tagcontext"=e.tagcontext};
			throw(
				extendedinfo = SerializeJSON(local.extendedinfo),
				message      = "Problem deserialising JSON data from file #arguments.filename#:" & e.message, 
				detail       = e.detail,
				errorcode    = "utils.jsondata.001"		
			);
		}

		if (structIsEmpty(arguments.fields)) {
			if (NOT StructKeyExists(dataStruct,"fields") ) {
				throw(
					message   = "no fields defined",
					detail    = "Fields must be supplied as argument or defined in data file",
					errorcode = "utils.jsondata.004"	
				);	
			}
			structAppend(arguments.fields, parseJSONDataFields(dataStruct.fields));
		}

		structDelete(dataStruct,"fields");
		local.allErrors = {};
		for ( local.pk in dataStruct ) {
			try{
				local.errors = {};
				local.valid = JSONDataValidate(dataStruct[local.pk],arguments.fields,local.errors);	
				if (NOT local.valid) {
					local.allErrors[local.pk] = duplicate(local.errors);
				}
			}
			catch (any e) {
				local.extendedinfo = {"tagcontext"=e.tagcontext};
				throw(
					extendedinfo = SerializeJSON(local.extendedinfo),
					message      = "Error parsing data records" & e.message, 
					detail       = e.detail,
					errorcode    = "utils.jsondata.005"		
				);
			}
			
		}

		if (NOT structIsEmpty(local.allErrors)) {
			local.extendedinfo = {"errors"=local.allErrors};
			throw(
				extendedinfo = SerializeJSON(local.extendedinfo),
				message      = "Error parsing data records", 
				detail       = "Validation failed for data records, see extendedinfo.errors",
				errorcode    = "utils.jsondata.006",
				type         = "validation"
			);
		}
		
		return dataStruct;
	}

	/**
	 * Validate individual record using field definition
	 */
	private boolean function JSONDataValidate(required struct data, required struct fieldDefs, required struct errors) output=false {
		
		var field = false;
		var value = false;

		structAppend(arguments.data,arguments.fieldDefs.defaults,false);
		
		for ( local.fieldName in arguments.fieldDefs.fields ) {
			field = arguments.fieldDefs.fields[local.fieldName];
			if ( field.required && (NOT structKeyExists(arguments.data,local.fieldName) || arguments.data[local.fieldName] == "") ) {
				arguments.errors[local.fieldName] = "Required field #local.fieldName# not specified";
			}
			value = arguments.data[local.fieldName];
			switch ( field.type ) {
				case  "text":
					if ( structKeyExists(field, "max") && !Len(value) <= field.max ) {
						arguments.errors[local.fieldname] ="Specified value for #local.fieldName# [#value#] too long (max #field.max#)";
					}
					if ( structKeyExists(field, "min") && ! Len(value) >= field.min ) {
						arguments.errors[local.fieldname] ="Specified value for #local.fieldName# [#value#] too short (min #field.min#)";
					}
					if ( structKeyExists(field, "pattern") && !REFindNoCase(field.pattern,value) ) {
						arguments.errors[local.fieldname] ="Specified value for #local.fieldName# [#value#] didn't match pattern #field.pattern#";
					}
					break;
				case  "boolean":
					if ( !IsBoolean(value) ) {
						arguments.errors[local.fieldname] ="Specified value for #local.fieldName# [#value#] not boolean";
					}
					else {
						arguments.data[local.fieldName] = arguments.data[local.fieldName] AND 1;
					}
					break;
				case  "int": case "numeric":
					if ( value != "" ) {
						if ( !IsNumeric(value) || (field.type == "int" && !isValid("integer",value)) ) {
							arguments.errors[local.fieldname] ="Specified value for #local.fieldName# [#value#] not #field.type#";
						}
						if ( structKeyExists(field, "max") && !(value <= field.max) ) {
							arguments.errors[local.fieldname] ="Specified value for #local.fieldName# [#value#] too high (max #field.max#)";
						}
						if ( structKeyExists(field, "min") && !(value >= field.min) ) {
							arguments.errors[local.fieldname] ="Specified value for #local.fieldName# [#value#] too low (min #field.min#)";
						}
					}
					break;
				case  "list": case "multi":
					if ( field.type == "list" && ListLen(value) > 1 ) {
						arguments.errors[local.fieldname] ="Specified value for #local.fieldName# [#value#] had multiple entries";
					}
					for ( local.val in value ) {
						if ( !structKeyExists(field.list,local.val) ) {
							arguments.errors[local.fieldname] ="Specified value for #local.fieldName# [#value#] not in allowed list values";
						}
					}
					break;
			}
		}
		return structIsEmpty(arguments.errors);
	}

	/**
	 * @hint Parse field definitions
	 *
	 * 
	 */
	private struct function parseJSONDataFields(required struct fields) output=false {
		
		var field = false;
		var retFields = {"fields"=arguments.fields,"defaults"={}};
		
		for ( local.fieldID in arguments.fields ) {
			
			field = retFields.fields[local.fieldID];
			if ( StructKeyExists(field,"default") ) {
				retFields.defaults[local.fieldID] = field.default;
			}
			if ( !StructKeyExists(field,"label") ) {
				field["label"] = labelFormat(local.fieldID);
			}
			structAppend(field,{"required"=0,"type"="text","description"="","sort_order"=0},false);
			
			if ( field.type == "list" ) {
				if ( !structKeyExists(field, "list") || !IsStruct(field.list) ) {
					throw( message="List values incorrect for field #local.fieldID#" );
				}
				local.sort_order = 10;
				for ( local.listID in field.list ) {
					if ( IsSimpleValue(field.list[local.listID]) ) {
						field.list[local.listID] = {"display"= field.list[local.listID],"sort_order"=local.sort_order};
					}
					local.sort_order += 10;
				}
			}
		}
		return retFields;
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

}
