component {
	// checks if utils are defined in the server scope and
	// then creates a reference to them in variables.utils
	private void function utils(boolean reload=0) {
		
		if ( arguments.reload OR NOT structKeyExists(server,"utils") ) {
			server.utils = StructNew();
		}
		if ( arguments.reload OR NOT structKeyExists(server.utils,"utils") ) {
			server.utils["utils"] = new utils.utils();
		}
		if (arguments.reload OR NOT structKeyExists(server.utils,"xml") ) {
			server.utils["xml"] = new utils.xml();
		}
		if ( arguments.reload OR NOT structKeyExists(server.utils,"patternObj") ) {
			server.utils["patternObj"] = createObject( "java", "java.util.regex.Pattern");
		}
		if ( arguments.reload OR NOT structKeyExists(server.utils,"flexmark") ) {
			server.utils["flexmark"] =  new markdown.flexmark(attributes=1);
		}

		variables.utils = server.utils;

	}
}