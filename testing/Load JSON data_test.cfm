<!--- 

# Load json data test


## Usage:

http://local.clikpic.com/customtags/cfscript/testing/load json data_test.cfm

## Notes:



## Status:


## History:

|------------|-----------|------------------------------------
| 2018-02-08 | THP       |   Created.

--->

<cfscript>
request.jsonutils = new utils.jsondata();
variables.siteResourcesTypes = request.jsonutils.loadJSONDataFile(ExpandPath("site_resources_types.json"));
writeDump(variables.siteResourcesTypes);
</cfscript>

