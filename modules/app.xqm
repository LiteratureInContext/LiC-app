xquery version "3.1";

(:~ This is the default application library module of the lic app.
 :
 : @author Winona Salesky
 : @version 1.0.0
 : @see wsalesky.com
 :)

(: Module for app-specific template functions :)
module namespace app="http://LiC.org/apps/templates";
(: Import eXist modules:)
import module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace lib="http://exist-db.org/xquery/html-templating/lib";
import module namespace config="http://LiC.org/apps/config" at "config.xqm";
import module namespace kwic="http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";
import module namespace functx="http://www.functx.com";
import module namespace http="http://expath.org/ns/http-client";

(: Import application modules. :)
import module namespace timeline="http://LiC.org/apps/timeline" at "lib/timeline.xqm";
import module namespace sf="http://srophe.org/srophe/facets" at "lib/facets.xql";
import module namespace facet="http://expath.org/ns/facet" at "lib/facet.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "content-negotiation/tei2html.xqm";
import module namespace data="http://LiC.org/apps/data" at "lib/data.xqm";
import module namespace maps="http://LiC.org/apps/maps" at "lib/maps.xqm";
import module namespace d3xquery="http://syriaca.org/d3xquery" at "../d3xquery/d3xquery.xqm";

(: Namespaces :)
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace mads = "http://www.loc.gov/mads/v2";

(: LiC application functions below :)

(: Global Variables :)
declare variable $app:start {request:get-parameter('start', 1) cast as xs:integer};
declare variable $app:perpage {request:get-parameter('perpage', 25) cast as xs:integer};

declare function app:if-attribute-set($node as node(), $model as map(*), $attribute as xs:string) {
    let $isSet :=
        (exists($attribute) and request:get-attribute($attribute))
    return
        if ($isSet) then
            templates:process($node/node(), $model)
        else
            ()
};

declare function app:if-attribute-unset($node as node(), $model as map(*), $attribute as xs:string) {
    let $isSet :=
        (exists($attribute) and request:get-attribute($attribute))
    return
        if (not($isSet)) then
            templates:process($node/node(), $model)
        else
            ()
};

(: Login functions :)
(: Activate login module use userManager.xql to login and create new users. :)
declare function app:username-login($node as node(), $model as map(*)) {
    let $user:= 
        if(request:get-attribute("org.exist.login.user")) then request:get-attribute("org.exist.login.user")
        else(: xmldb:get-current-user():) sm:id()/sm:id/sm:real/sm:username/string(.)    
    let $userName := 
            if(sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson'))) then 
                sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson')) 
            else $user
    return 
        if ($user and not(matches($user,'[gG]uest'))) then
            <ul class="nav navbar-nav">
                <li>
                    <p class="navbar-btn">
                       <div class="dropdown">
                        <button class="btn btn-light dropdown-toggle" type="button" data-bs-toggle="dropdown" aria-expanded="false">
                            <i class="bi bi-person"></i> {$userName} 
                        </button>
                        <ul class="dropdown-menu">
                          <li><a class="dropdown-item" href="{$config:nav-base}/user.html?user={$user}">Account</a></li>
                          <li><a class="dropdown-item" href="{$config:nav-base}/admin?logout=true" id="logout">Logout</a></li>
                        </ul>
                      </div>
                    </p>
                </li>
            </ul>
        else 
            <button type="button" class="btn btn-light" data-bs-toggle="modal" data-bs-target="#loginModal">
              <i class="bi bi-person"></i> Login
            </button>                
};

declare 
    %templates:wrap
function app:display-userinfo($node as node(), $model as map(*)) {
    let $user:= 
        if(request:get-attribute("org.exist.login.user")) then request:get-attribute("org.exist.login.user")
        else(: xmldb:get-current-user():) sm:id()/sm:id/sm:real/sm:username/string(.)    
    let $userName := 
            if(sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson'))) then 
                sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson')) 
            else $user
    let $coursepacks := if($user = 'admin') then
                            collection($config:app-root || '/coursepacks')/coursepack
                         else collection($config:app-root || '/coursepacks')/coursepack[@user = $user]            
    return
        <div>
            <h1>{$user} : {$userName}</h1>
            <h3>{if($user = 'admin') then 'All coursepacks:' else 'Your coursepacks:'}</h3>
            {for $coursepack in $coursepacks
             return 
                    <div class="indent">
                        <h4><a href="{$config:nav-base}/coursepack/{string($coursepack/@id)}">{string($coursepack/@title)}</a></h4>
                        <p class="desc">{$coursepack/desc/text()}</p>
                    </div> 
            }
        </div>
};

declare function app:username($node as node(), $model as map(*)) {
    let $user:= 
        if(request:get-attribute("org.exist.login.user")) then request:get-attribute("org.exist.login.user")
        else(: xmldb:get-current-user():) sm:id()/sm:id/sm:real/sm:username/string(.)    
    let $name := 
            if(sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson'))) then 
                sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson')) 
            else $user
    return if ($name) then $name else $user
};

declare
    %templates:wrap
function app:userinfo($node as node(), $model as map(*)) as map(*) {
    let $user:= 
        if(request:get-attribute("org.exist.login.user")) then request:get-attribute("org.exist.login.user")
        else(: xmldb:get-current-user():) sm:id()/sm:id/sm:real/sm:username/string(.)    
    let $name := 
            if(sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson'))) then 
                sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson')) 
            else $user
    let $group := if ($user) then sm:get-user-groups($user) else 'guest'
    return
        map { "user-id" : $user, "user-name" : $name, "user-groups" : $group}
};

(:~
 : Recurse through menu output absolute urls based on repo-config.xml values.
 : Addapted from https://github.com/eXistSolutions/hsg-shell 
 : @param $nodes html elements containing links with '$app-root'
:)
declare
    %templates:wrap
function app:fix-links($node as node(), $model as map(*)) {
    app:fix-links(templates:process($node/node(), $model))
};

declare function app:fix-links($nodes as node()*) {
    for $node in $nodes
    return
        typeswitch($node)
            case element(html:a) return
                let $href := replace($node/@href, "\$nav-base", $config:nav-base)
                return
                    <a href="{$href}">
                        {$node/@* except $node/@href, $node/node()}
                    </a>
            case element(html:form) return
                let $action := replace($node/@action, "\$nav-base", $config:nav-base)
                return
                    <form action="{$action}">
                        {$node/@* except $node/@action, app:fix-links($node/node())}
                    </form>      
            case element() return
                element { node-name($node) } {
                    $node/@*, app:fix-links($node/node())
                }
            default return
                $node
};

declare %private function app:parse-href($href as xs:string) {
    if (matches($href, "\$\{[^\}]+\}")) then
        string-join(
            let $parsed := analyze-string($href, "\$\{([^\}]+?)(?::([^\}]+))?\}")
            for $token in $parsed/node()
            return
                typeswitch($token)
                    case element(fn:non-match) return $token/string()
                    case element(fn:match) return
                        let $paramName := $token/fn:group[1]
                        let $default := $token/fn:group[2]
                        return
                            request:get-parameter($paramName, $default)
                    default return $token
        )
    else
        $href
};

(:~
 : Dynamically build featured items on homepage carousel
 : Takes options specified in repo-config and fetches appropriate content, or prints out HTML
:)
declare function app:create-featured-slides($node as node(), $model as map(*)) {
    let $featured := $config:get-config//repo:featured
    for $slide in $featured/repo:slide
    let $order := if($slide/@order != '') then xs:integer($slide/@order) else 100
    let $imageURL := 
        if(starts-with($slide/@imageURL,'http')) then string($slide/@imageURL) 
        else if(starts-with($slide/@imageURL,'resources/')) then concat($config:nav-base,'/',string($slide/@imageURL))
        else if(starts-with($slide/@imageURL,'/resources/')) then concat($config:nav-base,string($slide/@imageURL))
        else string($slide/@imageURL)
    let $image := if($imageURL != '') then 
                    <img src="{$imageURL}" alt="{if($slide/@imageDesc != '') then string($slide/@imageDesc) else 'Featured image'}" width="{if($slide/@width != '') then string($slide/@width) else '80%'}"/>
                  else ()
    order by $order
    return 
        <li class="slide overlay">
            <div class="slide-content">{
                if($slide/@type = 'text') then
                    $slide/child::*
                else if($slide/@type = 'coursepack') then
                    let $coursepackId := string($slide/@id)
                    let $coursepack := doc($config:app-root || '/coursepacks/' || $coursepackId || '.xml' )
                    return 
                        <div class="row">
                            <div class="coursepack {if($imageURL != '') then 'col-md-8' else 'col-md-12'}">
                            <div class="featuredImage">{$image}</div>
                            <h3>Featured Coursepack</h3>
                            <h4>{string($coursepack/coursepack/@title)} ({count($coursepack//work)} works)</h4>
                            <p>{$coursepack/coursepack/desc/text()}</p>
                            <ol>{(
                                for $w in subsequence($coursepack//work,1,5)
                                return 
                                <li>{$w/text()}</li>,
                                if(count($coursepack//work) gt 5) then
                                 <li> <a href="coursepack?id={$coursepackId}" data-toggle="tooltip" title="See all works">...</a>  </li>   
                                else ()                                
                            )}</ol>
                            <div class="get-more"><br/><a href="coursepack?id={$coursepackId}">Go to coursepack <i class="bi bi-arrow-right-circle"></i></a></div>
                           </div>
                        </div>
                else if($slide/@type = 'work') then
                    let $workID := string($slide/@id)
                    let $workPath := concat($config:data-root,'/', replace($workID,'/work/',''), '.xml')
                    let $work := doc(xmldb:encode-uri($workPath))
                    return 
                        <div>
                            <div class="work {if($imageURL != '') then 'col-md-8' else 'col-md-12'}">
                            <div class="featuredImage">{$image}</div>
                            <h3>Featured Work</h3>
                            {tei2html:summary-view($work, (), $workPath)}
                            </div>
                        </div>
                 else if($slide/@type = 'recentWork') then  
                    let $works := 
                        for $r in collection($config:data-root) 
                        order by $r/descendant::tei:revisionDesc/tei:change[1]/@when
                        return $r
                    return    
                    <div>
                        <h3>Recently Published Works</h3>
                        {
                        for $w in subsequence($works,1,3)
                        let $workPath := document-uri($w)
                        return
                            <div class="result">{tei2html:summary-view($w, (), $workPath)}</div>
                        }  
                   </div>
                else $slide/child::*
            }</div>
        </li>
};

(:~
 : Select page view, record or html content
 : If no record is found redirect to 404
 : @param $node the HTML node with the attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)
declare %templates:wrap function app:get-work($node as node(), $model as map(*)) {
     if(request:get-parameter('id', '') != '' or request:get-parameter('doc', '') != '') then
        let $rec := data:get-document()
        return 
            if(empty($rec)) then 
                if(not(empty(data:get-coursepacks()))) then <blockquote>No record found</blockquote>
                else response:redirect-to(xs:anyURI(concat($config:nav-base, '/404.html')))
            else map {"data" : $rec }
    else <blockquote>No record found</blockquote>
};

(:~
 : Output TEI as HTML
 : @param $node the HTML node with the attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)
(: Cludge for TEI stylesheets to only return child of html body, better handling will need to be developed.:)
(:
possible chunking options: 
<pb n="142" facs="pageImages/Speckled-Band_0142.jpg"/>

:)
declare function app:display-work($node as node(), $model as map(*)) {
     (: to 'chunk' content section:)
    let $work := $model("data")/tei:TEI/descendant::tei:text
    return 
        if($work) then tei2html:tei2html($work) 
        else <blockquote>No record found</blockquote>
};

(:~  
 : Display any TEI nodes passed to the function via the paths parameter
 : Used by templating module, defaults to tei:body if no nodes are passed. 
 : @param $paths comma separated list of xpaths for display. Passed from html page  
:)
declare function app:display-nodes($node as node(), $model as map(*), $paths as xs:string*){
    let $data := $model("data")
    return 
        if($paths != '') then 
             tei2html:tei2html(
                    for $p in tokenize($paths,',')
                    return util:eval(concat('$data',$p)))
        else tei2html:tei2html($data/descendant::tei:text)
}; 

(:~  
 : Add HTML divs for lazyLoad feature to fill in
 : Uses tei:pb for creating anchor divs.
 : example: <pb n="ii" facs="pageImages/ii.jpg"></pb> 
 : Use with data.xql and lazyLoad.js  
 : NOTE: could make a milestone paramter to let users select which milestone to use.
:)
declare function app:lazy-load($node as node(), $model as map(*), $paths as xs:string*){
    let $data := $model("data")
    let $nodes := $data/descendant::tei:text
    let $pages := $nodes/descendant::tei:pb
    let $count := count($pages)
    let $firstPage := 
        for $page in $pages[1]
        let $ms1 := $page
        let $ms2 := if($page/following::tei:pb) then $page/following::tei:pb[1] else ()(:($nodes//element())[last()]:) 
        let $data := data:get-fragment-from-doc($nodes, $ms1, $ms2, true(), true(),'')
        return 
            let $root := root($nodes)/child::*[1]
            let $id := string($root/@xml:id)
            let $wrapped := 
                    element {node-name($root)}
                            {(
                                for $a in $root/@*
                                return attribute {node-name($a)} {string($a)},
                                $data
                            )}
            return 
                <div class="tei-page-chunk row" n="{string($page/@n)}" ms1="{string($ms1/@n)}" ms2="{string($ms2/@n)}">
                    <div class="col-md-8">{
                        if($data != '') then
                             if($data/self::tei:text) then
                                 tei2html:tei2html($wrapped/child::*/node())
                             else tei2html:tei2html($wrapped)
                         else ()
                     }</div>
                     <div class="col-md-4">{
                         if($data/descendant::tei:pb[@facs]) then 
                             for $image in $data/descendant::tei:pb[@facs]
                             let $src := 
                                         if(starts-with($image/@facs,'https://') or starts-with($image/@facs,'http://')) then 
                                             string($image/@facs) 
                                         else concat($config:image-root,$id,'/',string($image/@facs))   
                             return 
                                      <span xmlns="http://www.w3.org/1999/xhtml" class="pageImage" data-pageNum="{string($image/@n)}">
                                           <a href="{$src}"><img src="{$src}" width="100%"/></a>
                                           <span class="caption">Page {string($image/@n)}</span>
                                      </span>
                         else ()
                     }</div>
                 </div>             
    return 
    ($firstPage,
    for $pb in subsequence($pages, 2, $count)
    return
        <div class="lazyLoad" data-page="{string($pb/@n)}" data-page-fac="{string($pb/@fac)}" style="display:block; padding:1px; border:1px solid #eee;"> </div>)
        
}; 

(:~  
 : Display teiHeader  
:)
declare function app:teiHeader($node as node(), $model as map(*)){
    let $data := $model("data")/descendant::tei:teiHeader
    return 
        if(tei2html:tei2html($model("data")/tei:TEI)) then 
            (tei2html:header($data),tei2html:COinS($data)) 
        else ()
}; 

(:~  
 : Display teiHeader  
:)
declare function app:citation($node as node(), $model as map(*)){
    let $data := $model("data")/descendant::tei:sourceDesc
    return tei2html:citation($data)
}; 

(:~  
 : Display footnotes at the bottom of the page.  
:)
declare function app:footnotes($node as node(), $model as map(*)){
    let $data := $model("data")/descendant::tei:note[@target]
    return
        (
        <div class="footnote show-print">
            <h3>Footnotes</h3>
            {for $n in $data[@type!="authorial"]
             return <div class="tei-footnote"><span class="tei-footnote-id">{string($n/@target)}</span>{tei2html:tei2html($n/node())}</div>
             }
        </div>,
        if($data[@type="authorial"]) then 
            <div class="footnotes authorial">
                <h3>Footnotes</h3>
                {for $n in $data[@type="authorial"]
                 return <div class="tei-footnote"><span class="tei-footnote-id">{string($n/@target)}</span>{tei2html:tei2html($n/node())}</div>
                 }
            </div>
        else ())
}; 

(:~  
 : Display any page images
 : Expects page images to be in tei:pb@facs
:)
declare function app:page-images($node as node(), $model as map(*)){
    if($model("data")//tei:pb[@facs]) then
       <div class="pageImages lic-well">
       <h4>Page images</h4>
       {
            let $id := string($model("data")//tei:TEI/@xml:id)
            for $image in $model("data")//tei:pb[@facs]
            let $src := 
                if(starts-with($image/@facs,'https://') or starts-with($image/@facs,'http://')) then 
                    string($image/@facs) 
                else concat($config:image-root,$id,'/',string($image/@facs))   
            return 
             <span xmlns="http://www.w3.org/1999/xhtml" class="pageImage">
                  <a href="{$src}"><img src="{$src}" width="100%"/></a>
                  <span class="caption">Page {string($image/@n)}</span>
             </span>
       }</div>    
    else ()  
}; 

(: Page images  w-100:)
declare function app:pageImages($node as node(), $model as map(*)) {
if($model("data")/descendant::tei:pb[@facs]) then 
    let $pages :=  $model("data")/descendant::tei:pb[@facs]
    let $count := count($pages)
    return 
    <div id="carouselExampleIndicators" class="carousel slide carousel-dark" data-bs-interval="false">
        <div class="carousel-indicators">
            {
                for $img at $p in $pages
                return 
                    if($p = 1) then 
                        <button type="button" data-bs-target="#carouselExampleIndicators" data-bs-slide-to="0" class="active" aria-current="true" aria-label="Slide 1"></button>
                    else <button type="button" data-bs-target="#carouselExampleIndicators" data-bs-slide-to="{$p - 1}" aria-label="Slide {$p}"></button>
            }
        </div>
        <div class="carousel-inner">
            {
                let $id := string($model("data")//tei:TEI/@xml:id)
                for $img at $p in $pages
                let $src := 
                    if(starts-with($img/@facs,'https://') or starts-with($img/@facs,'http://')) then string($img/@facs) 
                    else concat($config:image-root,$id,'/',string($img/@facs))
                return 
                <div class="carousel-item {if($p = 1) then 'active' else ''} container">
                    <img class="d-block  img-fluid" src="{$src}" alt="Page {string($img/@n)}"/>
                    <div class="carousel-caption d-none d-md-block">
                  </div>
                </div>
            }
        </div>
        <a class="carousel-control-prev" href="#carouselExampleIndicators" role="button" data-bs-slide="prev">
                <span class="carousel-control-prev-icon" aria-hidden="true"></span>
                <span class="sr-only">Previous</span>
        </a>
        <a class="carousel-control-next" href="#carouselExampleIndicators" role="button" data-bs-slide="next">
                <span class="carousel-control-next-icon" aria-hidden="true"></span>
                <span class="sr-only">Next</span>
        </a>
    </div>
else <blockquote>No images</blockquote>
};

(:~ 
 : Menu for different Data formats and sharing options
 : Available options are: TEI/XML, PDF, EPUB, Text, Print. 
 :)
declare %templates:wrap function app:other-data-formats($node as node(), $model as map(*), $formats as xs:string?){
    if($formats) then
        <div class="dataFormats">
            {
                for $f in tokenize($formats,',')
                return 
                   if($f = 'print') then                        
                        (<a href="javascript:window.print();" type="button" class="btn btn-outline-secondary btn-xs" id="printBtn" data-bs-toggle="tooltip" title="Click to send this page to the printer." >
                             <i class="bi bi-printer"></i>
                        </a>, '&#160;')  
                  else if($f = 'notes') then
                        (<button class="btn btn-outline-secondary btn-xs showHide" id="notesBtn" data-bs-toggle="collapse" data-bs-target="#teiViewNotes">
                            <span data-bs-toggle="tooltip" title="View Notes">
                                <i class="bi bi-plus-circle"></i> Editorial Statements
                            </span></button>, '&#160;')   
                  else if($f = 'citation') then
                        (<button class="btn btn-outline-secondary btn-xs" id="citationBtn" data-bs-toggle="collapse" data-bs-target="#teiViewCitation">
                            <span data-bs-toggle="tooltip" title="View Citation">
                                <i class="bi bi-book"></i> Citation
                            </span></button>, '&#160;')
                  else if($f = 'sources') then 
                        (<button class="btn btn-outline-secondary btn-xs showHide" id="sourcesBtn" data-bs-toggle="collapse" data-bs-target="#teiViewSources">
                            <span data-bs-toggle="tooltip" title="View Source Description">
                                <i class="bi bi-plus-circle"></i> Source Texts
                            </span></button>, '&#160;') 
                else if($f = 'pageImages') then 
                    if($model("data")/descendant::tei:pb[@facs]) then 
                         ((:
                           <a href="{request:get-uri()}" class="btn btn-outline-secondary btn-xs" id="pageImagesBtn" data-bs-toggle="tooltip" title="Click to hide the page images.">
                                <i class="bi bi-dash-circle"></i> Page Images
                             </a>:)
                             <button type="button" class="btn btn-outline-secondary btn-xs showHide" data-bs-toggle="modal" data-bs-target="#teiPageImages">
                                <i class="bi bi-plus-circle"></i> Page Images
                            </button>, '&#160;') 
                    else()         
                else if($f = 'lod') then 
                    let $lodcount := count(distinct-values($model("data")//@key))
                    return 
                        if($lodcount gt 6) then 
                             (<button class="btn btn-outline-secondary btn-xs showHide" id="LODBtn" data-bs-toggle="collapse" data-bs-target="#teiViewLOD">
                                <span data-bs-toggle="tooltip" title="View Linked Data">
                                    <i class="bi bi-plus-circle"></i> Linked Data
                                </span></button>, '&#160;')
                        else ()        
                else () 
            }
            {
                if($model("data")//tei:graphic[ends-with(@url,'.mp3')]) then 
                    (<button class="btn btn-outline-secondary btn-xs showHide" id="LODBtn" data-bs-toggle="collapse" data-bs-target="#teiAudio">
                        <span data-bs-toggle="tooltip" title="View Linked Data">
                            <i class="bi bi-headphones"></i> Audio
                      </span></button>, '&#160;')     
                else ()
            }
            { 
                <div class="btn-group" data-bs-toggle="tooltip"  title="Download Work Options">
                          <button type="button" class="btn btn-outline-secondary dropdown-toggle btn-xs"
                          data-bs-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                           <i class="bi bi-download"></i> Download 
                          </button>
                          <ul class="dropdown-menu">{
                            for $f in tokenize($formats,',')
                            return 
                                 if($f = 'tei') then
                                     <li><a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.tei" id="teiBtn" data-bs-toggle="tooltip" title="Click to view the TEI XML data for this work.">TEI/XML</a></li>
                                 else if($f = 'pdf') then                        
                                     <li><a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.pdf" id="pdfBtn" data-bs-toggle="tooltip" title="Click to view the PDF for this work.">PDF</a></li>                         
                                 else if($f = 'epub') then                        
                                     <li><a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.epub" id="epubBtn" data-bs-toggle="tooltip" title="Click to view the EPUB for this work.">EPUB</a></li>  
                                else if($f = 'rdf') then
                                     <li><a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.rdf" id="teiBtn" data-bs-toggle="tooltip" title="Click to view the RDF-XML data for this record.">RDF/XML</a></li>
                                else if($f = 'ttl') then
                                     <li><a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.ttl" id="teiBtn" data-bs-toggle="tooltip" title="Click to view the RDF-Turtle data for this record." >RDF/TTL</a></li>
                                else()}     
                        </ul>
                </div>
            }
            {
            <button id="rangy" class="drawer-handle rangy rangy-select btn btn-light" data-url="{$config:nav-base}/modules/lib/coursepack.xql" 
                data-workid="{document-uri(root($model("data")))}"
                data-worktitle="{$model("data")//tei:TEI/descendant::tei:titleStmt/tei:title[1]}" 
                title="Save selection/text to coursepack"> 
                <span data-bs-toggle="tooltip" title="Coursepack tools">
                <i class="bi bi-plus-circle"></i> Custom Coursepack<br/>
                    
                    <!--<img src="{$config:nav-base}/resources/images/add2Coursepack.png" height="75px"/>-->
                </span>
            </button>
            }            
        </div>
    else ()
};
declare function app:audio($node as node(), $model as map(*)) {
<div class="audioFile" style="display:block; text-align: center; margin-top:12px; padding:12px;">
    <audio controls="controls" style="position:sticky; top:20px;" class="audioFile">
      <source src="{$model("data")//tei:graphic[ends-with(@url,'.mp3')]/@url}" type="audio/mpeg"/>
    </audio>
    <script type="text/javascript">
        <![CDATA[
        $(window).scroll(function(e){ 
            var $el = $('.audioFile'); 
            var isPositionFixed = ($el.css('position') == 'fixed');
            if ($(this).scrollTop() > 400 && !isPositionFixed){ 
              $el.css({'position': 'fixed', 'top': '10px', 'right': '10px'}); 
            }
            if ($(this).scrollTop() < 400 && isPositionFixed){
              $el.css({'position': 'static', 'top': '0px'}); 
            } 
          });
        ]]>
    </script>
</div>

};

(: Coursepack display functions :)
(:~
 : Get coursepack by id or list all available coursepacks
:)
declare function app:get-coursepacks($node as node(), $model as map(*)) {
    if(data:create-query() != '') then 
        map {"coursepack" : data:get-coursepacks(),
               "hits" : data:search-coursepacks()  
         }
    else 
        map {"coursepack" :  data:get-coursepacks()}  
};

(:~
 : List all coursepacks as select options.
 : Used in the 'Add to Coursepack' function
 : Coursepack select options for selecting which coursepack to add selected works to. 
 :)
declare function app:select-coursepack($node as node(), $model as map(*)){
   let $coursepacks := data:get-coursepacks()
   for $coursepack in $coursepacks/descendant-or-self::coursepack
   return <option value="{string($coursepack/@id)}" class="">{string($coursepack/@title)}</option>
};

(:~
 : HTML Coursepack title
 : @depreciated 
:)
declare function app:display-coursepack-title($node as node(), $model as map(*)){
   <h1>{string($model("coursepack")/@title)}</h1> 
};

(:~
 : Display Coursepack or a list of all available coursepacks
:)
declare function app:display-coursepacks($node as node(), $model as map(*)){
let $coursepacks := $model("coursepack")
let $title := $model("coursepack")/@title
let $desc := $coursepacks/*:desc
let $hits := $model("hits")
return 
    if(empty($coursepacks)) then
        <div>
            <h1>No matching Coursepack. </h1>
            <div class="lic-well coursepack">
                <p>To create a new coursepack browse or search the list of <a href="{$config:nav-base}/browse.html">works</a>.</p>
                <p><a href="{$config:nav-base}/coursepack.html">Browse list</a></p>
            </div>
        </div>
    else if(request:get-parameter('id', '') != '') then 
        (<form class="form-inline coursepack" method="get" action="{string($coursepacks/@id)}" id="search">
            <h1>{string($model("coursepack")/@title)}</h1>
            <p class="desc">{$desc}</p>
            <div class="row">
                <div class="col-md-12">
                    <div class="coursepackToolbar">
                    {
                        if($hits != '') then 
                            app:pageination-inline($node, $model, 'title,author,pubDate')
                        else
                            <div class="btn-group">
                                <div class="dropdown">
                                 <button class="toolbar btn btn-outline-secondary dropdown-toggle" type="button" id="sortMenu" data-bs-toggle="dropdown" aria-expanded="false">
                                   Sort
                                 </button>
                                 <ul class="dropdown-menu pull-right" aria-labelledby="sortMenu">
                                    {
                                           for $option in tokenize('title,author,pubDate',',')
                                           return 
                                           <li>
                                               <a role="dropdown-item" tabindex="-1" href="?sort-element={$option}" id="rel">
                                                   {
                                                       if($option = 'pubDate' or $option = 'persDate') then 'Date'
                                                       else if($option = 'pubPlace') then 'Place of publication'
                                                       else functx:capitalize-first($option)
                                                   }
                                               </a>
                                           </li>
                                       }
                                 </ul>
                               </div>
                           </div>
                        
                    }
                        {(: edit coursepack :)
                            if(sm:has-access(document-uri(root($title)),'rw')) then 
                               ( 
                               <button type="button" class="toolbar btn btn-outline-secondary" data-bs-toggle="modal" data-bs-target="#editCoursePack" title="Edit Coursepack"><i class="bi bi-pencil"></i> Edit</button>,
                               <button type="button" class="deleteCoursepack toolbar btn btn-outline-secondary" data-bs-toggle="tooltip" title="Delete Coursepack" data-url="{$config:nav-base}/modules/lib/coursepack.xql?action=delete&amp;coursepackid={string($coursepacks/@id)}"><i class="bi bi-trash"></i> Delete</button>
                               )
                            else ()
                        }
 
                            {
                                if(request:get-parameter('view', '') = 'expanded') then 
                                    <a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}?view=list" class="toolbar btn btn-outline-secondary" data-bs-toggle="tooltip" title="List Coursepack Works"><i class="bi bi-list-task"></i> List Works </a>
                                else 
                                    <a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}?view=expanded" class="toolbar btn btn-outline-secondary" data-bs-toggle="tooltip" title="Expand Coursepack Works to see text"><i class="bi bi-plus-circle"></i> Expand Works </a>
                            }
                            {if($model("hits")//@key or $model("coursepack")//@key) then 
                                 (<a class="toolbar btn btn-outline-secondary" id="LODBtn" data-bs-toggle="collapse" data-bs-target="#teiViewLOD">
                                     <span data-bs-toggle="tooltip" title="View Linked Data">
                                         <i class="bi bi-plus-circle"></i> Linked Data
                                     </span></a>, '&#160;')
                                 else () 
                             }
                            <a href="javascript:window.print();" type="button" id="printBtn"  class="toolbar btn btn-outline-secondary" data-bs-toggle="tooltip" title="Print Coursepack"><i class="bi bi-printer"></i> Print</a>
                            <div class="btn-group" data-bs-toggle="tooltip"  title="Download Coursepack Option">
                                <button class="toolbar btn btn-outline-secondary dropdown-toggle" type="button" id="downloadMenu" data-bs-toggle="dropdown" aria-expanded="false">
                                    <i class="bi bi-download"></i> Download 
                              </button>
                              <ul class="dropdown-menu pull-right" aria-labelledby="downloadMenu">
                                <li><a role="dropdown-item" href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}.pdf" id="pdfBtn" title="Download Coursepack as PDF">PDF</a></li>
                                <li><a role="dropdown-item" href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}.epub" id="epubBtn" title="Download Coursepack as EPUB">EPUB</a></li>
                                <li><a role="dropdown-item" href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}.tei"  id="teiBtn" title="Download Coursepack as TEI">TEI</a></li>
                                <li><a role="dropdown-item" href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}.txt"  id="textBtn" title="Download Coursepack as plain text">Text</a></li>
                              </ul>
                            </div> 
                    
                        <div class="input-group mb-3" style="padding-top:12px;">
                            <input name="query" type="text" class="form-control" placeholder="Search coursepack text"/>
                            <select name="field" class="form-select">
                                <option value="keyword" selected="">Keyword anywhere</option>
                                <option value="annotation">Keyword in annotations</option>
                                <option value="title">Title</option>
                                <option value="author">Author</option>
                            </select>
                            <button class="toolbar btn btn-secondary" type="submit">Search</button>
                            <button class="toolbar btn btn-outline-secondary" type="submit">Clear</button>
                        </div>
                    </div>               
                </div>
            </div>
            
            <!-- WS, not working, need to add the map.invalidateSize somehwere for hide/show sections -->
            <div class="collapse left-align" id="teiViewLOD">
                {app:subset-lod($node, $model)}
            </div>
            <div class="lic-well coursepack boxContainer">
                 {
                 if($hits != '') then
                     (<hr/>,
                      <span style="margin-left:3em;"><input type="checkbox" class="toggle-button" id="selectAll" /> Select All</span>,
                     <hr/>,
                     app:show-hits($node, $model, 1, 10))
                 else if(data:create-query() != '') then
                     <div>No results.</div>
                 else 
                    for $work in $coursepacks//tei:TEI[descendant::tei:title[1]!='']
                    let $title := $work/descendant::tei:title[1]/text()
                    let $author := if($work/descendant::tei:author/descendant-or-self::tei:surname) then 
                                        $work/descendant::tei:author/descendant-or-self::tei:surname
                                   else $work/descendant::tei:author
                    let $id := document-uri(root($work))
                    let $selection := if($coursepacks//work[@id = $id]/text) then
                                        for $text in $coursepacks//work[@id = $id]/text
                                        return 
                                            (<div><h4>Selected Text</h4>,
                                            {tei2html:tei2html($text/child::*)}</div>)
                                      else()
                    let $sort := 
                        if(request:get-parameter('sort-element', '') = 'title') then 
                            $title
                        else if(request:get-parameter('sort-element', '') = 'author') then
                           $author[1]
                        else if(request:get-parameter('sort-element', '') = 'pubDate') then
                            $work/descendant::tei:date[1]
                        else if(request:get-parameter('sort-element', '') = 'date') then
                            $work/descendant::tei:date[1]    
                        else $work/@num
                    order by $sort
                    return  
                        <div class="container result">
                            <div class="row">
                              <div class="col-1">
                                <button data-url="{$config:nav-base}/modules/lib/coursepack.xql?action=deleteWork&amp;coursepackid={string($coursepacks/@id)}&amp;workid={$id}" class="removeWork btn btn-outline-secondary btn-sm" data-bs-toggle="tooltip" title="Delete Work from Coursepack">
                                    <i class="bi bi-trash"></i> 
                                </button>
                                <button data-url="{$config:nav-base}/modules/data.xql?id={string($coursepacks/@id)}&amp;view=expand&amp;workid={$id}" class="expand btn btn-outline-secondary btn-sm" data-bs-toggle="tooltip" title="Expand Work to see text">
                                   <i class="bi bi-plus-circle"></i> 
                                </button>
                              </div>
                              <div class="col">
                                {(
                                if($selection != '') then
                                    (<h4 class="selections-from">Selections from: </h4>, 
                                    tei2html:summary-view($work, (), $id[1]),
                                    if(request:get-parameter('view', '') = 'expanded') then 
                                       <div class="selected-text">{$selection}</div> 
                                    else ())
                                else if(request:get-parameter('view', '') = 'expanded') then
                                    (tei2html:header($work/descendant::tei:teiHeader),
                                    tei2html:tei2html($work/descendant::tei:text),
                                    let $notes := $work/descendant::tei:note[@target]
                                    return
                                        if($notes != '') then 
                                            <div class="footnote show-print">
                                                <h3>Footnotes</h3>
                                                {for $n in $notes
                                                 return <div class="tei-footnote"><span class="tei-footnote-id">{string($n/@target)}</span>{tei2html:tei2html($n/node())}</div>
                                                 }
                                            </div>
                                        else ()
                                    )
                                else tei2html:summary-view($work, (), $id[1])
                                )}
                                <div class="expandedText"></div>
                              </div>
                            </div>
                          </div>
                 }      
        </div>
        </form>,
        <div class="modal fade" id="editCoursePack" tabindex="-1" role="dialog" aria-labelledby="modalLabel" aria-hidden="true">
                <form action="{$config:nav-base}/modules/lib/coursepack.xql" method="post" id="editCoursepackForm" role="form">
                <div class="modal-dialog" role="document">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h4 class="pull-left" id="modalLabel">Edit Coursepack</h4>
                        </div>
                        <div class="modal-body">
                           <div id="response">
                                {
                                        <div>
                                        <div class="row">
                                            <div class="col-12">
                                                <div class="form-group">
                                                    <label for="title">Title:</label><br/>
                                                    <input type="text" class="form-control" name="title" id="title" value="{$title}"></input>
                                                 </div>
                                            </div>
                                        </div>
                                        <div class="row">        
                                            <div class="col-12">
                                                <div class="form-group">
                                                    <label for="desc">Description:</label><br/>
                                                    <textarea class="form-control" rows="10" name="desc" id="desc">{$desc//text()}</textarea>
                                                </div>
                                            </div>
                                        </div>
                                        <input type="hidden" id="coursepackid" name="coursepackid" value="{request:get-parameter('id', '')}"/>
                                        <input type="hidden" name="action" value="edit"/>
                                    </div>
                                }
                           </div> 
                        </div>
                        <div class="modal-footer">
                            <button type="submit" class="btn btn-outline-secondary">Submit</button><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Close</button>
                        </div>
                    </div>
                </div>
                </form>
            </div>
        )
        
    else        
        <div>
            <h1>Available Coursepacks</h1>
            <div class="lic-well coursepack">
                {
                for $coursepack in $coursepacks
                return 
                    <div class="indent result">
                        <h4><a href="{$config:nav-base}/coursepack/{string($coursepack/child::*/@id)}">{string($coursepack/child::*/@title)}</a></h4>
                        <p class="desc">{$coursepack/child::*/desc/text()}</p>
                    </div>          
                }
            </div>
        </div>
};

(:~
 : Display paging functions in html templates
:)
(: WS:Note - why are there 2 of these (pagination, pageination-inline), also update to make sure you don't get errors, see srophe app :)
declare %templates:wrap function app:pageination($node as node()*, $model as map(*), $sort-options as xs:string*){
let $search-string := app:search-string()
let $sort-options := $sort-options
let $hits := $model("hits")
let $perpage := if($app:perpage) then xs:integer($app:perpage) else 20
let $start := if($app:start) then $app:start else 1
let $total-result-count := count($hits)
let $end := 
    if ($total-result-count lt $perpage) then 
        $total-result-count
    else 
        $start + $perpage
let $number-of-pages :=  xs:integer(ceiling($total-result-count div $perpage))
let $current-page := xs:integer(($start + $perpage) div $perpage)
(: get all parameters to pass to paging function, strip start parameter :)
let $url-params := replace(replace(request:get-query-string(), '&amp;start=\d+', ''),'start=\d+','')
let $param-string := if($url-params != '') then concat('?',$url-params,'&amp;start=') else '?start='        
let $pageType := tokenize(request:get-uri(),'/')[last()]
let $pagination-links := 
    (
    <div class="row alpha-pages" xmlns="http://www.w3.org/1999/xhtml">  
            <div class="col-sm-5 search-string">
                    {if($search-string != '' and request:get-parameter('view', '') != 'author' and request:get-parameter('view', '') != 'title') then        
                        (<h3 class="hit-count paging">Search results:</h3>,
                        <p class="col-md-offset-1 hit-count">{$total-result-count} matches for {$search-string}</p>)
                     else ()   
                    }
            </div>
            <div>
                <nav aria-label="Page navigation example">
                {
                    if($pageType = 'contributors.html') then
                        <ul class="pagination justify-content-end">
                            {((: Show 'Previous' for all but the 1st page of results :)
                                if ($current-page = 1) then ()
                                else <li class="page-item"><a class="page-link" href="{concat($param-string, $perpage * ($current-page - 2)) }">Prev</a></li>,
                                (: Show links to each page of results :)
                                let $max-pages-to-show := 8
                                let $padding := xs:integer(round($max-pages-to-show div 2))
                                let $start-page := 
                                              if ($current-page le ($padding + 1)) then
                                                  1
                                              else $current-page - $padding
                                let $end-page := 
                                              if ($number-of-pages le ($current-page + $padding)) then
                                                  $number-of-pages
                                              else $current-page + $padding - 1
                                for $page in ($start-page to $end-page)
                                let $newstart := 
                                              if($page = 1) then 1 
                                              else $perpage * ($page - 1)
                                return 
                                    if ($newstart eq $start) then <li class="active"><a href="#" >{$page}</a></li>
                                     else <li class="page-item"><a class="page-link" href="{concat($param-string, $newstart)}">{$page}</a></li>,
                                (: Shows 'Next' for all but the last page of results :)
                                if ($start + $perpage ge $total-result-count) then ()
                                else <li class="page-item"><a class="page-link" href="{concat($param-string, $start + $perpage)}">Next</a></li>
                                )}
                        </ul>
                    else 
                        <div class="col-md-12">
                            {
                            if($total-result-count gt $perpage) then 
                            <ul class="pagination justify-content-end">
                                {((: Show 'Previous' for all but the 1st page of results :)
                                    if ($current-page = 1) then ()
                                    else <li class="page-item"><a class="page-link" href="{concat($param-string, $perpage * ($current-page - 2)) }">Prev</a></li>,
                                    (: Show links to each page of results :)
                                    let $max-pages-to-show := 8
                                    let $padding := xs:integer(round($max-pages-to-show div 2))
                                    let $start-page := 
                                                  if ($current-page le ($padding + 1)) then
                                                      1
                                                  else $current-page - $padding
                                    let $end-page := 
                                                  if ($number-of-pages le ($current-page + $padding)) then
                                                      $number-of-pages
                                                  else $current-page + $padding - 1
                                    for $page in ($start-page to $end-page)
                                    let $newstart := 
                                                  if($page = 1) then 1 
                                                  else $perpage * ($page - 1)
                                    return 
                                        if ($newstart eq $start) then <li class="active"><a class="page-link" href="#" >{$page}</a></li>
                                         else <li class="page-item"><a class="page-link" href="{concat($param-string, $newstart)}">{$page}</a></li>,
                                    (: Shows 'Next' for all but the last page of results :)
                                    if ($start + $perpage ge $total-result-count) then ()
                                    else <li class="page-item"><a class="page-link" href="{concat($param-string, $start + $perpage)}">Next</a></li>,
                                    if($sort-options != '') then data:sort-options($param-string, $start, $sort-options)
                                    else(),
                                    (:<li class="page-item"><a class="page-link" href="{concat($param-string,'1&amp;perpage=',$total-result-count)}">All</a></li>,:)
                                    if($search-string != '') then
                                        <li class="page-item pull-right search-new"><a class="page-link" href="search.html"><i class="bi bi-search"></i> New</a></li>
                                    else ()
                                    (:, 
                                    if($model("hits")//@key) then 
                                         <li class="pull-right"><a href="#" id="LODBtn" data-toggle="collapse" data-target="#teiViewLOD">
                                            <span data-toggle="tooltip" title="View Linked Data">
                                                <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span> Linked Data
                                            </span></a></li>
                                    else():)
                                    )}
                            </ul>
                            else 
                            <ul class="pagination justify-content-end">
                            {(
                                if($sort-options != '') then data:sort-options($param-string, $start, $sort-options)
                                else(),
                                if($search-string != '') then   
                                    <li class="page-item pull-right"><a class="page-link" href="{request:get-url()}"><i class="bi bi-search"></i> New</a></li>
                                else(), 
                                if($model("hits")//@key) then 
                                     <li class="page-item pull-right"><a class="page-link" href="#" id="LODBtn" data-bs-toggle="collapse" data-target="#teiViewLOD">
                                        <span data-bs-toggle="tooltip" title="View Linked Data">
                                            <i class="bi bi-plus-circle"></i> Linked Data
                                        </span></a></li>
                                else())}
                            </ul>
                            }
                        </div>
                }
                </nav>
            </div>
    </div>,
    if($search-string != '' and $total-result-count = 0) then 'No results, please try refining your search or reading our search tips.' 
    else ()
    )    
    return $pagination-links 
};

(:~
 : Display paging functions in html templates
:)
declare %templates:wrap function app:pageination-inline($node as node()*, $model as map(*), $sort-options as xs:string*){
let $search-string := app:search-string()
let $sort-options := $sort-options
let $hits := $model("hits")
let $perpage := if($app:perpage) then xs:integer($app:perpage) else 20
let $start := if($app:start) then $app:start else 1
let $total-result-count := count($hits)
let $end := 
    if ($total-result-count lt $perpage) then 
        $total-result-count
    else 
        $start + $perpage
let $number-of-pages :=  xs:integer(ceiling($total-result-count div $perpage))
let $current-page := xs:integer(($start + $perpage) div $perpage)
(: get all parameters to pass to paging function, strip start parameter :)
let $url-params := replace(replace(request:get-query-string(), '&amp;start=\d+', ''),'start=\d+','')
let $param-string := if($url-params != '') then concat('?',$url-params,'&amp;start=') else '?start='        
let $pagination-links := 
        if($total-result-count gt $perpage) then 
            <ul class="pagination justify-content-end">
                {((: Show 'Previous' for all but the 1st page of results :)
                        if ($current-page = 1) then ()
                        else <li><a class="page-link" href="{concat($param-string, $perpage * ($current-page - 2)) }">Prev</a></li>,
                        (: Show links to each page of results :)
                        let $max-pages-to-show := 8
                        let $padding := xs:integer(round($max-pages-to-show div 2))
                        let $start-page := 
                                      if ($current-page le ($padding + 1)) then
                                          1
                                      else $current-page - $padding
                        let $end-page := 
                                      if ($number-of-pages le ($current-page + $padding)) then
                                          $number-of-pages
                                      else $current-page + $padding - 1
                        for $page in ($start-page to $end-page)
                        let $newstart := 
                                      if($page = 1) then 1 
                                      else $perpage * ($page - 1)
                        return 
                            if ($newstart eq $start) then <li class="active"><a class="page-link" href="#" >{$page}</a></li>
                             else <li class="page-item"><a class="page-link" href="{concat($param-string, $newstart)}">{$page}</a></li>,
                        (: Shows 'Next' for all but the last page of results :)
                        if ($start + $perpage ge $total-result-count) then ()
                        else <li class="page-item"><a class="page-link" href="{concat($param-string, $start + $perpage)}">Next</a></li>,
                        if($sort-options != '') then data:sort-options($param-string, $start, $sort-options)
                        else(),
                        <li class="page-item"><a href="{concat($param-string,'1&amp;perpage=',$total-result-count)}">All</a></li>,
                        if($search-string != '') then
                            <li class="page-item pull-right search-new"><a class="page-link" href="search.html"><i class="bi bi-search"></i> New</a></li>
                        else () 
                        )}
            </ul>
        else 
            <ul class="pagination justify-content-end">
                {(
                    if($sort-options != '') then data:sort-options($param-string, $start, $sort-options)
                    else(),
                    if($search-string != '') then   
                        <li class="page-item pull-right"><a class="page-link" href="{request:get-url()}"><i class="bi bi-search"></i> Reset</a></li>
                    else() 
                    )}
            </ul>    
    return $pagination-links 
};

(:~
 : Create a span with the number of items in the current search result.
:)
declare function app:hit-count($node as node()*, $model as map(*)) {
    <span xmlns="http://www.w3.org/1999/xhtml" id="hit-count">{ count($model("hits")) }</span>
};

(:~
 : Simple browse works with sort options
 :)
declare %templates:wrap function app:browse-works($node as node(), $model as map(*)) {
     map { "hits" : data:search() }           
};

(:~
 : Simple browse works with sort options
 if(request:get-parameter('contributorID', '') != '') then 
                        for $n in $contributors[@xml:id = request:get-parameter('contributorID', '')]
                        order by $n/descendant::tei:surname[1]
                        return <browse xmlns="http://www.w3.org/1999/xhtml" id="{$n/@xml:id}">{$n}</browse>
                    else 
                        for $n in $contributors
                        order by $n/descendant::tei:surname[1]
                        return <browse xmlns="http://www.w3.org/1999/xhtml" id="{$n/@xml:id}">{$n}</browse>
 :)
declare %templates:wrap function app:list-contributors($node as node(), $model as map(*)) {
    let $contributors := 
        if(doc-available(replace($config:data-root,'/data','/contributors') || '/editors.xml')) then 
            doc(replace($config:data-root,'/data','/contributors') || '/editors.xml')//tei:person
        else ()
    (:
    let $contributors := 
            for $n in $contributors
            order by $n/descendant::tei:surname[1]
            return $n
        :)
    let $contributors := 
         if(request:get-parameter('contributorID', '') != '') then 
             for $n in $contributors[@xml:id = request:get-parameter('contributorID', '')]
             order by $n/descendant::tei:surname[1]
             return $n
         else 
             for $n in $contributors
             order by $n/descendant::tei:surname[1]
             return $n   
    return          
        map { "hits" : $contributors}  
};

(:~
 : Output the contributors list            
:)
declare 
    %templates:wrap
    %templates:default("start", 1)
    %templates:default("per-page", 10)
function app:contributors($node as node()*, $model as map(*), $start as xs:integer, $per-page as xs:integer) {
    let $per-page := if(not(empty($app:perpage))) then $app:perpage else $per-page
    return 
    <div>{
        for $h at $p in subsequence($model("hits"), $start, $per-page)
        let $id := string($h/@xml:id) 
        let $annotations := collection($config:data-root)//tei:text/descendant::tei:note[@resp= 'editors.xml#' || $id]
        let $texts := collection($config:data-root)//tei:titleStmt/descendant::tei:name[@ref= 'editors.xml#' || $id] | collection($config:data-root)//tei:teiHeader/descendant::tei:note[@resp= 'editors.xml#' || $id]
        let $count-annotations := count($annotations)
        let $count-texts := count($texts)
        return 
            <div class="result row" xmlns="http://www.w3.org/1999/xhtml">
                <button class="getContributorAnnotations btn btn-link" 
                    data-bs-toggle="collapse" title="View annotations" data-bs-target="#collapseContributor{$id}" data-contributor-id="{$id}" 
                    data-original-title="View annotations">
                        <i class="bi bi-plus-circle"></i></button>
                <span class="browse-author-name">{concat(string-join($h/descendant-or-self::tei:surname,' '),', ',string-join($h/descendant-or-self::tei:forename,' '))}</span>
                {if($count-annotations gt 0 or $count-texts gt 0) then
                            concat(' (',
                                if($count-annotations gt 0) then 
                                    concat($count-annotations,
                                    if($count-annotations gt 1) then ' annotations' else ' annotation',
                                    if($count-texts gt 0) then ', ' else ())
                                else (),
                                if($count-texts gt 0) then 
                                    concat($count-texts, if($count-texts gt 1) then ' texts' else ' text')
                                else (),
                            ')')
                        else ()}
                <div class="contributor-desc">{(
                            if($h/tei:occupation) then 
                                (for $r at $p in $h/tei:occupation
                                 return (tei2html:tei2html($r), if($p lt count($h/tei:occupation)) then ', ' else ()),
                                 if($h/tei:affiliation[. != '']) then ', ' else ())
                            else (),
                            if($h/tei:affiliation) then 
                                tei2html:tei2html($h/tei:affiliation)
                            else (),
                           if($h/tei:note) then 
                               <p>{ tei2html:tei2html($h/tei:note)}</p>
                            else ()
                )}</div>
                <div class="collapse" id="collapseContributor{$id}">
                <div class="indent">
                         <h3>Annotations</h3>
                         {
                             for $annotation at $p in $annotations
                             group by $work-id := document-uri(root($annotation))
                             let $work := $annotation/ancestor-or-self::tei:TEI
                             let $title := $work/descendant::tei:titleStmt/tei:title
                             let $url := concat($config:nav-base,'/work',substring-before(replace($work-id,$config:data-root,''),'.xml'))
                             order by normalize-space($title[1]) ascending
                             return 
                                <div class="annotations">
                                    <span class="title">
                                    <button class="getAnnotated btn btn-link" data-bs-toggle="tooltip" title="View annotations" data-work-id="{$work-id}" data-contributor-id="{$id}">
                                        <i class="bi bi-plus-circle"></i>
                                    </button> 
                                    <a href="{$url}" class="link-to-work" data-bs-toggle="tooltip" title="Go to work"><i class="bi bi-book"></i></a>&#160;
                                    {tei2html:tei2html($title)} ({count($annotation)} annotations) 
                                    </span>
                                    <div class="annotationsResults"></div>
                               </div>
                         }
                        </div>
                        <div class="indent">
                         <h3>Texts</h3>
                         {
                             for $text in $texts
                             group by $work-id := document-uri(root($text))
                             let $work := $text/ancestor-or-self::tei:TEI
                             let $title := $work/descendant::tei:titleStmt/tei:title
                             let $url := concat($config:nav-base,'/work',substring-before(replace($work-id,$config:data-root,''),'.xml'))
                             order by normalize-space($title[1]) ascending
                             return 
                             <div class="annotations">
                                    <span class="title">
                                    <button class="getTextAnnotated btn btn-link" data-bs-toggle="tooltip" title="View editorial statements" data-work-id="{$work-id}" data-contributor-id="{$id}">
                                        <i class="bi bi-plus-circle"></i>
                                    </button> 
                                    <a href="{$url}" class="link-to-work" data-bs-toggle="tooltip" title="Go to work"><i class="bi bi-book"></i></a>&#160;
                                    {tei2html:tei2html($title)} ({count($text)} texts)
                                    </span>
                                    <div class="textAnnotationsResults"></div>
                               </div>
                         }
                        </div>
                </div>
            </div>
    }</div>    
};

(:~
 : Output the search result as a div, using the kwic module to summarize full text matches.            
:)
declare 
    %templates:wrap
    %templates:default("start", 1)
    %templates:default("per-page", 10)
function app:show-hits($node as node()*, $model as map(*), $start as xs:integer, $per-page as xs:integer) {
    let $hits := $model("hits")
    let $per-page := if(not(empty($app:perpage))) then $app:perpage else $per-page
    return 
        if(request:get-parameter('view', '') = 'author') then
            let $authors := ft:facets($hits, "author", ())
            return 
                sort(map:for-each($authors, function($label, $count) {
                    let $facetID := replace($label,'[^a-zA-Z0-9]','')
                    return 
                        <div class="result row">
                            <div class="col-md-11">
                                <a class="btn btn-link togglelink dynamicContent" data-bs-toggle="collapse" data-bs-target="#collapse{$facetID}" data-url="{$config:nav-base}/modules/data.xql?facet-author={$label}">
                                    <i class="bi bi-plus-circle" data-bs-toggle="tooltip" title="View Works"  aria-hidden="true"></i>
                                </a>
                                <span>{$label} ({$count})</span>
                                <div class="collapse" id="collapse{$facetID[1]}">
                                    <div class="nestedResults"></div>
                                </div>
                            </div>
                        </div>
                    }))           
        else 
            for $hit at $p in subsequence($hits, $start, $per-page)
            let $id := document-uri(root($hit))
            let $score := ft:score($hit)
            let $title := $hit/descendant::tei:title[1]/text()
            let $expanded := if(request:get-parameter('query', '') != '') then kwic:expand($hit) else () 
            let $xmlId := $hit/@xml:id
            let $headnotes := if($xmlId != '') then
                                    collection($config:data-root || '/headnotes')//tei:relation[@active[matches(.,concat('#',$xmlId,"(\W.*)?$"))]]
                                    (:collection($config:data-root || '/headnotes')//tei:relation[@active[. = concat('#',$xmlId)]]:) 
                               else ()
            where $title != ''                                    
            return
                    <div class="result row">
                        <span class="checkbox col-md-1"><input type="checkbox" name="target-texts" class="coursepack" value="{$id}" data-title="{$title}"/></span>
                        <span class="col-md-11">
                        {(tei2html:summary-view($hit, (), $id[1])) }
                        {if($expanded//exist:match) then  
                            <span class="result-kwic">{tei2html:output-kwic($expanded, $id)}</span>
                         else ()}
                         {if(count($headnotes) gt 0) then
                            for $h in $headnotes
                            let $root := root($h)
                            let $hID := document-uri($root)
                            let $title := $root/descendant::tei:title[1]/text()
                            return 
                            <div class="headnoteInline">
                              <input type="checkbox" name="target-texts" class="coursepack headnoteCheckbox" value="{$hID}" data-title="{$title}"/>
                              <span class="HeadnoteLabel">{(tei2html:summary-view($root, (), $hID[1])) }</span>
                            </div>
                          else ()}
                         </span>
                    </div>        

};

(:~ 
 : Helper function to debug search queries
:)
declare %templates:wrap function app:debug-search($node as node(), $model as map(*)){
    <div class="bg-alert">Debugging search: {data:create-query()}</div>
};

(:~
 : Search results stored in map for use by other functions
:)
declare %templates:wrap function app:search-works($node as node(), $model as map(*)){
    let $queryExpr := data:create-query()
    let $docs := 
                if(request:get-parameter('narrow', '') = 'true' and request:get-parameter('target-texts', '') != '') then
                        for $doc in request:get-parameter('target-texts', '')
                        return doc($doc)
                else ()                        
    let $eval-string := 
                if(request:get-parameter('narrow', '') = 'true' and request:get-parameter('target-texts', '') != '') then
                    concat("$docs/tei:TEI",$queryExpr)                       
                else concat("collection('",$config:data-root,"')/tei:TEI",$queryExpr)
    return 
            let $hits := data:search()
            let $store := (
                session:set-attribute("search.LiC", $hits),
                session:set-attribute("search.LiC.query", $queryExpr)
            )
            return
                map {
                    "hits" : $hits,
                    "query" : $queryExpr
                }
};

(:~
 : Create a user friendly search string for output on search results page. 
:)
declare function app:search-string(){
    <span xmlns="http://www.w3.org/1999/xhtml">
    {(
        let $parameters :=  request:get-parameter-names()
        for  $parameter in $parameters
        return 
            if(request:get-parameter($parameter, '') != '') then
                if($parameter = ('start','sort-element','field','target-texts','narrow','fq')) then ()
                else if($parameter = 'query') then 
                        (<span class="query-value">{request:get-parameter($parameter, '')}&#160;</span>, ' in ', <span class="param">{request:get-parameter('field', '')}</span>,'&#160;')
                else (<span class="param">{replace(concat(upper-case(substring($parameter,1,1)),substring($parameter,2)),'-',' ')}: </span>,<span class="match">{request:get-parameter($parameter, '')}&#160; </span>)    
            else ())
            }
    </span>
};

(:
 : Display facets from HTML page 
 : @param $collection passed from html 
 : @param $facets relative (from collection root) path to facet-config file if different from facet-config.xml
:)
declare function app:display-facets($node as node(), $model as map(*), $facet-def-file as xs:string?){
    let $hits := $model("hits")
    let $facet-config := 
        if(doc-available(xs:anyURI($config:app-root || '/facet-def.xml'))) then
            doc(xs:anyURI($config:app-root || '/facet-def.xml'))
        else ()
    return 
        if(not(empty($facet-config))) then 
           sf:display($model("hits"),$facet-config)
        else ()
};

(: LOD functions :)
(:~ 
 : Display LOD data across collection 
 :)
declare 
    %templates:wrap
function app:lod($node as node(), $model as map(*)) { 
    <div>
        {
            if(request:get-parameter('view', '') = 'map') then
                app:map()
            else if(request:get-parameter('view', '') = 'persName') then
                app:persons()
            else if(request:get-parameter('view', '') = 'timeline') then
                app:timeline()                 
            else if(request:get-parameter('view', '') = ('network','graph')) then
                app:network() 
            else app:map()
        }
    </div>
};

(:~ 
 : Display a subset of LOD data based on current data, either work record or search/browse results 
 :)
declare 
    %templates:wrap
function app:subset-lod($node as node(), $model as map(*)) { 
let $map := app:map($node, $model)
let $graph := app:network($node, $model)
return 
    <div class="container">
        <div class="page-header">
          <h1>Linked Data</h1>
          <p>Explore the collection using linked open data.</p>
        </div>
        <div class="accordion" id="accordionExample">
        <div class="accordion-item">
          <h2 class="accordion-header" id="headingOne">
            <button class="accordion-button" type="button" data-bs-toggle="collapse" data-bs-target="#collapseOne" aria-expanded="true" aria-controls="collapseOne">
              Map
            </button>
          </h2>
          <div id="collapseOne" class="accordion-collapse collapse show" aria-labelledby="headingOne" data-bs-parent="#accordionExample">
            <div class="accordion-body">
              {$map}
            </div>
          </div>
        </div>
        <div class="accordion-item">
          <h2 class="accordion-header" id="headingTwo">
            <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapseTwo" aria-expanded="false" aria-controls="collapseTwo">
              Relationships
            </button>
          </h2>
          <div id="collapseTwo" class="accordion-collapse collapse" aria-labelledby="headingTwo" data-bs-parent="#accordionExample">
            <div class="accordion-body">
              {$graph}
            </div>
          </div>
        </div>
      </div>
        <!--
        <div class="panel panel-default">
          <div class="panel-heading panel-heading-nav">
            <ul class="nav nav-tabs">
              <li role="presentation" class="active nav-item">
                <a class="nav-link" href="#one" aria-controls="one" role="tab" data-bs-toggle="tab">Places</a>
              </li>
              <li class="nav-item" role="presentation">
                <a class="nav-link" href="#two" aria-controls="two" role="tab" data-bs-toggle="tab">Relationships</a>
              </li>
            </ul>
          </div>
          <div class="panel-body">
            <div class="tab-content">
              <div role="tabpanel" class="tab-pane fade show" id="one">
               {$map}
              </div>
              <div role="tabpanel" class="tab-pane fade" id="two">
                {$graph} 
              </div>
            </div>
          </div>
        </div>
        -->
    </div>
};

(:~
 : Create map of places mentioned in collection.
 : Used by app:lod()
:)
declare function app:map() {
    let $geojson := if(request:get-parameter('id', '') != '') then
                        doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))//tei:place[tei:idno = request:get-parameter('id', '')]
                    else doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))
    return 
        (
        <h2>Places</h2>,
        <p>Places referenced in the collection. </p>,
        <div>{maps:build-map($geojson)}</div>,
        if(request:get-parameter('id', '') != '' and count($geojson) = 1) then 
            let $related := $geojson/descendant::tei:relation
            for $r in $related
            group by $type := $r/@type
            return 
                <div style="margin-left:2em;">
                    <h3>{$geojson/tei:placeName}</h3>
                    <p style="font-weight:strong;">{functx:capitalize-first($type)} 
                        {if($type = 'mention') then concat(' (',string($r[1]/@count),')') else () }</p>
                        <ul>{
                            for $work in $r
                            let $id := $work/@active
                            return <li><a href="{$config:nav-base}/work{substring-before(replace($id,$config:data-root,''),'.xml')}">{tei2html:tei2html($work//tei:title)}</a></li>
                        }</ul>
                </div>
        else () )
};

(:~
 : Create map of subset of places mentioned in collection.
:)
declare function app:map($node as node(), $model as map(*)) {
    let $reference-data := if(not(empty($model("data")))) then $model("data") else if(not(empty($model("hits")))) then $model("hits") else if(not(empty($model("coursepack")))) then $model("coursepack") else () 
    let $geojson := if(contains(request:get-uri(),'/coursepack/')) then 
                        doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))
                    else if(request:get-parameter('id', '') != '') then
                        doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))//tei:place[tei:idno = request:get-parameter('id', '')]
                    else doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))
    let $subset := for $key in distinct-values($reference-data//@key)
                   return $geojson//tei:place[tei:idno = concat('http://vocab.getty.edu/tgn/', $key)]
    let $id := if(count($reference-data) = 1) then document-uri(root($reference-data)) else ()
    return 
        if(not(empty($subset))) then
            <div>{
                if(not(empty($id))) then maps:build-map-work($subset, $id)
                else maps:build-map-subset($subset)
                }</div>
        else <div>ID: {request:get-parameter('id', '')}</div>
};

(:~
 : List all the persNames mentioned
 :)
declare function app:persons() {
let $persNames := if(request:get-parameter('id', '') != '') then 
                                doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person[tei:idno = request:get-parameter('id', '')]
                              else doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person
let $active := if(request:get-parameter('alpha', '') != '') then request:get-parameter('alpha', '') else ()
return 
    <div>
        <h2>Persons</h2>
        <p>Persons referenced in the collection. </p>
        <div class="browse-alpha tabbable" xmlns="http://www.w3.org/1999/xhtml">
            <ul class="list-inline pagination justify-content-end">
            { 
                for $letter in tokenize('A B C D E F G H I J K L M N O P Q R S T U V W X Y Z', ' ')
                let $disabled := if(starts-with($persNames/descendant::tei:persName/descendant::tei:surname,$letter)) then 'false' else 'true'
                return
                    <li>{if($disabled = 'true') then attribute class {"disabled"} else if($active = $letter) then attribute class {"active"} else ()}<a href="?view=persName&amp;alpha={$letter}">{$letter}</a></li>
            }
            </ul>
        </div>
        <div>
            {
            (: Get results :)
            for $person at $i in $persNames
            let $name :=  if($person/descendant::mads:name) then 
                                string-join($person/descendant::mads:name/mads:namePart,', ')
                              else if($person/descendant::tei:persName/descendant::tei:surname) then 
                                  concat(normalize-space($person/descendant::tei:persName/descendant::tei:surname),', ', normalize-space($person/descendant::tei:persName/descendant::tei:forename))
                              else string-join($person/descendant::tei:persName//text(),' ')
            let $name-string := normalize-space($name)
            let $sort-name := replace($name-string,"^\s+|^[mM]rs.\s|^[mM]r.\s|^\(|(['][s]+)|\)",'')
            let $idno := replace($person/tei:idno,'\s|.|,|;', ' ')
            let $related := $person/descendant::tei:relation
            order by $sort-name
            where starts-with($sort-name,$active)
            return 
                <div style="border-bottom:1px solid #eee;">
                    <button class="btn btn-link" data-bs-toggle="collapse" data-bs-target="{concat('#name',$i,'Show')}"><i class="bi bi-plus-circle"></i></button> 
                    {normalize-space($name)} ({count($person/descendant::tei:relation)} associated work{if(count($related) gt 1) then 's' else()})
                    {
                    if($person/tei:persName/@type = ('lcnaf','lccn')) then 
                        <a href="http://id.loc.gov/authorities/names/{$person/tei:idno}" alt="Go to Library of Congress authority record"><i class="bi bi-window-plus" aria-hidden="true" data-bs-toggle="tooltip" title="Go to Library of Congress authority record"></i></a>
                    else if($person/tei:persName/@type = 'orcid') then 
                        <a href="https://orcid.org/{$person/tei:idno}" alt="Go to authority record"><i class="bi bi-window-plus"></i></a>
                    else ()
                    }
                    <div class="panel-collapse collapse {if(count($persNames) = 1) then 'in' else()} left-align" id="{concat('name',$i,'Show')}">{
                        for $r in $related
                        group by $type := $r/@type
                        return 
                            <div style="margin-left:2em;">
                                <p style="font-weight:strong;">{functx:capitalize-first($type)} 
                                {if($type = 'mention') then concat(' (',string($r[1]/@count),')') else () }</p>
                                <ul>{
                                for $work in $r
                                let $id := $work/@active
                                return <li><a href="{$config:nav-base}/work{substring-before(replace($id,$config:data-root,''),'.xml')}">{tei2html:tei2html($work//tei:title)}</a></li>
                                }</ul>
                            </div>
                    }</div>
                </div>
            }
        </div>
    </div>
};

(:~
 : List a subset of the persNames mentioned 
 :)
declare function app:persons($node as node(), $model as map(*)) {
    let $persNames := if(request:get-parameter('id', '') != '') then 
                                doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person[tei:idno = request:get-parameter('id', '')]
                              else doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person
    let $reference-data := if(not(empty($model("data")))) then $model("data") else if(not(empty($model("hits")))) then $model("hits") else () 
    let $subset := for $key in $reference-data//@key
                   return $persNames//tei:person[tei:idno = $key]
    return   
        if(not(empty($subset))) then
            for $person at $i in $persNames
            let $name :=  if($person/descendant::mads:name) then 
                                string-join($person/descendant::mads:name/mads:namePart,', ')
                              else if($person/descendant::tei:persName/descendant::tei:surname) then 
                                  concat(normalize-space($person/descendant::tei:persName/descendant::tei:surname),', ', normalize-space($person/descendant::tei:persName/descendant::tei:forename))
                              else string-join($person/descendant::tei:persName//text(),' ')
            let $name-string := normalize-space($name)
            let $sort-name := replace($name-string,"^\s+|^[mM]rs.\s|^[mM]r.\s|^\(|(['][s]+)|\)",'')
            let $idno := replace($person/tei:idno,'\s|.|,|;', ' ')
            let $related := $person/descendant::tei:relation
            order by $sort-name
            return 
                  <div style="border-bottom:1px solid #eee;">
                    <button class="btn btn-link" 
                    data-bs-toggle="collapse" data-bs-target="{concat('#name',$i,'Show')}">
                        <i class="bi bi-plus-circle"></i>
                    </button> 
                    {normalize-space($name)} ({count($person/descendant::tei:relation)} associated work{if(count($related) gt 1) then 's' else()})
                    {
                    if($person/tei:persName/@type = ('lcnaf','lccn')) then 
                        <a href="http://id.loc.gov/authorities/names/{$person/tei:idno}" alt="Go to Library of Congress authority record"><i class="bi bi-window-plus"></i></a>
                    else if($person/tei:persName/@type = 'orcid') then 
                        <a href="https://orcid.org/{$person/tei:idno}" alt="Go to authority record"><i class="bi bi-window-plus"></i></a>
                    else ()}
                    <div class="panel-collapse collapse {if(count($persNames) = 1) then 'in' else()} left-align" id="{concat('name',$i,'Show')}">{
                        for $r in $related
                        group by $type := $r/@type
                        return 
                            <div style="margin-left:2em;">
                                <p style="font-weight:strong;">{functx:capitalize-first($type)} 
                                {if($type = 'mention') then concat(' (',string($r[1]/@count),')') else () }</p>
                                <ul>{
                                for $work in $r
                                let $id := $work/@active
                                return <li><a href="{$config:nav-base}/work{substring-before(replace($id,$config:data-root,''),'.xml')}">{tei2html:tei2html($work//tei:title)}</a></li>
                                }</ul>
                            </div>
                    }</div>
                </div>
        else ()
};

(: 
   Timeline of dates in the teiHeader/imprint (first imprint reference) linked to the texts a
   network visualization where people and places listed in each text are visible, 
   with larger nodes for higher mentions 
:)
declare function app:timeline() {
    <div>
        <div>
        <h2>Publication Dates</h2>
        <p>A timeline of works in the collection.</p>
        {timeline:timeline()}    
        </div>
    </div>
};

(: 
   Timeline of dates in the teiHeader/imprint (first imprint reference) linked to the texts a
   network visualization where people and places listed in each text are visible, 
   with larger nodes for higher mentions 
:)
declare function app:timeline($node as node(), $model as map(*)) {
    <div>
        <div>
        <h2>Publication Dates</h2>
        <p>A timeline of works in the collection.</p>
        {timeline:timeline()}    
        </div>
    </div>
};
(: 
 : d3js visualization of works/persons/places
:)
declare function app:network() {
    let $dataType := request:get-parameter('data', '')
    let $graphType := request:get-parameter('type', '')
    let $id := request:get-parameter('id', '')
    let $data := 
            if($dataType = 'persNames') then
                if($id != '') then 
                    doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person[tei:idno = $id]
                else doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person
            else if($dataType = 'placeNames') then 
                if($id != '') then
                    doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))//tei:place[tei:idno = $id]
                else doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))//tei:place 
            else if($dataType = 'work') then 
                if($id != '') then
                    doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:relation[@active = $id] | 
                    doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))//tei:relation[@active = $id]
                else doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person | 
                     doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))//tei:place 
            else 
                doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person | 
                doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))//tei:place   
    let $type := if(request:get-parameter('type', '') = 'bubble') then 'bubble' else 'Force'
    let $json := 
            (serialize(d3xquery:build-graph-type($data, (), (), $graphType, ()), 
               <output:serialization-parameters>
                   <output:method>json</output:method>
               </output:serialization-parameters>))
    return 
        if(not(empty($data))) then
            <div>
                <script src="https://d3js.org/d3.v4.min.js"></script>
                {
                if(request:get-parameter('type', '') = 'force') then 
                    (<h2>Collection Graph</h2>,<p>A linked data graph visualizing the connection between works, people and places in the collection.</p>) 
                else if(request:get-parameter('type', '') = 'bubble') then 
                    (<h2>Persons and Places Graph</h2>,<p>A linked data graph visualizing the people and places referenced in the collection.</p>) 
                else <h2>Graph visualization</h2>
                }
                <div id="result" style="min-height:500px;"/>
                <script><![CDATA[
                    $(document).ready(function () {
                        //Start bubble chart here
                        //Get JSON data
                        var rootURL = ']]>{$config:nav-base}<![CDATA[';
                        //var url = ']]>{$config:nav-base}/d3xquery/<![CDATA[';
                        var postData =]]>{$json}<![CDATA[;
                        var id = ']]>{request:get-parameter('id', '')}<![CDATA[';
                        var type = ']]>{$type}<![CDATA[';
                        selectGraphType(postData,rootURL,type)
                        });
                ]]></script>
                  <style><![CDATA[
                    .d3jstooltip {
                      background-color:white;
                      border: 1px solid #ccc;
                      border-radius: 6px;
                      padding:.5em;
                      }
                    }
                    ]]>
                </style>
                <script src="{$config:nav-base}/d3xquery/visualizations.js"/>
            </div>
        else () 
};

(: Check for LOD relationships, do not build graph or buttons f false() :)
declare function app:checkRelationships($node as node(), $model as map(*)){
    let $persNames := if(request:get-parameter('id', '') != '') then 
                                doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person[tei:idno = request:get-parameter('id', '')]
                              else doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person
    let $geojson := if(request:get-parameter('id', '') != '') then
                        doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))//tei:place[tei:idno = request:get-parameter('id', '')]
                    else doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))
    let $reference-data := if(not(empty($model("data")))) then $model("data") else if(not(empty($model("hits")))) then $model("hits") else () 
    let $keys := $reference-data//@key
    let $subset := (for $key in $keys
                    return $geojson//tei:place[tei:idno = concat('http://vocab.getty.edu/tgn/', $key)],
                    for $key in $keys
                    return $persNames//tei:person[tei:idno = $key])                   
    let $type := if(request:get-parameter('type', '') = 'bubble') then 'bubble' else 'Force'
    return if(not(empty($subset))) then true() else false()
};

(: 
 : d3js visualization of works/persons/places
:)
declare function app:network($node as node(), $model as map(*)) {
    let $persNames := if(contains(request:get-uri(),'/coursepack/')) then 
                        doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person
                      else if(request:get-parameter('id', '') != '') then 
                        doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person[tei:idno = request:get-parameter('id', '')]
                      else doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person
    let $geojson := if(contains(request:get-uri(),'/coursepack/')) then 
                        doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))
                    else if(request:get-parameter('id', '') != '') then
                        doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))//tei:place[tei:idno = request:get-parameter('id', '')]
                    else doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))
    let $reference-data := if(not(empty($model("data")))) then $model("data") else if(not(empty($model("hits")))) then $model("hits") else if(not(empty($model("coursepack")))) then $model("coursepack") else () 
    let $keys := $reference-data//@key
    let $subset := if(not(empty($model("data")))) then
                       let $id := document-uri(root($model("data")))
                       return 
                            ($geojson/descendant::tei:relation[@active = $id] | $persNames/descendant::tei:relation[@active = $id])
                   else 
                      for $r in $reference-data
                      let $id := document-uri(root($r))
                      return ($geojson/descendant::tei:relation[@active = $id] | $persNames/descendant::tei:relation[@active = $id])                 
    let $type := if(request:get-parameter('type', '') = 'bubble') then 'bubble' else 'Force'
    let $json := 
            (serialize(d3xquery:build-graph-type($subset, (), (), $type, ()), 
               <output:serialization-parameters>
                   <output:method>json</output:method>
               </output:serialization-parameters>))
    return 
        if(not(empty($subset))) then 
            <div id="LODResults">
                <script src="https://d3js.org/d3.v4.min.js"></script>
                <div id="result" style="min-height:500px;"/>
                <script><![CDATA[
                    $(document).ready(function () {
                        $('#LODBtn').click(function (e) {
                            var rootURL = ']]>{$config:nav-base}<![CDATA[';
                            var postData =]]>{$json}<![CDATA[;
                            var id = ']]>{request:get-parameter('id', '')}<![CDATA[';
                            var type = ']]>{$type}<![CDATA[';
                            if($('#result svg').length == 0){
                               	selectGraphType(postData,rootURL,type);
                               }
                            jQuery(window).trigger('resize');
                           })
                        });
                ]]></script>
                  <style><![CDATA[
                    .d3jstooltip {
                      background-color:white;
                      border: 1px solid #ccc;
                      border-radius: 6px;
                      padding:.5em;
                      }
                    }
                    ]]>
                </style>
                <script src="{$config:nav-base}/d3xquery/visualizations.js"/>
            </div>
        else ()
};
