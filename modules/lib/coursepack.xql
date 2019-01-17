xquery version "3.1";
(:~ 
 : Creates and manages course packs.
 : Create new coursepacks
 : Add to existing coursepacks
:)

(: Import eXist modules:)
import module namespace config="http://LiC.org/config" at "../config.xqm";
import module namespace functx="http://www.functx.com";

(: Import application modules. :)
(:import module namespace tei2html="http://syriaca.org/tei2html" at "content-negotiation/tei2html.xqm";:)

(: Namespaces :)
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace http="http://expath.org/ns/http-client";

(:~
 : Build new coursepack and save to database. 
 : @param $data works and coursepack information passed from JavaScript post
:)
declare function local:create-new-coursepack($data as item()*){
    let $num := (count(collection($config:app-root || '/coursepacks')) + 1) 
    let $coursepack := $data?coursepack
    let $coursepackTitle := $coursepack(1)('coursepackTitle')
    let $works := $coursepack(1)('works')
    let $desc := if($coursepack(1)('coursepackDesc')) then <desc>{$coursepack(1)('coursepackDesc')}</desc> else ()
    let $id := concat(replace($coursepackTitle,'\s|''|:|;',''),$num)
    let $newcoursepack :=  
        <coursepack id="{$id}" title="{$coursepackTitle}">
            {( $desc,
               for $work in $works?*
               let $workID := $work?id
               return (<work id="{$workID}">{$work?title}</work>,local:update-work($workID, $id, $coursepackTitle))
            )}
        </coursepack>
    return 
        try { 
            (xmldb:store(xmldb:encode-uri($config:app-root || '/coursepacks'), xmldb:encode-uri(concat($id,'.xml')), $newcoursepack),
            'Saved!')
        } catch * {
            (response:set-status-code( 500 ),
            <response status="fail">
                <message>Failed to add new coursepack {$id} : {concat($err:code, ": ", $err:description)}</message>
            </response>)
        }
};

(:~
 : Update an existing coursepack. 
 : @param $data works and coursepack information passed from JavaScript post
:)
declare function local:update-coursepack($data as item()*){
    let $coursepack := $data?coursepack
    let $coursepackID := $coursepack(1)('coursepackID')
    let $works := $coursepack(1)('works')
    let $coursepack := collection($config:app-root || '/coursepacks')//id($coursepackID)
    let $coursepackTitle := string($coursepack/@title)
    let $insertWorks :=  
               for $work in $works?*
               let $workID := $work?id
               return (<work id="{$workID}">{$work?title}</work>,local:update-work($workID, $coursepackID, $coursepackTitle))
    return 
        try { 
            (update insert $insertWorks into $coursepack,'Saved!')
        } catch * {
            (response:set-status-code( 500 ),
            <response status="fail">
                <message>Failed to add new coursepack {$coursepackID} : {concat($err:code, ": ", $err:description)}</message>
            </response>)
        }
};

(:~
 : Insert courspack seriesStmt into work record.
 : @param $workID work record id/document-uri
 : @param $id coursepack id
 : @param $coursepackTitle coursepack title
 :)
declare function local:update-work($workID, $id, $coursepackTitle){
if(doc($workID)) then 
    let $work := doc($workID)
    return
        if($work/descendant::tei:fileDesc/tei:seriesStmt[tei:idno[@type='coursepack'] = $id]) then () 
        else
            let $seriesStmt := 
                <seriesStmt xmlns="http://www.tei-c.org/ns/1.0">
                     <title>{$coursepackTitle}</title>
                     <idno type="coursepack">{$id}</idno>
                 </seriesStmt>
            return update insert $seriesStmt into $work/descendant::tei:fileDesc                
else ()
};

(:~ 
 : Create HTML response to create-new-coursepack request
 : @param $data works and coursepack information passed from JavaScript post
 :)
declare function local:create-new-coursepack-response($data as item()*){
    let $payload := util:base64-decode($data)
    let $json-data := parse-json($payload) 
    let $coursepack := $json-data?coursepack
    let $coursepackTitle := $coursepack?1?('coursepackTitle')
    let $works := $coursepack?1?('works')
    return 
        <repsonse xmlns="http://www.w3.org/1999/xhtml">
            <div class="coursepack">
                <div class="bg-info">{local:create-new-coursepack($json-data)}</div>
                <h4>Coursepack Title: {$coursepackTitle}</h4>
                <ul>{
                    for $work in $works?*
                    return 
                        <li>{$work?title}</li>
                 }</ul>
                 <a href="{$config:nav-base}/coursepack.html">See all Coursepacks</a>
            </div>
        </repsonse>
};

(:~ 
 : Create HTML response to create-new-coursepack request  
 : @param $data works and coursepack information passed from JavaScript post
 :)
declare function local:update-coursepack-response($data as item()*){
    let $payload := util:base64-decode($data)
    let $json-data := parse-json($payload) 
    let $coursepack := $json-data?coursepack
    let $works := $coursepack?1?('works')
    return 
        <repsonse status="success" xmlns="http://www.w3.org/1999/xhtml">
            <div class="coursepack">
                <div class="bg-info">{local:update-coursepack($json-data)}</div>
                <h4>Coursepack Updated</h4>
                <ul>{
                    for $work in $works?*
                    return 
                        <li>{$work?title}</li>
                 }</ul>
                 <a href="{$config:nav-base}/coursepack.html">See all Coursepacks</a>
            </div>
        </repsonse>
};

(:~ 
 : Create HTML response to create-new-coursepack request  
 : @param $data works and coursepack information passed from JavaScript post
 :)
declare function local:delete-coursepack-response(){
    let $coursepackID := request:get-parameter('coursepackid', '')
    let $coursepack := collection($config:app-root || '/coursepacks')//id($coursepackID)
    return 
        try { 
            (xmldb:remove(xmldb:encode-uri($config:app-root || '/coursepacks'), concat($coursepackID,'.xml')),
                response:redirect-to(xs:anyURI(concat($config:nav-base, '/coursepack.html'))))
            } catch * {
                (response:set-status-code( 500 ),
                <response status="fail">
                    <message>Failed to Delete coursepack {$coursepackID} : {concat($err:code, ": ", $err:description)}</message>
                </response>)
            }
};

(:~ 
 : Create HTML response to create-new-coursepack request  
 : @param $data works and coursepack information passed from JavaScript post
 :)
declare function local:delete-work-response(){
    let $coursepackID := request:get-parameter('coursepackid', '')
    let $workID := request:get-parameter('workid', '')
    let $coursepack := collection($config:app-root || '/coursepacks')//id($coursepackID)
    let $work := doc($workID)
    return 
        try { 
            (for $work in $coursepack//work[@id = $workID]
             return update delete $work,
             for $coursepack in $work//tei:seriesStmt[tei:idno[. = $coursepackID]]
             return update delete $coursepack,
                <response status="success">
                    <message>Work removed.</message>
                </response>
            )
            } catch * {
                (response:set-status-code( 500 ),
                <response status="fail">
                    <message>Failed to Delete coursepack {$coursepackID} : {concat($err:code, ": ", $err:description)}</message>
                </response>)
            }
};

(:~
 : Get and process post data.
:)
let $post-data := 
              if(request:get-parameter('target-texts', '') != '') then string-join(request:get-parameter('target-texts', ''),',')
              else if(request:get-parameter('coursepack', '') != '') then request:get-parameter('coursepack', '')
              else if(not(empty(request:get-data()))) then request:get-data()
              else ()
return
    if(request:get-parameter('action', '') = 'update') then 
        (response:set-header("Content-Type", "text/html"),
        <output:serialization-parameters>
            <output:method value='html5'/>
            <output:media-type value='text/html'/>
        </output:serialization-parameters>, local:update-coursepack-response($post-data))        
    else if(request:get-parameter('action', '') = 'delete') then 
        (response:set-header("Content-Type", "text/html"),
        <output:serialization-parameters>
            <output:method value='html5'/>
            <output:media-type value='text/html'/>
        </output:serialization-parameters>, local:delete-coursepack-response())
    else if(request:get-parameter('action', '') = 'deleteWork') then 
        (response:set-header("Content-Type", "text/html"),
        <output:serialization-parameters>
            <output:method value='html5'/>
            <output:media-type value='text/html'/>
        </output:serialization-parameters>, local:delete-work-response())                
    else 
        (response:set-header("Content-Type", "text/html"),
        <output:serialization-parameters>
            <output:method value='html5'/>
            <output:media-type value='text/html'/>
        </output:serialization-parameters>, local:create-new-coursepack-response($post-data))
    