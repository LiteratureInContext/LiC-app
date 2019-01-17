xquery version "3.0";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

if ($exist:path eq '') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{request:get-uri()}/"/>
    </dispatch>
    
else if ($exist:path eq "/") then
    (: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>

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
    let $id := replace(xmldb:decode($exist:resource), "^(.*)\..*$", "$1")
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
