xquery version "3.1";
(:~ 
 : Creates and manages course packs.
 : Create new coursepacks
 : Add to existing coursepacks
:)

(: Import eXist modules:)
import module namespace config="http://LiC.org/apps/config" at "../config.xqm";
import module namespace data="http://LiC.org/apps/data" at "data.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "../content-negotiation/tei2html.xqm";
import module namespace functx="http://www.functx.com";
import module namespace util="http://exist-db.org/xquery/util";
(: For running commits to github, backing up courspacks :)
import module namespace gitcommit="http://syriaca.org/srophe/gitcommit" at "gitCommit.xql";

(: Import application modules. :)
(:import module namespace tei2html="http://syriaca.org/tei2html" at "content-negotiation/tei2html.xqm";:)

(: Namespaces :)
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace http="http://expath.org/ns/http-client";

(:let $save := gitcommit:run-commit($post-processed-xml, concat($github-path,$file-name), concat("User submitted content for ",$file-name)):)


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

declare variable $local:github-path {
    if(request:get-parameter('githubPath','') != '') then request:get-parameter('githubPath','') else 'coursepacks/'
};

declare variable $local:github-repo {
    if(request:get-parameter('githubRepo','') != '') then request:get-parameter('githubRepo','') else 'blogs'
};

declare variable $local:github-owner {
    if(request:get-parameter('githubOwner','') != '') then request:get-parameter('githubOwner','') else 'wsalesky'
};

declare variable $local:github-branch {
    if(request:get-parameter('githubBranch','') != '') then request:get-parameter('githubBranch','') else 'master'
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
    let $desc := if($coursepack(1)('coursepackDesc')) then <desc id="coursepackNotes">{$coursepack(1)('coursepackDesc')}</desc> else ()
    let $id := concat(replace(replace($coursepackTitle, "[^a-zA-Z0-9 - |]", ''),'\s',''),$num)
    let $userFullName := sm:get-account-metadata($local:user, xs:anyURI('http://axschema.org/namePerson'))
    let $newcoursepack :=  
        <coursepack id="{$id}" title="{$coursepackTitle}" user="{$local:user}">
            <instructor>{if($userFullName != '') then $userFullName else $local:user}</instructor>
            {($desc,
               for $work at $n in $works?*
               let $workID := $work?id
               group by $groupID := $workID
               return 
               (<work id="{$groupID}" num="{$n}">
                <title>{$work?title[1]}</title>
                {
                    let $record := doc(xmldb:encode-uri($id))
                    let $date := 
                        if($record/descendant::tei:sourceDesc/descendant::tei:imprint/tei:date) then
                            $record/descendant::tei:sourceDesc/descendant::tei:imprint[1]/tei:date[1]
                        else $record/descendant::tei:publicationStmt[1]/tei:date[1]
                    let $author :=
                        if($record/descendant::tei:sourceDesc/descendant::tei:author) then
                            $record/descendant::tei:sourceDesc/descendant::tei:author[1]
                        else $record/descendant::tei:author[1]
                    return 
                        (
                        <author>{$author}</author>,
                        <date>{$date}</date>
                        )
                }
                {for $text in $work?text
                    let $regex := fn:analyze-string($text,'id="([^"]*)"')
                    let $m1 := $regex//fn:match[1]/fn:group/text()
                    let $m2 := $regex//fn:match[last()]/fn:group/text()
                    let $nodes := doc(xs:anyURI(xmldb:encode-uri($workID[1])))
                    let $nodesIDs := local:addID($nodes)
                    let $ms1 := $nodesIDs/descendant::*[@id=$m1 or @xml:id=$m1 or @exist:id=$m1] 
                    let $ms2 := $nodesIDs/descendant::*[@id=$m2 or @xml:id=$m2 or @exist:id=$m2] 
                    return 
                       <text>{parse-xml-fragment($work?text)}</text>
                 }
                </work> 
                (:,local:update-work($workID, $id, $coursepackTitle, $coursepack(1)('coursepackDesc')):)
               )
            )}
        </coursepack>
    return 
        try { 
            (
            let $save := xmldb:store(xmldb:encode-uri($config:app-root || '/coursepacks'), xmldb:encode-uri(concat($id[1],'.xml')), $newcoursepack)
                        (:gitcommit:run-commit($newcoursepack, concat($local:github-path,$id), concat("Created New coursepack ",$id)),:)
            return 'Your coursepack has been created.' 
            )
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
    let $updateWorks := 
               for $work at $n in $works?*
               let $workID := $work?id
               let $num := $n + $numWorks
               let $coursepackWork := $coursepack//*[@id = $workID]
               let $text := 
                    for $text in $work?text
                    let $textString := replace(string($text),'&lt;br&gt;','&lt;br/&gt;')
                    let $regex := fn:analyze-string($text,'id="([^"]*)"')
                    let $m1 := $regex//fn:match[1]/fn:group/text()
                    let $m2 := $regex//fn:match[last()]/fn:group/text()
                    let $nodes := doc(xs:anyURI(xmldb:encode-uri($workID[1])))
                    let $nodesIDs := local:addID($nodes)
                    let $ms1 := $nodesIDs/descendant::*[@id=$m1 or @xml:id=$m1 or @exist:id=$m1] 
                    let $ms2 := $nodesIDs/descendant::*[@id=$m2 or @xml:id=$m2 or @exist:id=$m2] 
                    return 
                       <text>{parse-xml-fragment($textString)}</text>
               let $workRec := 
                    <work id="{$workID}" num="{$num}">
                        <title>{$work?title[1]}</title>
                        {
                            let $record := doc(xmldb:encode-uri($workID))
                            let $date := 
                                if($record/descendant::tei:sourceDesc/descendant::tei:imprint/tei:date) then
                                    $record/descendant::tei:sourceDesc/descendant::tei:imprint[1]/tei:date[1]
                                else $record/descendant::tei:publicationStmt[1]/tei:date[1]
                            let $author :=
                                if($record/descendant::tei:sourceDesc/descendant::tei:author) then
                                    $record/descendant::tei:sourceDesc/descendant::tei:author[1]
                                else $record/descendant::tei:author[1]
                            return 
                                (
                                <author>{$author}</author>,
                                <date>{$date}</date>
                                )
                        }
                        {$text}
                        </work>
               return 
                    if($coursepack//work[@id = $workID]) then 
                        if($text != '') then
                           update insert $text into $coursepack//work[@id = $workID]
                        else ()
                    else update insert $workRec into $coursepack
    return 
        try { 
            ($updateWorks (:,
            gitcommit:run-commit($coursepack, concat($local:github-path,$coursepackID), concat("Updataed coursepack ",$coursepackID)):),
            <response>
                <coursepack id="{$coursepackID}"/>
                <works>{$updateWorks}</works>
                Your Coursepack has been Updated!
            </response>)
        } catch * {
            (response:set-status-code( 500 ),
            <response status="fail">
                <message>Failed to add new coursepack {$coursepackID} : {concat($err:code, ": ", $err:description)}</message>
            </response>)
        }
};

(:~
 : Update an existing coursepack. 
 : @param $data works and coursepack information passed from JavaScript post
:)
declare function local:update-notes($data as item()*, $coursepackID, $noteID){
    let $JSON := parse-json($data)
    let $noteJSON := $JSON?note
    let $noteCleaned := replace($noteJSON, '&amp;nbsp;','&#160;')
    let $noteText := parse-xml-fragment($noteCleaned)
    let $coursepack := collection($config:app-root || '/coursepacks')/coursepack[@id = $coursepackID]
    let $note := $coursepack/descendant-or-self::*[@id=$noteID]
    return 
        try { 
            (update value $note with $noteText/child::*, 
            <response status="success">
                <message>Your Coursepack has been Updated! {$noteText}</message>
            </response>)
        } catch * {
            (response:set-status-code( 500 ),
            <response status="fail">
                <message>Failed to add new coursepack {$coursepackID} : {concat($err:code, ": ", $err:description)} {$noteText}</message>
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
                <ul>{(:
                    for $work in $works?*
                    return 
                        <li>{$work?title[1]}</li>
                 :)''}</ul>
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
    let $coursepackID := $coursepack(1)('coursepackID')
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
declare function local:update-notes-response($data as item()*, $coursepackID, $noteID){
    let $payload := util:base64-decode($data)
    let $response := local:update-notes($payload, $coursepackID, $noteID)
    return 
        <response status="success" xmlns="http://www.w3.org/1999/xhtml">
            <div class="coursepack">
                <div class="bg-info hidden">{$response}</div>
                <h4>Coursepack Updated</h4>
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
 : Create HTML response to create-new-coursepack request  
 : @param $data works and coursepack information passed from JavaScript post
 :)
declare function local:editCoursepack($data){
    let $coursepackID := request:get-parameter('coursepackid', '')
    let $newTitle := request:get-parameter('title', '')
    let $newDesc := request:get-parameter('desc', '')
    let $coursepack := collection($config:app-root || '/coursepacks')/coursepack[@id = $coursepackID]
    let $title := $coursepack/@title
    let $desc := $coursepack/*:desc[@id="coursepackNotes"]
    return 
        try { 
            ( if($newTitle != '') then 
                   update value $title with $newTitle
              else (),
              if($newDesc != '') then
                update value $desc with $newDesc
              else (),
                <response status="success">
                    <message>Updated.</message>
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
            if(request:get-parameter('coursepackid', '') != '' ) then
                local:editCoursepack($data)
            else if($action = ('update','delete','deleteWork')) then
                if(request:get-parameter('content', '') = 'notes') then
                            if(not(empty($data))) then
                                let $coursepackID := request:get-parameter('coursepackid', '')
                                let $noteID := request:get-parameter('noteid', '')
                                return 
                                     (response:set-header("Content-Type", "text/html"),
                                     <output:serialization-parameters>
                                         <output:method value='html5'/>
                                         <output:media-type value='text/html'/>
                                     </output:serialization-parameters>, local:update-notes-response($data, $coursepackID, $noteID))  
                             else 'no data'
                             
                else 
                    let $coursepackID := 
                             if(request:get-parameter('coursepackid', '') != '') then
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