xquery version "3.0";

import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";
import module namespace config="http://LiC.org/config" at "modules/config.xqm";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

(:Variables for login module. :)
declare variable $userParam := request:get-parameter("user", ());
declare variable $logout := request:get-parameter("logout", ());
        
if ($exist:path eq '') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{request:get-uri()}/"/>
    </dispatch>
    
else if ($exist:path eq "/") then
    (: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>

(: Log users in or out :)
else if ($exist:resource = "login") then 
    (util:declare-option("exist:serialize", "method=json media-type=application/json"),
    try {
        let $loggedIn := login:set-user($config:login-domain, (), true())
        let $user := request:get-attribute($config:login-domain || ".user")
        return
           if ($user and sm:list-users() = $user) then
                <response>
                    <user>{$user}</user>
                    <logged>{$loggedIn}</logged>
                </response>
            else if($userParam and sm:list-users() = $userParam) then
                <response>
                    <user>{$user}</user>
                    <logged>{$loggedIn}</logged>
                </response>
            else if($logout = 'true') then 
               <response>
                    <success>You have been logged out.</success>
                </response> 
            else (
                <response>
                    <fail>Wrong user or password user: {$user} userParam: {$userParam}</fail>
                </response>
            )
    } catch * {
        <response>
            <fail>{$err:description}</fail>
        </response>
    })
    
(: Check user credentials :)
else if ($exist:resource = "userInfo") then 
    ((:util:declare-option("exist:serialize", "method=json media-type=application/json"),:)
     let $currentUser := 
                if(request:get-attribute($config:login-domain || ".user")) then request:get-attribute($config:login-domain || ".user") 
                else xmldb:get-current-user()
    let $group :=  
                if($currentUser) then 
                    sm:get-user-groups($currentUser) 
                else () 
    return
    if($group = 'lic') then
            (response:set-status-code( 200 ), 
            response:set-header("Content-Type", "text/html"),
            <response status="success" xmlns="http://www.w3.org/1999/xhtml">
                <message>logged in.</message>
            </response>)
        else 
            (response:set-status-code( 401 ),
            response:set-header("Content-Type", "text/html"),
            <response status="success" xmlns="http://www.w3.org/1999/xhtml">
                <message>Please register or login</message>
            </response>)
   )
    
(: Resource paths starting with $app-root are resolved relative to app :)
else if (contains($exist:path, "/$nav-base/")) then
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{concat($exist:controller,'/', substring-after($exist:path, '/$nav-base/'))}">
                <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
            </forward>
        </dispatch>        

(: Resource paths starting with $shared are loaded from the shared-resources app :)
else if (contains($exist:path, "/$shared/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/shared-resources/{substring-after($exist:path, '/$shared/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>

(: Set paths for coursepacks :)
else if($exist:resource = 'coursepack') then 
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/coursepack.html">
        <set-header name="Cache-Control" value="no-cache"/>
        </forward>
        <view>
            <forward url="{$exist:controller}/modules/view.xql">
            <set-header name="Cache-Control" value="no-cache"/>
            </forward>
            <!--<set-header name="Cache-Control" value="no-cache"/>-->
        </view>
        <error-handler>
            <forward url="{$exist:controller}/error-page.html" method="get"/>
            <forward url="{$exist:controller}/modules/view.xql"/>
        </error-handler>
    </dispatch>   
else if(contains($exist:path, "/coursepack/") or $exist:resource = 'coursepack') then 
    let $document := substring-after($exist:path,'/coursepack/')
    let $id := if(ends-with($document,('.html','/html'))) then
                    replace($document,'/html|.html','')
               else if(ends-with($document,('.xml','.tei','.pdf','.epub','.json','.atom','.rdf','.ttl','.txt'))) then
                    replace($document,'.xml|.tei|.pdf|.epub|.json|.atom|.rdf|.ttl|.txt','')
               else $document
    let $document := substring-after($exist:path,'/coursepack/')
    let $format := fn:tokenize($document, '\.')[fn:last()]
    return 
    (: Sends to content-negotiation module to handle /atom, /tei,/rdf:)
    if (ends-with($exist:path, ('.xml','.tei','.pdf','.epub','.json','.atom','.rdf','.ttl','.txt'))) then
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">        
            <forward url="{$exist:controller}/modules/content-negotiation/content-negotiation.xql">
                <add-parameter name="coursepack" value="true"/>
                <add-parameter name="id" value="{$id}"/>
                <add-parameter name="format" value="{$format}"/>
                <set-header name="Cache-Control" value="no-cache"/>
            </forward>
        </dispatch>
    else 
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/coursepack.html"/>
        <view>
            <forward url="{$exist:controller}/modules/view.xql">
                <add-parameter name="id" value="{$id}"/>
                <set-header name="Cache-Control" value="no-cache"/>
            </forward>
        </view>
        <error-handler>
            <forward url="{$exist:controller}/error-page.html" method="get"/>
            <forward url="{$exist:controller}/modules/view.xql"/>
        </error-handler>
    </dispatch>
(: Set path for works, assumes '/work/' in the path. :)  
else if(contains($exist:path, "/work/")) then
    let $document := substring-after($exist:path,'/work/')
    let $format := fn:tokenize($document, '\.')[fn:last()]
    let $id := if(contains($document,'.')) then substring-before($document,'.') else $document
    return 
    (: Sends to content-negotiation module to handle /atom, /tei,/rdf:)
    if (ends-with($exist:path, ('.xml','.tei','.pdf','.epub','.json','.atom','.rdf','.ttl'))) then
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">        
            <forward url="{$exist:controller}/modules/content-negotiation/content-negotiation.xql">
                <add-parameter name="doc" value="{$id}"/>
                <add-parameter name="format" value="{$format}"/>
            </forward>
        </dispatch>
    else             
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$exist:controller}/work.html"></forward>
            <view>
                <forward url="{$exist:controller}/modules/view.xql">
                    <add-parameter name="doc" value="{$id}"/>
                </forward>
            </view>
            <error-handler>
                <forward url="{$exist:controller}/error-page.html" method="get"/>
                <forward url="{$exist:controller}/modules/view.xql"/>
            </error-handler>
        </dispatch>  
else if (ends-with($exist:resource, ".html")) then
    (: the html page is run through view.xql to expand templates :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="{$exist:controller}/modules/view.xql">
                <set-header name="Cache-Control" value="no-cache"/>
            </forward>
        </view>
		<error-handler>
			<forward url="{$exist:controller}/error-page.html" method="get"/>
			<forward url="{$exist:controller}/modules/view.xql"/>
		</error-handler>
    </dispatch>

else
    (: everything else is passed through :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>
