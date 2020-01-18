xquery version "3.0";

module namespace geojson="http://syriaca.org/srophe/geojson";
(:~
 : Module returns coordinates as geoJSON
 : Formats include geoJSON 
 : @author Winona Salesky <wsalesky@gmail.com>
 : @authored 2014-06-25
:)

import module namespace config="http://LiC.org/config" at "../config.xqm";
import module namespace http="http://expath.org/ns/http-client";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

(:~
 : Serialize XML as JSON
:)
declare function geojson:geojson($nodes as node()*){
   serialize(geojson:json-wrapper($nodes), 
        <output:serialization-parameters>
            <output:method>json</output:method>
        </output:serialization-parameters>)        
};

(:~
 : Build root element for geojson output
:)
declare function geojson:json-wrapper($nodes as node()*) as element()*{
    <root>
        <type>FeatureCollection</type>
        <features>
            {
            let $nodes := $nodes//tei:place[descendant::tei:geo]
            let $count := count($nodes)
            for $n in $nodes
            return (:geojson:geojson-object($n, $count):) geojson:geojson-object-relation($n, $count)
            }
        </features>
    </root>
};

(:~
 : Build geoJSON object for each node with coords
 : Sample data passed to geojson-object
  <place xmlns="http://www.tei-c.org/ns/1.0">
    <idno></idno>
    <title></title>
    <desc></desc>
    <location>lat long</location>  
  </place>
  Note: geojson is long lat
:)
declare function geojson:geojson-object($node as node()*, $count as xs:integer?) as element()*{
let $id := $node/descendant::tei:idno[1]
let $title := $node/descendant::tei:placeName[1]
let $coords := $node/descendant::tei:geo[1]
let $lat := $coords/tei:lat
let $long := $coords/tei:long 
return 
    <json:value>
        {(if(count($count) = 1) then attribute {xs:QName("json:array")} {'true'} else())}
        <type>Feature</type>
        <geometry>
            <type>Point</type>
            <coordinates json:literal="true">{$long/text()}</coordinates>
            <coordinates json:literal="true">{$lat/text()}</coordinates>
        </geometry>
        <properties>
            <uri>{$id/text()}</uri>
            <name>{$title/text()}</name>
            {
             let $relations := $node/descendant::tei:relation
             for $r in $relations
             return 
                <relation>
                {(if(count($relations) = 1) then attribute {xs:QName("json:array")} {'true'} else())}
                    <id>{$r/tei:id/text()}</id>
                    <title>{$r/tei:title/text()}</title>
                </relation> 
            }
            
        </properties>
    </json:value>
};

(:~
 : Build geoJSON object for each node with coords
 : Sample data passed to geojson-object
  <place xmlns="http://www.tei-c.org/ns/1.0">
    <idno></idno>
    <title></title>
    <desc></desc>
    <location>lat long</location>  
  </place>
  Note: geojson is long lat
:)
declare function geojson:geojson-object-relation($node as node()*, $count as xs:integer?) as element()*{
for $r in $node/descendant::tei:relation
let $id := $node/descendant::tei:idno[1]
let $title := $node/descendant::tei:placeName[1]
let $coords := $node/descendant::tei:geo[1]
let $lat := $coords/tei:lat
let $long := $coords/tei:long 
return 
    <json:value>
        {(if(count($count) = 1) then attribute {xs:QName("json:array")} {'true'} else())}
        <type>Feature</type>
        <geometry>
            <type>Point</type>
            <coordinates json:literal="true">{$long/text()}</coordinates>
            <coordinates json:literal="true">{$lat/text()}</coordinates>
        </geometry>
        <properties>
            <uri>{$id/text()}</uri>
            <name>{$title/text()}</name>
            <type>{string($r/@type)}</type>
            <relation>
                <id>{$r/tei:id/text()}</id>
                <title>{$r/tei:title/text()}</title>
            </relation> 
        </properties>
    </json:value>
};