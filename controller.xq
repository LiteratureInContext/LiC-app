xquery version "3.1";

(:~ The controller library contains URL routing functions.
 :
 : @see http://www.exist-db.org/exist/apps/doc/urlrewrite.xml
 :)
import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";
import module namespace config="http://LiC.org/apps/config" at "modules/config.xqm";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;


declare variable $local:login_domain := "org.exist-db.mysec";
declare variable $local:user := $local:login_domain || '.user';

(:Variables for login module. :)
declare variable $nav-base := '/exist/apps/manuForma';
declare variable $userParam := request:get-parameter("user", ());
declare variable $logout := request:get-parameter("logout", ());

let $logout := request:get-parameter("logout", ())
return
if ($exist:path eq '') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{request:get-uri()}/"/>
    </dispatch>
else if ($exist:path eq "/") then
  (: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
      <redirect url="index.html"/>
    </dispatch>
(:
 : Login a user via AJAX. Just returns a 401 if login fails.
 :)
else if ($exist:resource eq 'login') then 
    let $loggedIn := login:set-user("org.exist.login", (), false())
    let $user := request:get-attribute("org.exist.login.user")
    return (
        util:declare-option("exist:serialize", "method=json"),
        try {
            <status xmlns:json="http://www.json.org" message="{if($logout = 'true') then 'Logged out' else if($user) then 'Success' else 'Fail'}">
                <user>{$user}</user>
                {
                    if ($user) then (
                        for $item in sm:get-user-groups($user) return <groups json:array="true">{$item}</groups>,
                        <dba>{sm:is-dba($user)}</dba>
                    ) else
                        ()
                }
            </status>
        } catch * {
            response:set-status-code(401),
            <status>{$err:description}</status>
        }
    ) 
else if ($exist:path = "/admin") then (
    login:set-user("org.exist.login", (), true()),
    let $user := request:get-attribute("org.exist.login.user")
    let $route := request:get-parameter("route","")
    return
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
         <redirect url="index.html"/>
         <set-header name="Cache-Control" value="no-cache"/>
       </dispatch>
)         
(: Check user credentials :)
else if ($exist:resource = "userInfo") then( 
    ((:util:declare-option("exist:serialize", "method=json media-type=application/json"),:)
     let $currentUser := 
                if(request:get-attribute("org.exist.login.user.user")) then request:get-attribute("org.exist.login.user.user") 
                else(: xmldb:get-current-user():) sm:id()/sm:id/sm:real/sm:username/string(.)
    let $group :=  
                if($currentUser) then 
                    sm:get-user-groups($currentUser) 
                else () 
    return
        (response:set-status-code( 200 ), 
            response:set-header("Content-Type", "text/xml"),
            <response status="success" xmlns="http://www.w3.org/1999/xhtml">
                <message>
                <user>{$currentUser}</user>
                <fullName>{sm:get-account-metadata($currentUser, xs:anyURI("http://axschema.org/namePerson"))}</fullName>
                <description>{sm:get-account-metadata($currentUser, xs:anyURI("http://exist-db.org/security/description"))}</description>
                </message>
            </response>)    
   ) 
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
else if($exist:resource = 'coursepack') then (
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/coursepack.html">
        <set-header name="Cache-Control" value="no-cache"/>
        </forward>
        <view>
            <forward url="{$exist:controller}/modules/view.xq">
            <set-header name="Cache-Control" value="no-cache"/>
            </forward>
            <!--<set-header name="Cache-Control" value="no-cache"/>-->
        </view>
        <error-handler>
            <forward url="{$exist:controller}/error-page.html" method="get"/>
            <forward url="{$exist:controller}/modules/view.xq"/>
        </error-handler>
    </dispatch>   
    )
else if(contains($exist:path, "/api/")) then
(
    if(contains($exist:path, "/work/")) then
        let $document := substring-after($exist:path,'/work/')
        let $format := request:get-parameter('format', '')
        let $id := if(contains($document,'.')) then substring-before($document,'.') else $document
        return 
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">        
                <forward url="{$exist:controller}/modules/content-negotiation/content-negotiation.xql">
                    <add-parameter name="doc" value="{$id}"/>
                </forward>
            </dispatch>
    else if(contains($exist:path, "/coursepack/") or $exist:resource = 'coursepack') then 
        let $document := substring-after($exist:path,'/coursepack/')
        let $id := if(ends-with($document,('.html','/html'))) then
                        replace($document,'/html|.html','')
                   else if(ends-with($document,('.xml','.tei','.pdf','.epub','.json','.atom','.rdf','.ttl','.txt'))) then
                        replace($document,'.xml|.tei|.pdf|.epub|.json|.atom|.rdf|.ttl|.txt','')
                   else $document
        let $document := substring-after($exist:path,'/coursepack/')
        return 
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">        
                <forward url="{$exist:controller}/modules/content-negotiation/content-negotiation.xql">
                    <add-parameter name="coursepack" value="true"/>
                    <add-parameter name="id" value="{$id}"/>
                </forward>
            </dispatch>
    else if(contains($exist:path, "/search/")) then
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">        
                <forward url="{$exist:controller}/modules/content-negotiation/content-negotiation.xql"></forward>
            </dispatch>
    else ()
)
else if(contains($exist:path, "/coursepack/") or $exist:resource = 'coursepack') then 
(
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
            </forward>
        </dispatch>
    else 
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/coursepack.html"/>
        <view>
            <forward url="{$exist:controller}/modules/view.xq">
                <add-parameter name="id" value="{$id}"/>
                <set-header name="Cache-Control" value="no-cache"/>
            </forward>
        </view>
        <error-handler>
            <forward url="{$exist:controller}/error-page.html" method="get"/>
            <forward url="{$exist:controller}/modules/view.xq"/>
        </error-handler>
    </dispatch>
)

(: Set path for works, assumes '/work/' in the path. :)  
else if(contains($exist:path, "/work/")) then
(
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
                <forward url="{$exist:controller}/modules/view.xq">
                    <add-parameter name="doc" value="{$id}"/>
                </forward>
            </view>
            <error-handler>
                <forward url="{$exist:controller}/error-page.html" method="get"/>
                <forward url="{$exist:controller}/modules/view.xq"/>
            </error-handler>
        </dispatch>  
)
else if (ends-with($exist:resource, ".html")) then
    (: the html page is run through view.xql to expand templates :)
    (
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="{$exist:controller}/modules/view.xq">
            </forward>
        </view>
		<error-handler>
			<forward url="{$exist:controller}/error-page.html" method="get"/>
			<forward url="{$exist:controller}/modules/view.xq"/>
		</error-handler>
    </dispatch>
)
else
    (: everything else is passed through :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>
    