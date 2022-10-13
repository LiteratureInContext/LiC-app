xquery version "3.1";
(:~ 
 : Creates and manages course packs.
 : Create new coursepacks
 : Add to existing coursepacks
:)

(: Import eXist modules:)
import module namespace config="http://LiC.org/config" at "../config.xqm";
import module namespace data="http://LiC.org/data" at "data.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "../content-negotiation/tei2html.xqm";
import module namespace functx="http://www.functx.com";

(: Import application modules. :)
(:import module namespace tei2html="http://syriaca.org/tei2html" at "content-negotiation/tei2html.xqm";:)

(: Namespaces :)
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace http="http://expath.org/ns/http-client";


(:Add an id to each node so it can be used by the data:get-fragment-from-doc function. For selected texts:)
declare function local:addID($nodes as node()*) as item()* {
    for $node in $nodes
    return 
        typeswitch($node)
            case text() return $node
            case comment() return ()
            case element() return
                element {name($node)}
                        {(
                            if($node/@id or $node/@xml:id) then () else attribute {'id'} {generate-id($node)},
                            for $a in $node/@*
                            return attribute {node-name($a)} {string($a)},local:addID($node/node())
                            )}
            default return local:addID($node/node())
};

declare variable $local:user {
    if(request:get-attribute($config:login-domain || ".user")) then request:get-attribute($config:login-domain || ".user") 
    else sm:id()/sm:id/sm:real/sm:username/string(.)
};

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
    let $id := concat(replace($coursepackTitle,'\s|''|:|;|/|\\|,',''),$num)
    let $newcoursepack :=  
        <coursepack id="{$id}" title="{$coursepackTitle}" user="{$local:user}">
            {( $desc,
               for $work at $n in $works?*
               let $workID := $work?id
               group by $groupID := $workID
               return 
               (<work id="{$groupID}" num="{$n}">
                <title>{$work?title[1]}</title>
                {for $text in $work?text
                    let $regex := fn:analyze-string($text,'id="([^"]*)"')
                    let $m1 := $regex//fn:match[1]/fn:group/text()
                    let $m2 := $regex//fn:match[last()]/fn:group/text()
                    let $nodes := doc(xs:anyURI(xmldb:encode-uri($workID)))
                    let $nodesIDs := local:addID($nodes)
                    let $ms1 := $nodesIDs/descendant::*[@id=$m1 or @xml:id=$m1 or @exist:id=$m1] 
                    let $ms2 := $nodesIDs/descendant::*[@id=$m2 or @xml:id=$m2 or @exist:id=$m2] 
                    return 
                       <text>{(:$work?text:)data:get-fragment-from-doc($nodesIDs, $ms1, $ms2, true(), true(),'')}</text>
                 }
                </work> 
                (:,local:update-work($workID, $id, $coursepackTitle, $coursepack(1)('coursepackDesc')):)
               )
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
    let $coursepack := collection($config:app-root || '/coursepacks')/coursepack[@id = $coursepackID]
    let $coursepackTitle := string($coursepack/@title)
    let $numWorks := count($coursepack//work)
    let $desc := $coursepack//desc/text()
    let $insertWorks :=  
               for $work at $n in $works?*
               let $workID := $work?id
               let $num := $n + $numWorks
               group by $groupID := $workID
               return 
               (<work id="{$groupID}" num="{$num}">
                <title>{$work?title[1]}</title>
                
                {
                    for $text in $work?text
                    let $regex := fn:analyze-string($text,'id="([^"]*)"')
                    let $m1 := $regex//fn:match[1]/fn:group/text()
                    let $m2 := $regex//fn:match[last()]/fn:group/text()
                    let $nodes := doc(xs:anyURI(xmldb:encode-uri($workID)))
                    let $nodesIDs := local:addID($nodes)
                    let $ms1 := $nodesIDs/descendant::*[@id=$m1 or @xml:id=$m1 or @exist:id=$m1] 
                    let $ms2 := $nodesIDs/descendant::*[@id=$m2 or @xml:id=$m2 or @exist:id=$m2] 
                    return 
                       <text>{(:$work?text:)data:get-fragment-from-doc($nodesIDs, $ms1, $ms2, true(), true(),'')}</text>
                (:   for $text in $work?text) 
                    let $regex := fn:analyze-string($text,'id="([^"]*)"')
                    let $m1 := $regex//fn:match[1]/fn:group/text()
                    let $m2 := $regex//fn:match[last()]/fn:group/text()
                    let $nodes := local:addID(doc(xmldb:encode-uri($workID))//tei:TEI)
                    let $ms1 := $nodes/descendant::*[@id=$m1 or @xml:id=$m1 or @exist:id=$m1] 
                    let $ms2 := $nodes/descendant::*[@id=$m2 or @xml:id=$m2 or @exist:id=$m2] 
                    return
                    <text>{(:$work?text:)data:get-fragment-from-doc($nodes, $ms1, $ms2, true(), true(),'')}</text>
                :) }
                </work> 
               (:,local:update-work($workID, $coursepackID, $coursepackTitle, $desc):)
               )
    return 
        try { 
            (update insert $insertWorks into $coursepack, 
            <response>
                <coursepack id="{$coursepackID}"/>
                <works>{$insertWorks}</works>
                Updated!
            </response>)
        } catch * {
            (response:set-status-code( 500 ),
            <response status="fail">
                <message>Failed to add new coursepack {$coursepackID} : {concat($err:code, ": ", $err:description)}</message>
            </response>)
        }
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
    let $response := local:create-new-coursepack($json-data)
    let $coursepackID := tokenize(substring-before(string-join($response,''),'.xml'),'/')[last()]
    return 
        <response xmlns="http://www.w3.org/1999/xhtml">
            <div class="coursepack">
                <div class="bg-info hidden">{$response}</div>
                <h4>Coursepack Title: {$coursepackTitle}</h4>
                {$response}
                <ul>{
                    for $work in $works?*
                    return 
                        <li>{$work?title[1]}</li>
                 }</ul>
                 <a href="{$config:nav-base}/coursepack/{$coursepackID}">Go to Coursepack</a><br/>
                 <a href="{$config:nav-base}/coursepack.html">See all Coursepacks</a>
            </div>
        </response>
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
    let $response := local:update-coursepack($json-data)
    let $coursepackID := string($response/coursepack/@id)
    return 
        <response status="success" xmlns="http://www.w3.org/1999/xhtml">
            <div class="coursepack">
                <div class="bg-info hidden">{$response}</div>
                <h4>Coursepack Updated</h4>
                <ul>{
                    for $work in $works?*
                    return 
                        <li>{$work?title[1]}</li>
                 }</ul>
                 <a href="{$config:nav-base}/coursepack/{$coursepackID}">Go to Coursepack</a><br/>
                 <a href="{$config:nav-base}/coursepack.html">See all Coursepacks</a>
            </div>
        </response>    
};

(:~ 
 : Create HTML response to create-new-coursepack request  
 : @param $data works and coursepack information passed from JavaScript post
 :)
declare function local:delete-coursepack-response(){
    let $coursepackID := request:get-parameter('coursepackid', '')
    let $coursepack := collection($config:app-root || '/coursepacks')/coursepack[@id = $coursepackID]
    return 
        try { 
            (xmldb:remove(xmldb:encode-uri($config:app-root || '/coursepacks'), concat($coursepackID,'.xml')),
                <response status="success" xmlns="http://www.w3.org/1999/xhtml">
                    <goto id="url">{concat($config:nav-base, '/coursepack.html')}</goto>
                </response> 
                (:response:redirect-to(xs:anyURI(concat($config:nav-base, '/coursepack.html'))):) 
                )
            } catch * {
                ((:response:set-status-code( 500 ),:)
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
    let $coursepack := collection($config:app-root || '/coursepacks')/coursepack[@id = $coursepackID]
    return 
        try { 
            (for $work in $coursepack//work[@id = $workID]
             return update delete $work,
                <response status="success">
                    <message>Work removed.</message>
                </response>)
            } catch * {
                (response:set-status-code( 500 ),
                <response status="fail">
                    <message>Failed to Delete coursepack {$coursepackID} : {concat($err:code, ": ", $err:description)}</message>
                </response>)
            }
};

(:~ 
 : Check current user credentials against resource  
 : @param $user user id
 : @param $data json data
 :)
declare function local:authenticate($data as item()*){
    let $action := request:get-parameter('action', '')
    return 
        if(sm:get-user-groups($local:user)  = 'lic' or 'dba') then 
            if($action = ('update','delete','deleteWork')) then
                let $coursepackID := if(request:get-parameter('coursepackid', '') != '') then
                            request:get-parameter('coursepackid', '')
                         else if(not(empty($data))) then
                            let $payload := util:base64-decode($data)
                            let $json-data := parse-json($payload)
                            let $coursepack := $json-data?coursepack
                            let $id := $coursepack(1)('coursepackID')
                            return $id
                         else 'no data'
                let $coursepack := collection($config:app-root || '/coursepacks')/coursepack[@id = $coursepackID]
                let $coursepack-permissions := sm:get-permissions(xs:anyURI(document-uri(root($coursepack))))
                return
                    if(($coursepack-permissions/*/@owner = $local:user) or ($coursepack-permissions/@user = $local:user) or ($local:user = 'admin')) then 
                        if(request:get-parameter('action', '') = 'update') then 
                            (response:set-header("Content-Type", "text/html"),
                            <output:serialization-parameters>
                                <output:method value='html5'/>
                                <output:media-type value='text/html'/>
                            </output:serialization-parameters>, local:update-coursepack-response($data))        
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
                        else() 
                    else 
                        (response:set-header("Content-Type", "text/html"),
                        <output:serialization-parameters>
                            <output:method value='html5'/>
                            <output:media-type value='text/html'/>
                        </output:serialization-parameters>,
                        response:set-status-code( 401 ),
                                <response status="fail">
                                    <message>You do not have permission to edit this resource. Please log in. </message>
                                </response>)
            else
                (response:set-header("Content-Type", "text/html"),
                <output:serialization-parameters>
                    <output:method value='html5'/>
                    <output:media-type value='text/html'/>
                </output:serialization-parameters>, local:create-new-coursepack-response($data))
        else 
            (response:set-header("Content-Type", "text/html"),
                <output:serialization-parameters>
                    <output:method value='html5'/>
                    <output:media-type value='text/html'/>
                </output:serialization-parameters>,
                response:set-status-code( 401 ),
                        <response status="fail">
                            <message>You must be logged in to use this feature.</message>
                        </response>)        
};

(:~
 : Get and process post data.
:)
let $post-data := 
                if(request:get-parameter('target-texts', '') != '') then string-join(request:get-parameter('target-texts', ''),',')
                else if(request:get-parameter('coursepack', '') != '') then request:get-parameter('coursepack', '')
                else if(not(empty(request:get-data()))) then request:get-data()
                else ()
return local:authenticate($post-data)                      