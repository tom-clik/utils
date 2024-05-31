// preview on /utils_testBox.cfc?method=runRemote

component extends="testbox.system.BaseSpec"{
     function beforeTests(){
     	variables.utils = new utils.utils();
     }
     
     function afterTests(){}

     function setup( currentMethod ){}
     function teardown( currentMethod ){}
	
	/**
	* @test
	*/
	function structAppend(){
		
		Struct1 = {
			"simple" = "simple value",
			"sarray" = ['one','two','three'],
			"sstruct" = {'one'=1,'two'=2,'three'=3},
			"empty" = {}
		};
		Struct2.defaults = {
			"simple" = "simple value changed",
			"extra" = "Extra added",
			"sarray" = ['four'],
			"sstruct" = {'one'='one','four'=4},
			"EMPTY" = {'one'=1,'two'=2,'three'=3}	
		};

		testStruct = Duplicate(Struct1);
		variables.utils.fnDeepStructAppend(testStruct,Struct2.defaults,0);
		expect( StructCount(testStruct.empty)).toBe( 3 );
		testStruct2 = Duplicate(Struct1);
		variables.utils.fnDeepStructAppend(testStruct2,Struct2.defaults,1);
		expect( testStruct.simple).toBe( "simple value" );
		expect( testStruct2.simple).toBe( "simple value changed" );
		expect( ArrayLen(testStruct.sarray)).toBe( 3 );
		expect( ArrayLen(testStruct2.sarray)).toBe( 1 );
		expect( testStruct.sstruct.one).toBe( "1" );
		expect( testStruct2.sstruct.one).toBe( "one" );

	}

	/**
	* @test
	*/
	function stack() {
		myStack = new utils.stack();
		myStack.push("Balls");
		expect( myStack.peek()).toBe( "Balls" );
		expect( myStack.count()).toBe( 1 );
		myStack.push("Rackets");
		expect( myStack.count()).toBe( 2 );
		expect( myStack.peek()).toBe( "Rackets" );
		expect( myStack.count()).toBe( 2 );
		expect( myStack.pop()).toBe( "Rackets" );
		expect( myStack.count()).toBe( 1 );
		expect( myStack.pop()).toBe( "Balls" );
		expect( myStack.count()).toBe( 0 );
	}
	
	/**
	* @test
	*/
	function fileSizeFormatTest() {
		testSize = 15670;
		expect( fileSizeFormat(testSize)).toBe( "15.6Kb" );
		testSize = testSize * 1000;
		expect( fileSizeFormat(testSize)).toBe( "15.6Mb" );
		testSize = testSize * 1000;
		expect( fileSizeFormat(testSize)).toBe( "15.6Gb" );
	}

	/**
	* @test
	*/
	function fnParseIniFile() {
		data = variables.utils.fnParseIniFile("testing/sample.ini");
		expect( data.section1.test1).toBe( 2 );
	}

	
}