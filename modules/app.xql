xquery version "3.1";
(: Main application module for LiC: Literature in Context application :)
module namespace app="http://LiC.org/templates";

(: Import eXist modules:)
import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://LiC.org/config" at "config.xqm";
import module namespace kwic="http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";
import module namespace functx="http://www.functx.com";
import module namespace http="http://expath.org/ns/http-client";

(: Import application modules. :)
import module namespace timeline="http://LiC.org/timeline" at "lib/timeline.xqm";
import module namespace facet="http://expath.org/ns/facet" at "lib/facet.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "content-negotiation/tei2html.xqm";
import module namespace data="http://LiC.org/data" at "lib/data.xqm";
import module namespace maps="http://LiC.org/maps" at "lib/maps.xqm";
import module namespace d3xquery="http://syriaca.org/d3xquery" at "../d3xquery/d3xquery.xqm";

(: Namespaces :)
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace mads = "http://www.loc.gov/mads/v2";

(: Global Variables :)
declare variable $app:start {request:get-parameter('start', 1) cast as xs:integer};
declare variable $app:perpage {request:get-parameter('perpage', 25) cast as xs:integer};

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
                            <div class="get-more"><br/><a href="coursepack?id={$coursepackId}">Go to coursepack <span class="glyphicon glyphicon-circle-arrow-right" aria-hidden="true"></span></a></div>
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
            else map {"data" := $rec }
    else <blockquote>No record found</blockquote>
};

(:~
 : Output TEI as HTML
 : @param $node the HTML node with the attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)
(: Cludge for TEI stylesheets to only return child of html body, better handling will need to be developed.:)
declare function app:display-work($node as node(), $model as map(*)) {
     if(tei2html:tei2html($model("data")/tei:TEI)) then tei2html:tei2html($model("data")/tei:TEI) 
     else <div>'No record found'</div>
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
                        (<a href="javascript:window.print();" type="button" class="btn btn-primary btn-xs" id="printBtn" data-toggle="tooltip" title="Click to send this page to the printer." >
                             <span class="glyphicon glyphicon-print" aria-hidden="true"></span>
                        </a>, '&#160;')  
                  else if($f = 'notes') then
                        (<button class="btn btn-primary btn-xs" id="notesBtn" data-toggle="collapse" data-target="#teiViewNotes">
                            <span data-toggle="tooltip" title="View Notes">
                                <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span> Editorial Statements
                            </span></button>, '&#160;')   
                  else if($f = 'citation') then
                        (<button class="btn btn-primary btn-xs" id="citationBtn" data-toggle="collapse" data-target="#teiViewCitation">
                            <span data-toggle="tooltip" title="View Citation">
                                <span class="glyphicon glyphicon-book" aria-hidden="true"></span> Citation
                            </span></button>, '&#160;')
                  else if($f = 'sources') then 
                        (<button class="btn btn-primary btn-xs" id="sourcesBtn" data-toggle="collapse" data-target="#teiViewSources">
                            <span data-toggle="tooltip" title="View Source Description">
                                <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span> Source Texts
                            </span></button>, '&#160;') 
                else if($f = 'pageImages') then 
                    if($model("data")/descendant::tei:pb[@facs]) then 
                        if(request:get-parameter('view', '') = 'pageImages') then 
                           (<a href="{request:get-uri()}" class="btn btn-primary btn-xs" id="pageImagesBtn" data-toggle="tooltip" title="Click to hide the page images.">
                                <span class="glyphicon glyphicon-minus-sign" aria-hidden="true"></span> Page Images
                             </a>, '&#160;') 
                        else 
                            (<a href="?view=pageImages" class="btn btn-primary btn-xs" id="pageImagesBtn" data-toggle="tooltip" title="Click to view the page images along side the text.">
                                <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span> Page Images
                             </a>, '&#160;') 
                    else()         
                else if($f = 'lod') then  
                    if($model("data")//@key) then 
                         (<button class="btn btn-primary btn-xs" id="LODBtn" data-toggle="collapse" data-target="#teiViewLOD">
                            <span data-toggle="tooltip" title="View Linked Data">
                                <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span> Linked Data
                            </span></button>, '&#160;')
                    else ()        
                else () 
            }
            { 
                <div class="btn-group" data-toggle="tooltip"  title="Download Work Options">
                          <button type="button" class="btn btn-primary dropdown-toggle btn-xs"
                          data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                           <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> Download <span class="caret"></span>
                          </button>
                          <ul class="dropdown-menu">{
                            for $f in tokenize($formats,',')
                            return 
                                 if($f = 'tei') then
                                     <li><a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.tei" id="teiBtn" data-toggle="tooltip" title="Click to view the TEI XML data for this work.">TEI/XML</a></li>
                                 else if($f = 'pdf') then                        
                                     <li><a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.pdf" id="pdfBtn" data-toggle="tooltip" title="Click to view the PDF for this work.">PDF</a></li>                         
                                 else if($f = 'epub') then                        
                                     <li><a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.epub" id="epubBtn" data-toggle="tooltip" title="Click to view the EPUB for this work.">EPUB</a></li>  
                                else if($f = 'rdf') then
                                     <li><a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.rdf" id="teiBtn" data-toggle="tooltip" title="Click to view the RDF-XML data for this record.">RDF/XML</a></li>
                                else if($f = 'ttl') then
                                     <li><a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.ttl" id="teiBtn" data-toggle="tooltip" title="Click to view the RDF-Turtle data for this record." >RDF/TTL</a></li>
                                else()}     
                        </ul>
                </div>
            }
            {
            <button id="rangy" class="rangy rangy-select btn btn-primary btn-lg" data-url="{$config:nav-base}/modules/lib/coursepack.xql" 
                data-workid="{document-uri(root($model("data")))}"
                data-worktitle="{$model("data")//tei:TEI/descendant::tei:titleStmt/tei:title[1]}" 
                title="Save selection/text to coursepack"> 
                <span data-toggle="tooltip" title="Coursepack tools">
                    <span class="glyphicon glyphicon-duplicate" aria-hidden="true"></span>
                </span>
            </button>
            }            
        </div>
    else ()
};

(: Coursepack display functions :)
(:~
 : Get coursepack by id or list all available coursepacks
:)
declare function app:get-coursepacks($node as node(), $model as map(*)) {
    if(data:create-query() != '') then 
        map {"coursepack" := data:get-coursepacks(),
               "hits" := data:search-coursepacks()  
         }
    else 
        map {"coursepack" :=  data:get-coursepacks()}  
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
        <form class="form-inline coursepack" method="get" action="{string($coursepacks/@id)}" id="search">
            <div class="row">
                <div class="col-md-6"><h1>{string($model("coursepack")/@title)}</h1>
                    <p class="desc">{$coursepacks/*:desc}</p>
                </div>
                <div class="col-md-6">
                <div class="coursepackToolbar">
                    <a href="{$config:nav-base}/modules/lib/coursepack.xql?action=delete&amp;coursepackid={string($coursepacks/@id)}" class="toolbar btn btn-primary deleteCoursepack" data-toggle="tooltip" title="Delete Coursepack"><span class="glyphicon glyphicon-trash" aria-hidden="true"></span></a> 
                        {
                            if(request:get-parameter('view', '') = 'expanded') then 
                                <a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}?view=list" class="toolbar btn btn-primary" data-toggle="tooltip" title="List Coursepack Works"><span class="glyphicon glyphicon-th-list"/> List Works </a>
                            else 
                                <a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}?view=expanded" class="toolbar btn btn-primary" data-toggle="tooltip" title="Expand Coursepack Works to see text"><span class="glyphicon glyphicon-plus-sign"/> Expand Works </a>
                        }
                        {if($model("hits")//@key or $model("coursepack")//@key) then 
                             (<a class="btn btn-primary" id="LODBtn" data-toggle="collapse" data-target="#teiViewLOD">
                                 <span data-toggle="tooltip" title="View Linked Data">
                                     <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span> Linked Data
                                 </span></a>, '&#160;')
                             else () 
                         }
                        <a href="javascript:window.print();" type="button" id="printBtn"  class="toolbar btn btn-primary" data-toggle="tooltip" title="Print Coursepack"><span class="glyphicon glyphicon-print" aria-hidden="true"></span> Print</a>
                        <div class="btn-group" data-toggle="tooltip"  title="Download Coursepack Option">
                          <button type="button" class="btn btn-primary dropdown-toggle"
                          data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                           <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> Download <span class="caret"></span>
                          </button>
                          <ul class="dropdown-menu">
                            <li><a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}.pdf" id="pdfBtn" title="Download Coursepack as PDF">PDF</a></li>
                            <li><a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}.epub" id="epubBtn" title="Download Coursepack as EPUB">EPUB</a></li>
                            <li><a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}.tei"  id="teiBtn" title="Download Coursepack as TEI">TEI</a></li>
                            <li><a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}.txt"  id="textBtn" title="Download Coursepack as plain text">Text</a></li>
                          </ul>
                        </div> 
                </div>
                                   
                </div>
            </div>
        <div class="panel-collapse collapse left-align" id="teiViewLOD">
            {app:subset-lod($node, $model)}
        </div>
        <div class="lic-well coursepack">
                <div class="coursepackToolbar search-box no-print">
                    <div class="form-group">
                        <input type="text" class="form-control" id="query" name="query" placeholder="Search Coursepack"/>
                    </div>
                    <div class="form-group">
                        <select name="field" class="form-control">
                                <option value="keyword" selected="selected">Keyword anywhere</option>
                                <option value="annotation">Keyword in annotations</option>
                                <option value="title">Title</option>
                                <option value="author">Author</option>
                        </select>
                    </div>
                    <div class="form-group">
                            <select name="annotation" class="form-control">
                                <option value="true" selected="selected">Annotations</option>
                                <option value="false">No Annotations</option>
                            </select>
                        </div>
                    <button type="submit" class="btn btn-primary" data-toggle="tooltip" title="Search Coursepack"><span class="glyphicon glyphicon-search"/></button> 
                    {
                        if($hits != '') then 
                            app:pageination-inline($node, $model, 'title,author,pubDate')
                        else
                            <div class="btn-group">
                               <div class="dropdown"><button class="btn btn-default dropdown-toggle" type="button" id="dropdownMenu1" data-toggle="dropdown" aria-expanded="true">Sort <span class="caret"/></button>
                                   <ul class="dropdown-menu pull-right" role="menu" aria-labelledby="dropdownMenu1">
                                       {
                                           for $option in tokenize('title,author,pubDate',',')
                                           return 
                                           <li role="presentation">
                                               <a role="menuitem" tabindex="-1" href="?sort-element={$option}" id="rel">
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
               </div>

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
                    let $id := document-uri(root($work))
                    let $selection := if($coursepacks//work[@id = $id]/text) then
                                        for $text in $coursepacks//work[@id = $id]/text
                                        return 
                                            (<div><h4>Selected Text</h4>,
                                            {tei2html:tei2html($text/child::*)}</div>)
                                      else()
                    order by data:filter-sort-string(data:add-sort-options($work, request:get-parameter('sort-element', '')))
                    group by $workID := $id 
                    return  
                        <div class="result row">
                            <div class="col-md-1">
                             <button data-url="{$config:nav-base}/modules/lib/coursepack.xql?action=deleteWork&amp;coursepackid={string($coursepacks/@id)}&amp;workid={$id}" class="removeWork btn btn-default btn-sm" data-toggle="tooltip" title="Delete Work from Coursepack">
                                <span class="glyphicon glyphicon-trash" aria-hidden="true"></span>
                             </button>
                             <button data-url="{$config:nav-base}/modules/data.xql?id={string($coursepacks/@id)}&amp;view=expand&amp;workid={$id}" class="expand btn btn-default btn-sm" data-toggle="tooltip" title="Expand Work to see text">
                                <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span>
                             </button>
                            </div>
                            <div class="col-md-11">{(
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
                 }      
        </div>
        </form>
    else        
        <div>
            <h1>Available Coursepacks</h1>
            <div class="lic-well coursepack">
                {
                for $coursepack in $coursepacks
                return 
                    <div class="indent">
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
let $pagination-links := 
    (<div class="row alpha-pages" xmlns="http://www.w3.org/1999/xhtml">  
            <div class="col-sm-5 search-string">
                    {if($search-string != '' and request:get-parameter('view', '') != 'author' and request:get-parameter('view', '') != 'title') then        
                        (<h3 class="hit-count paging">Search results:</h3>,
                        <p class="col-md-offset-1 hit-count">{$total-result-count} matches for {$search-string}</p>)
                     else ()   
                    }
            </div>
            <div>
                {if($search-string != '') then attribute class { "col-md-7" } else attribute class { "col-md-12" } }
                {
                if($total-result-count gt $perpage) then 
                <ul class="pagination pull-right">
                    {((: Show 'Previous' for all but the 1st page of results :)
                        if ($current-page = 1) then ()
                        else <li><a href="{concat($param-string, $perpage * ($current-page - 2)) }">Prev</a></li>,
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
                             else <li><a href="{concat($param-string, $newstart)}">{$page}</a></li>,
                        (: Shows 'Next' for all but the last page of results :)
                        if ($start + $perpage ge $total-result-count) then ()
                        else <li><a href="{concat($param-string, $start + $perpage)}">Next</a></li>,
                        if($sort-options != '') then data:sort-options($param-string, $start, $sort-options)
                        else(),
                        <li><a href="{concat($param-string,'1&amp;perpage=',$total-result-count)}">All</a></li>,
                        if($search-string != '') then
                            <li class="pull-right search-new"><a href="search.html"><span class="glyphicon glyphicon-search"/> New</a></li>
                        else (), 
                        if($model("hits")//@key) then 
                             <li class="pull-right"><a href="#" id="LODBtn" data-toggle="collapse" data-target="#teiViewLOD">
                                <span data-toggle="tooltip" title="View Linked Data">
                                    <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span> Linked Data
                                </span></a></li>
                        else()
                        )}
                </ul>
                else 
                <ul class="pagination pull-right">
                {(
                    if($sort-options != '') then data:sort-options($param-string, $start, $sort-options)
                    else(),
                    if($search-string != '') then   
                        <li class="pull-right"><a href="{request:get-url()}"><span class="glyphicon glyphicon-search"/> New</a></li>
                    else(), 
                    if($model("hits")//@key) then 
                         <li class="pull-right"><a href="#" id="LODBtn" data-toggle="collapse" data-target="#teiViewLOD">
                            <span data-toggle="tooltip" title="View Linked Data">
                                <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span> Linked Data
                            </span></a></li>
                    else())}
                </ul>
                }
               
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
            <ul class="pagination">
                {((: Show 'Previous' for all but the 1st page of results :)
                        if ($current-page = 1) then ()
                        else <li><a href="{concat($param-string, $perpage * ($current-page - 2)) }">Prev</a></li>,
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
                             else <li><a href="{concat($param-string, $newstart)}">{$page}</a></li>,
                        (: Shows 'Next' for all but the last page of results :)
                        if ($start + $perpage ge $total-result-count) then ()
                        else <li><a href="{concat($param-string, $start + $perpage)}">Next</a></li>,
                        if($sort-options != '') then data:sort-options($param-string, $start, $sort-options)
                        else(),
                        <li><a href="{concat($param-string,'1&amp;perpage=',$total-result-count)}">All</a></li>,
                        if($search-string != '') then
                            <li class="pull-right search-new"><a href="search.html"><span class="glyphicon glyphicon-search"/> New</a></li>
                        else () 
                        )}
            </ul>
        else 
            <ul class="pagination">
                {(
                    if($sort-options != '') then data:sort-options($param-string, $start, $sort-options)
                    else(),
                    if($search-string != '') then   
                        <li class="pull-right"><a href="{request:get-url()}"><span class="glyphicon glyphicon-search"/> Reset</a></li>
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
    let $hits := data:search()       
    return          
        map { "hits" := 
                    if(request:get-parameter('view', '') = 'author') then
                        for $hit in $hits
                        let $author := $hit/descendant::tei:titleStmt/descendant::tei:author[1]
                        let $name :=  tei2html:persName-last-first($author)
                        group by $facet-grp-p := $name[1]
                        order by normalize-space(string($facet-grp-p)) ascending
                        return 
                            <author xmlns="http://www.w3.org/1999/xhtml" id="{string($author[1]/tei:persName[1]/@key)}" key="{normalize-space(string-join($author[1]/tei:persName[1]//text(),' '))}" name="{normalize-space(string($facet-grp-p))}" count="{count($hit)}">
                                {$hit}
                            </author>
                    else $hits
            }  
};

(:~
 : Simple browse works with sort options
 :)
declare %templates:wrap function app:list-contributors($node as node(), $model as map(*)) {
    let $contributors := doc(replace($config:data-root,'/data','/contributors') || '/editors.xml')//tei:person
    let $hits := data:search()    
    return          
        map { "hits" :=
                    if(request:get-parameter('contributorID', '') != '') then 
                        for $n in $contributors[@xml:id = request:get-parameter('contributorID', '')]
                        order by $n/descendant::tei:surname[1]
                        return <browse xmlns="http://www.w3.org/1999/xhtml" id="{$n/@xml:id}">{$n}</browse>
                    else 
                        for $n in $contributors
                        order by $n/descendant::tei:surname[1]
                        return <browse xmlns="http://www.w3.org/1999/xhtml" id="{$n/@xml:id}">{$n}</browse>,
               "records" := $hits                 
                    
            }  
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
    for $hit at $p in subsequence($model("hits"), $start, $per-page)
    let $id := string($hit/@id)
    let $annotations := $model("records")//tei:text/descendant::tei:note[@resp= 'editors.xml#' || $id]
    (: This slows down the query, and we do not use it:)
    let $texts := $model("records")//tei:titleStmt/descendant::tei:name[@ref= 'editors.xml#' || $id] | $model("records")//tei:teiHeader/descendant::tei:note[@resp= 'editors.xml#' || $id]
    let $count-annotations := count($annotations)
    let $count-texts := count($texts)
    return 
        <div class="result row">
            {
            if(request:get-parameter('contributorID', '') != '') then
                <div xmlns="http://www.w3.org/1999/xhtml"> 
                    <span class="browse-author-name">{concat(string-join($hit/tei:person/tei:persName/tei:surname,' '),', ',string-join($hit/tei:person/tei:persName/tei:forename,' '))}</span> 
                        {if($count-annotations gt 0) then
                            concat(' (',$count-annotations,' annotations)')
                        else ()}
                        <div class="contributor-desc">{(
                            if($hit/tei:person/tei:occupation) then 
                                (for $r at $p in $hit/tei:person/tei:occupation
                                 return (tei2html:tei2html($r), if($p lt count($hit/tei:person/tei:occupation)) then ', ' else ()),
                                 if($hit/tei:person/tei:affiliation[. != '']) then ', ' else ())
                            else (),
                            if($hit/tei:person/tei:affiliation) then 
                                tei2html:tei2html($hit/tei:person/tei:affiliation)
                            else (),
                           if($hit/tei:person/tei:note) then 
                               <p>{ tei2html:tei2html($hit/tei:person/tei:note)}</p>
                            else ()
                            )}</div>
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
                                    <button class="getAnnotated btn btn-link" data-toggle="tooltip" title="View annotations" data-work-id="{$work-id}" data-contributor-id="{$id}">
                                        <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span>
                                    </button> 
                                    <a href="{$url}" class="link-to-work" data-toggle="tooltip" title="Go to work"><span class="glyphicon glyphicon-book" aria-hidden="true"></span></a>&#160;
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
                                    <button class="getTextAnnotated btn btn-link" data-toggle="tooltip" title="View editorial statements" data-work-id="{$work-id}" data-contributor-id="{$id}">
                                        <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span>
                                    </button> 
                                    <a href="{$url}" class="link-to-work" data-toggle="tooltip" title="Go to work"><span class="glyphicon glyphicon-book" aria-hidden="true"></span></a>&#160;
                                    {tei2html:tei2html($title)} ({count($text)} texts)
                                    </span>
                                    <div class="textAnnotationsResults"></div>
                               </div>
                         }
                        </div>
                </div>
            else 
                <div xmlns="http://www.w3.org/1999/xhtml" class="contributor">
                    <button class="getContributorAnnotations btn btn-link" data-toggle="tooltip" title="View annotations" data-contributor-id="{$id}">
                        <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span>
                    </button> 
                    <span class="browse-author-name">{concat(string-join($hit/tei:person/tei:persName/tei:surname,' '),', ',string-join($hit/tei:person/tei:persName/tei:forename,' '))}</span> 
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
                        if($hit/tei:person/tei:occupation) then 
                            (for $r at $p in $hit/tei:person/tei:occupation
                             return (tei2html:tei2html($r), if($p lt count($hit/tei:person/tei:occupation)) then ', ' else ()),
                             if($hit/tei:person/tei:affiliation[. != '']) then ', ' else ())
                        else (),
                        if($hit/tei:person/tei:affiliation) then 
                            tei2html:tei2html($hit/tei:person/tei:affiliation)
                        else (),
                       if($hit/tei:person/tei:note) then 
                           <p>{ tei2html:tei2html($hit/tei:person/tei:note)}</p>
                        else ()
                        )}</div>
                    <div class="contributorAnnotationsResults"></div>
                </div>            
            }
        </div>  
};

(:~
 : Output the search result as a div, using the kwic module to summarize full text matches.            
:)
declare 
    %templates:wrap
    %templates:default("start", 1)
    %templates:default("per-page", 10)
function app:show-hits($node as node()*, $model as map(*), $start as xs:integer, $per-page as xs:integer) {
    if(request:get-parameter('view', '') = 'author') then
        let $per-page := if(not(empty($app:perpage))) then $app:perpage else $per-page
        for $hit at $p in subsequence($model("hits"), $start, $per-page)
        let $author := string($hit/@name)
        let $authorKey := $hit/@id
        let $headnotes := if($authorKey != '') then
                            collection($config:data-root || '/headnotes')//tei:relation[@active[matches(.,concat($authorKey,"(\W.*)?$"))]]
                          else ()
        where $author != ''
        return 
            <div class="result row">
                <span class="col-md-11">
                    <button class="getNestedResults btn btn-link" data-toggle="tooltip" title="View Works" data-author-id="{string($hit/@key)}">
                        <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span>
                    </button>{$author} ({string($hit/@count)} {if(xs:integer($hit/@count) gt 1) then ' works' else ' work'})
                    {if(count($headnotes) gt 0) then
                    for $h in $headnotes
                    let $root := root($h)
                    let $hID := document-uri($root)
                    let $title := $root/descendant::tei:title[1]/text()
                    return 
                    <div class="headnoteInline indent">
                      <input type="checkbox" name="target-texts" class="coursepack headnoteCheckbox" value="{$hID}" data-title="{$title}"/>
                      <span class="HeadnoteLabel">{(tei2html:summary-view($root, (), $hID[1])) }</span>
                    </div>
                  else ()}
                    <div class="nestedResults"></div>
                 </span>
            </div>     
    (:Standard display/title :)
    else 
        let $per-page := if(not(empty($app:perpage))) then $app:perpage else $per-page
        for $hit at $p in subsequence($model("hits"), $start, $per-page)
        let $root := root($hit)
        let $id := document-uri(root($hit))
        let $title := $hit/descendant::tei:title[1]/text()
        let $expanded := kwic:expand($hit)
        let $xmlId := $root//tei:TEI/@xml:id
        let $headnotes := if($xmlId != '') then
                            collection($config:data-root || '/headnotes')//tei:relation[@active[matches(.,concat($xmlId,"(\W.*)?$"))]]
                          else ()
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
                    "hits" := $hits,
                    "query" := $queryExpr
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
 : Display Timeline. Uses http://timeline.knightlab.com/
:)
declare function app:timeline($data as node()*, $title as xs:string*){
(: Test for valid dates json:xml-to-json() May want to change some css styles for font:)
if($data/descendant-or-self::tei:imprint/descendant::tei:date[@when or @to or @from or @notBefore or @notAfter]) then 
    <div class="timeline">
        <script type="text/javascript" src="http://cdn.knightlab.com/libs/timeline/latest/js/storyjs-embed.js"/>
        <script type="text/javascript">
        <![CDATA[
            $(document).ready(function() {
                var parentWidth = $(".timeline").width();
                createStoryJS({
                    start:      'start_at_end',
                    type:       'timeline',
                    width:      "'" +parentWidth+"'",
                    height:     '325',
                    source:     ]]>{timeline:get-dates($data, $title)}<![CDATA[,
                    embed_id:   'my-timeline'
                    });
                });
                ]]>
        </script>
    <div id="my-timeline"/>
    <p>*Timeline generated with <a href="http://timeline.knightlab.com/">http://timeline.knightlab.com/</a></p>
    </div>
else ()
};

(:
 : Display facets from HTML page 
 : @param $collection passed from html 
 : @param $facets relative (from collection root) path to facet-config file if different from facet-config.xml
:)
declare function app:display-facets($node as node(), $model as map(*), $facet-def-file as xs:string?){
    let $hits := $model("hits")
    let $facet-config-file := 'facet-def.xml'
    let $facet-config := 
             if(doc-available(concat($config:app-root,'/',$facet-config-file))) then
                 doc(concat($config:app-root,'/',$facet-config-file))
             else ()
    return 
        if(not(empty($facet-config))) then 
            facet:html-list-facets-as-buttons(facet:count($hits, $facet-config/descendant::facet:facet-definition))
        else ()
};

(: Login functions :)
(: Activate login module use userManager.xql to login and create new users. :)
declare function app:username-login($node as node(), $model as map(*)) {
    let $user:= 
        if(request:get-attribute($config:login-domain || ".user")) then request:get-attribute($config:login-domain || ".user") 
        else xmldb:get-current-user()    
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
                        <button class="btn btn-primary dropdown-toggle" type="button" data-toggle="dropdown">
                        <span class="glyphicon glyphicon-user"/> {$userName} <span class="caret"></span>
                        </button>
                        <ul class="dropdown-menu">
                          <li><a href="{$config:nav-base}/user.html?user={$user}">Account</a></li>
                          <li><a href="{$config:nav-base}/login?logout=true" id="logout">Logout</a></li>
                        </ul>
                      </div>
                    </p>
                </li>
            </ul>
        else 
             <ul class="nav navbar-nav">
                <li>
                    <p class="navbar-btn">
                       <a data-toggle="modal" href="#loginModal" class="btn btn-primary dropdown-toggle">
                         <span class="glyphicon glyphicon-user"/> Login
                        </a>
                    </p>
                </li>
            </ul>
};

(: ? :)
declare 
    %templates:wrap
function app:userinfo($node as node(), $model as map(*)) as map(*) {
    let $user:=         
        if(request:get-attribute($config:login-domain || ".user")) then request:get-attribute($config:login-domain || ".user") 
        else xmldb:get-current-user()
    let $name := if ($user) then sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson')) else 'Guest'
    let $group := if ($user) then sm:get-user-groups($user) else 'guest'
    return
        map { "user-id" := $user, "user-name" := $name, "user-groups" := $group}
};


declare 
    %templates:wrap
function app:display-userinfo($node as node(), $model as map(*)) {
    let $user:= 
        if(request:get-attribute($config:login-domain || ".user")) then request:get-attribute($config:login-domain || ".user") 
        else xmldb:get-current-user()
    let $userName := 
            if(sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson'))) then 
                sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson')) 
            else $user 
    let $coursepacks := collection($config:app-root || '/coursepacks')/coursepack[@user = $user]            
    return
        <div>
            <h1>{$user} : {$userName}</h1>
            <h3>Your coursepacks:</h3>
            {for $coursepack in $coursepacks
             return 
                    <div class="indent">
                        <h4><a href="{$config:nav-base}/coursepack/{string($coursepack/@id)}">{string($coursepack/@title)}</a></h4>
                        <p class="desc">{$coursepack/desc/text()}</p>
                    </div> 
            }
        </div>
};

(: LOD functions :)
(:~ 
 : Display LOD data across collection 
 :)
declare 
    %templates:wrap
function app:lod($node as node(), $model as map(*)) { 
    <div>
        <h1>Linked Data</h1>
        <p>Explore the collection using linked open data.</p>
        <ul class="nav nav-tabs">
            <li class="{if(request:get-parameter('view', '') = 'map') then 'active' else if(request:get-parameter('view', '') = '') then 'active' else ()}"><a href="?view=map">Places</a></li>
            <li class="{if(request:get-parameter('view', '') = 'persName') then 'active' else ()}"><a href="?view=persName">Persons</a></li>
            <li class="{if(request:get-parameter('view', '') = 'timeline') then 'active' else ()}"><a href="?view=timeline">Timeline</a></li>
            <li class="{if(request:get-parameter('view', '') = 'graph' and request:get-parameter('type', '') = 'force') then 'active' else ()}"><a href="?view=graph&amp;type=force&amp;data=all">Collection Graph</a></li>
            <li class="{if(request:get-parameter('view', '') = 'graph' and request:get-parameter('type', '') = 'bubble') then 'active' else ()}"><a href="?view=graph&amp;type=bubble&amp;data=all">Persons and Places Graph</a></li>
        </ul>
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
    let $graph := app:network($node, $model)
    return 
        if(not(empty($graph))) then
            <div>
                 <h2>Linked Data: <small>Persons and places related to this work.</small></h2>
                 {$graph}
             </div> 
        else ()
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
    let $geojson := if(request:get-parameter('id', '') != '') then
                        doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))//tei:place[tei:idno = request:get-parameter('id', '')]
                    else doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/placeNames.xml')))
    let $reference-data := if(not(empty($model("data")))) then $model("data") else if(not(empty($model("hits")))) then $model("hits") else () 
    let $subset := for $key in $reference-data//@key
                   return $geojson//tei:place[tei:idno = concat('http://vocab.getty.edu/tgn/', $key)]
    return 
        if(not(empty($subset))) then
            (: This should just be a map of places, not work, should be able to pass in map type :)
            <div>{maps:build-map($subset)}</div>
        else ()
};

(:~
 : List all the persNames mentioned
 :)
declare function app:persons() {
    <div>
        <div>
        <h2>Persons</h2>
        <p>Persons referenced in the collection. </p>
        {   let $persNames := if(request:get-parameter('id', '') != '') then 
                                doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person[tei:idno = request:get-parameter('id', '')]
                              else doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/persNames.xml')))//tei:person
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
                    data-toggle="collapse" data-target="{concat('#name',$i,'Show')}">
                        <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span>
                    </button> 
                    {normalize-space($name)} ({count($person/descendant::tei:relation)} associated work{if(count($related) gt 1) then 's' else()})
                    {
                    if($person/tei:persName/@type = ('lcnaf','lccn')) then 
                        <a href="http://id.loc.gov/authorities/names/{$person/tei:idno}" alt="Go to Library of Congress authority record"><span class="glyphicon glyphicon-new-window" aria-hidden="true" data-toggle="tooltip" title="Go to Library of Congress authority record"></span></a>
                    else if($person/tei:persName/@type = 'orcid') then 
                        <a href="https://orcid.org/{$person/tei:idno}" alt="Go to authority record"><span class="glyphicon glyphicon-new-window" aria-hidden="true" data-toggle="tooltip" title="Go to authority record"></span></a>
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
        }</div>
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
                    data-toggle="collapse" data-target="{concat('#name',$i,'Show')}">
                        <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span>
                    </button> 
                    {normalize-space($name)} ({count($person/descendant::tei:relation)} associated work{if(count($related) gt 1) then 's' else()})
                    {
                    if($person/tei:persName/@type = ('lcnaf','lccn')) then 
                        <a href="http://id.loc.gov/authorities/names/{$person/tei:idno}" alt="Go to Library of Congress authority record"><span class="glyphicon glyphicon-new-window" aria-hidden="true" data-toggle="tooltip" title="Go to Library of Congress authority record"></span></a>
                    else if($person/tei:persName/@type = 'orcid') then 
                        <a href="https://orcid.org/{$person/tei:idno}" alt="Go to authority record"><span class="glyphicon glyphicon-new-window" aria-hidden="true" data-toggle="tooltip" title="Go to authority record"></span></a>
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
                <div id="result" style="height:500px;"/>
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
                <div id="result" style="max-height:300px;"/>
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

