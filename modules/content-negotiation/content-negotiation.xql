xquery version "3.0";

(:~
 : Passes content to content negotiation module, if not using restxq
 : @author Winona Salesky <wsalesky@gmail.com>
 : @authored 2018-04-12
:)

import module namespace config="http://LiC.org/config" at "../config.xqm";

(: Content serialization modules. :)
import module namespace cntneg="http://syriaca.org/cntneg" at "content-negotiation.xqm";
(: Data processing module. :)
import module namespace data="http://LiC.org/data" at "../lib/data.xqm";

(: Namespaces :)
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace http="http://expath.org/ns/http-client";

let $path := if(request:get-parameter('id', '')  != '') then 
                request:get-parameter('id', '')
             else if(request:get-parameter('doc', '') != '') then
                request:get-parameter('doc', '')
             else ()   
let $data :=
    if(request:get-parameter('coursepack', '') = 'true') then 
        if(request:get-parameter('query', '') != '') then 
            <coursepack>{(data:get-coursepacks(),data:search-coursepacks())}</coursepack>
        else <coursepack>{data:get-coursepacks()}</coursepack>
    else if(request:get-parameter('id', '') != '' or request:get-parameter('doc', '') != '') then
        data:get-document()
    else ()
let $format := if(request:get-parameter('format', '') != '') then request:get-parameter('format', '') else 'xml'    
return  
    if(not(empty($data))) then
        cntneg:content-negotiation($data, $format, $path)    
    else ()
    