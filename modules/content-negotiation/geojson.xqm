xquery version "3.0";

module namespace geojson="http://syriaca.org/srophe/geojson";
(:~
 : Module returns coordinates as geoJSON
 : Formats include geoJSON 
 : @author Winona Salesky <wsalesky@gmail.com>
 : @authored 2014-06-25
:)

import module namespace config="http://LiC.org/apps/config" at "../config.xqm";
import module namespace http="http://expath.org/ns/http-client";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

(:~
 : Serialize XML as JSON
:)
declare function geojson:geojson($nodes as node()*, $mode){
   serialize(geojson:json-wrapper($nodes, $mode,()), 
        <output:serialization-parameters>
            <output:method>json</output:method>
        </output:serialization-parameters>)
};

declare function geojson:geojson($nodes as node()*, $mode, $id){
   serialize(geojson:json-wrapper($nodes, $mode, $id), 
        <output:serialization-parameters>
            <output:method>json</output:method>
        </output:serialization-parameters>)
};
(:~
 : Build root element for geojson output
:)
declare function geojson:json-wrapper($nodes as node()*, $mode, $id) as element()*{
    <root>
        <type>FeatureCollection</type>
        <features>
            {
            let $nodes := $nodes/descendant-or-self::tei:place[descendant::tei:geo]
            let $count := count($nodes)
            for $n in $nodes
            return 
            if($mode = 'subset') then
                if($id != '') then geojson:geojson-object-work($n, $count, $id)
                else geojson:geojson-object-relation($n, $count)
            else geojson:geojson-object-relation($n, $count)
            }
        </features>
    </root>
};

declare function geojson:geojson-object-work($node as node()*, $count as xs:integer?, $id) as element()*{
for $r in $node/descendant::tei:relation[@active = $id]
let $id := $node/descendant::tei:idno[1]
let $title := $node/descendant::tei:placeName[1]
let $coords := $node/descendant::tei:geo[1]
let $workID := string($r/@active)
let $link := concat($config:nav-base,'/work',substring-before(replace($workID,$config:data-root,''),'.xml'))
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
                <id>{$link}</id>
                <title>{normalize-space(($r/tei:desc/tei:title/text()))}</title>
            </relation> 
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
:)
(:
declare function geojson:geojson-object($node as node()*, $count as xs:integer?) as element()*{
for $r in $node/descendant::tei:relation
let $place := $node/ancestor::tei:place
let $id := $place/descendant-or-self::tei:idno[1]
let $title := $place/descendant-or-self::tei:placeName[1]
let $coords := $place/descendant-or-self::tei:geo[1]
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
            let $relations := $node/descendant-or-self::tei:relation[@active != '']
             for $r in $relations
             return 
                <relation>
                {(if(count($relations) = 1) then attribute {xs:QName("json:array")} {'true'} else())}
                    <id>{string($r/@active)}</id>
                    <title>{normalize-space(($r/tei:desc/tei:title/text()))}</title>
                </relation> 
             }   
        </properties>
    </json:value>
};
:)
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
let $workID := string($r/@active)
let $link := concat($config:nav-base,'/work',substring-before(replace($workID,$config:data-root,''),'.xml'))
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
                <id>{$link}</id>
                <title>{normalize-space(($r/tei:desc/tei:title/text()))}</title>
            </relation> 
        </properties>
    </json:value>
};