xquery version "3.0";

(:~
 : Passes content to content negotiation module, if not using restxq
 : @author Winona Salesky <wsalesky@gmail.com>
 : @authored 2018-04-12
:)

import module namespace config="http://LiC.org/apps/config" at "../config.xqm";

(: Content serialization modules. :)
import module namespace cntneg="http://syriaca.org/cntneg" at "content-negotiation.xqm";
(: Data processing module. :)
import module namespace data="http://LiC.org/apps/data" at "../lib/data.xqm";

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
            (data:get-coursepacks(),data:search-coursepacks())
        else data:get-coursepacks()
    else if(request:get-parameter('id', '') != '' or request:get-parameter('doc', '') != '') then
        data:get-document()
    else if(request:get-parameter('query', '') != '') then
        let $hits := data:search()
        let $start := if(request:get-parameter('start', 1)) then request:get-parameter('start', 1) else 1
        let $perpage := if(request:get-parameter('perpage', 10)) then request:get-parameter('perpage', 10) else 10
        return 
             <results total="{count($hits)}">
             {
                for $h at $p in subsequence($hits, $start, $perpage)
                let $id := document-uri(root($h))
                return 
                    <result>
                        {$h/descendant::tei:idno}
                        {$h/descendant::tei:title}
                        <uri>{$config:nav-base}/work{substring-before(replace($id,$config:data-root,''),'.xml')}</uri>
                    </result>
             
             }</results>    
    else ()
let $format := if(request:get-parameter('format', '') != '') then request:get-parameter('format', '') else 'xml'    
return  
    if(not(empty($data))) then
        cntneg:content-negotiation($data, $format, $path)    
    else ()
    