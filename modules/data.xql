xquery version "3.1";
(:~  
 : Basic data interactions, returns raw data for use in other modules  
 : Not a library module
:)

import module namespace config="http://LiC.org/config" at "config.xqm";
import module namespace data="http://LiC.org/data" at "lib/data.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "content-negotiation/tei2html.xqm";
import module namespace maps="http://LiC.org/maps" at "lib/maps.xqm";

import module namespace functx="http://www.functx.com";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace util="http://exist-db.org/xquery/util";

(: Get posted data :)
let $results := 
            if(request:get-parameter('query', '')) then 
                if(request:get-parameter('query', '') = 'geojson') then
                    doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/geojson.xml')))
                else request:get-parameter('query', '')
            else if(request:get-parameter('getPage', '') != '') then 
                let $data := data:get-document(request:get-parameter('workID', ''))
                return tei2html:get-page($data, request:get-parameter('getPage', ''))
            else request:get-data() 

return 
    if(request:get-parameter('getPage', '') != '') then 
        $results
    else (response:set-header("Content-Type", "application/json"),
        serialize($results, 
            <output:serialization-parameters>
                <output:method>json</output:method>
            </output:serialization-parameters>))    