xquery version "3.1";
(:~  
 : Basic data interactions, returns raw data for use in other modules  
 : Not a library module
:)

import module namespace config="http://LiC.org/apps/config" at "config.xqm";
import module namespace data="http://LiC.org/apps/data" at "lib/data.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "content-negotiation/tei2html.xqm";
import module namespace maps="http://LiC.org/apps/maps" at "lib/maps.xqm";

import module namespace functx="http://www.functx.com";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace util="http://exist-db.org/xquery/util";

(:
 search
:)

declare function local:search(){
for $r in collection($config:data-root)//tei:TEI[ft:query(.,())]

};


'test results'