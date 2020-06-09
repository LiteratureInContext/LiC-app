xquery version "3.1";

import module namespace config="http://LiC.org/config" at "../modules/config.xqm";
import module namespace d3xquery="http://syriaca.org/d3xquery" at "d3xquery.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace json="http://www.json.org";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare variable $id {request:get-parameter('id', '')};
declare variable $record {request:get-parameter('recordID', '')};
declare variable $type {request:get-parameter('type', '')};
declare variable $relationship {request:get-parameter('relationship', '')};
declare variable $collectionPath {request:get-parameter('collection', '')}; 
 


let $data := 
             if(request:get-parameter('data', '') = 'persNames') then
                doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person
             else 
                doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person | 
                doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))//tei:place 
(:d3xquery:build-graph-type($data, $id, $relationship, $type):)
return
    (response:set-header("Access-Control-Allow-Origin", "*"),
     response:set-header("Access-Control-Allow-Methods", "GET, POST"),
     response:set-header("Content-Type", "application/json"),
     serialize(d3xquery:build-graph-type($data, $id, $relationship, $type), 
        <output:serialization-parameters>
            <output:method>json</output:method>
        </output:serialization-parameters>))