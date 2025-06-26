xquery version "3.1";
(:~
 : XQuery to call, format and save TEI2HTML pages into the database 
:)

import module namespace http="http://expath.org/ns/http-client";
import module namespace config="http://srophe.org/srophe/config" at "config.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace srophe="https://srophe.app";

(: Helper function to recursively create a collection hierarchy. :)
declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xmldb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

declare function local:saveHTML($nodes){

};

<div>{    
if(request:get-parameter('type', '') = 'factoids') then 
    local:buildFactoids()
else if(request:get-parameter('type', '') = 'aggregate') then
    local:buildAggregate()
else if(request:get-parameter('type', '') = 'personIndex') then
    local:buildPersonIndex()
else if(request:get-parameter('type', '') = 'placeIndex') then
    local:buildPlaceIndex()    
else if(request:get-parameter('type', '') = 'keywordIndex') then
    local:buildKeywordIndex()    
else if(request:get-parameter('type', '') = 'browse') then
    local:buildBrowsePage()    
else <div>In correct parameters, see instructions. </div>
}</div>