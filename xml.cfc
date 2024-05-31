component {

	/**
	 * Parse XML into a Struct array of structs
	 * @description An improvement on xml2struct which recognises whether a node needs to be an array. This allows for single records or multiple records without worrying about which is which. The results will be an array or a struct. Sub records within the data are similarly coped with so there's no need to go back and convert structs keyed by row number into arrays.
	 */
	public function xml2Data(required xmlData, addOrder="0") {
		var retData = false;
		var root = false;
		var root = arguments.xmlData.xmlRoot;
		var retData = parseXMLNode(root,arguments.addOrder);
		return retData;
	}

	/**
	 * Parse an XML node into a struct or array. helper function for xml2Data. 
	 */
	public any function parseXMLNode(required xmlElement, addOrder="0") {
		var retVal = false;
		var child = false;
		if ( isArrayNode(arguments.xmlElement) ) {
			retVal = [];
			for ( child in arguments.xmlElement.xmlChildren ) {
				ArrayAppend(retVal,parseXMLNode(child,arguments.addOrder));
			}
		} else {
			retVal = [=];
			if ( arguments.addOrder ) {
				var order = 0;
			}
			for ( child in arguments.xmlElement.xmlChildren ) {
				if ( Trim(child.xmlText) != "" &&  ArrayLen(child.xmlChildren) >= 1 ) {
					// assume mixed node is html
					local.text = reReplace(ToString(child),"([\n\r])\t+","\1","all");
					local.text = reReplace(local.text,"\<\?xml.*?\>","");
					local.text = reReplace(local.text,"\<\/?#child.XmlName#\>","","all");
					addDataToNode(retVal,child.XmlName,local.text);
				} else if ( ArrayLen(child.xmlChildren) >= 1 || !structIsEmpty(child.XmlAttributes) ) {
					local.data = parseXMLNode(child,arguments.addOrder);
					if ( IsStruct(local.data) && arguments.addOrder ) {
						local.data["sort_order"] = order;
						order += 1;
					}
					addDataToNode(retVal,child.XmlName,local.data);
				} else {
					addDataToNode(retVal,child.XmlName,reReplace(child.xmlText,"([\n\r])\t+","\1","all"));
				}
			}
			//  only append attribute values now. 
			local.attrVals = this.xmlAttributes2Struct(arguments.xmlElement.XmlAttributes);
			StructAppend(retVal,local.attrVals,false);
			/*  allow use of arbitrary text content as "value" attribute in mixed nodes 
		if value is already defined as attribute, use textValue, unless tag is <option> in which case use display
		*/
			if ( !arrayLen(arguments.xmlElement.xmlChildren) && Trim(arguments.xmlElement.xmlText) != "" && structCount(retVal) ) {
				local.tagName = "value";
				if ( structKeyExists(retVal,"value") ) {
					if ( arguments.xmlElement.XmlName == "option" ) {
						local.tagName = "display";
					} else {
						local.tagName = "textValue";
					}
				}
				retVal[local.tagName] = reReplace(arguments.xmlElement.xmlText,"([\n\r])\t+","\1","all");
			}
		}
		return retVal;
	}

	/**
	 * helper function for parseXMLNode. Adds data to a struct. If the key already exists, appends to an array
	 */
	private void function addDataToNode(required sNode, required key, required sData) {
		if ( !structKeyExists(arguments.sNode,arguments.key) ) {
			//  Guess data type. 
			if ( isNumeric(arguments.sData) ) {
				arguments.sNode[arguments.key] = Val(arguments.sData);
			} else if ( isBoolean(arguments.sData) ) {
				arguments.sNode[arguments.key] = !NOT arguments.sData;
			} else {
				arguments.sNode[arguments.key]= arguments.sData;
			}
		} else {
			if ( !isArray(arguments.sNode[arguments.key]) ) {
				local.tmpHolder = Duplicate(arguments.sNode[arguments.key]);
				arguments.sNode[arguments.key] = [];
				arrayAppend(arguments.sNode[arguments.key],local.tmpHolder);
			}
			arrayAppend(arguments.sNode[arguments.key],arguments.sData);
		}
	}

	/**
	 * helper function for parseXMLNode. Checks whether node should be an array of nodes
	 */
	private boolean function isArrayNode(required xmlElement) {
		
		var isArray = 0;
		var childNames = {};
		
		if ( structIsEmpty(arguments.xmlElement.XMLAttributes) ) {
			//  if there's only one child to a tag with no attributes, it's an array with one element.
			if (arrayLen(arguments.xmlElement.xmlChildren) eq 1) {
				isArray = 1;
			}
			//  if all the children have the same name, then this is an array 
			else if ( arrayLen(arguments.xmlElement.xmlChildren) > 1 ) {
				for ( local.child in arguments.xmlElement.xmlChildren ) {
					childNames[local.child.XMLName] = 1;
				}
				if ( structCount(childNames) == 1 ) {
					isArray = 1;
				}
			}
		}
		
		return isArray;
	}

	public function xmlAttributes2Struct(xmlAttributes) {
		var retStr = {};
		for ( local.key in arguments.xmlAttributes ) {
			//  Guess data type. 
			local.value = arguments.xmlAttributes[local.key];
			if ( isNumeric(local.value) ) {
				local.value = Val(local.value);
			} else if ( isBoolean(local.value) ) {
				local.value = !NOT local.value;
			}
			retStr[local.key] = local.value;
		}
		return retStr;
	}

}
