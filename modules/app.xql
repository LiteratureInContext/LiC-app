xquery version "3.1";
(: Main application module for LiC: Literature in Context application :)
module namespace app="http://LiC.org/templates";

(: Import eXist modules:)
import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://LiC.org/config" at "config.xqm";
import module namespace timeline="http://LiC.org/timeline" at "lib/timeline.xqm";
import module namespace facet="http://expath.org/ns/facet" at "lib/facet.xqm";
import module namespace kwic="http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";
import module namespace functx="http://www.functx.com";

(: Import application modules. :)
import module namespace tei2html="http://syriaca.org/tei2html" at "content-negotiation/tei2html.xqm";
import module namespace data="http://LiC.org/data" at "lib/data.xqm";

(: Namespaces :)
declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace html="http://www.w3.org/1999/xhtml";

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
        else if(starts-with($slide/@imageURL,'/resources/')) then concat($config:nav-base,string($slide/@imageURL)) 
        else ()
    let $image := if($imageURL != '') then 
                    <img src="{$imageURL}" alt="{if($slide/@imageDesc != '') then string($slide/@imageDesc) else 'Featured image'}"/>
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
                            {if($imageURL != '') then 
                                 <div class="col-md-4">{$image}</div>
                            else ()}
                            <div class="coursepack {if($imageURL != '') then 'col-md-8' else 'col-md-12'}">
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
                            {if($imageURL != '') then 
                                 <div class="col-md-4">{$image}</div>
                            else ()}
                            <div class="work {if($imageURL != '') then 'col-md-8' else 'col-md-12'}">
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
                if(not(empty(data:get-coursepacks()))) then map {"data" := 'Output plain HTML page'}
                else response:redirect-to(xs:anyURI(concat($config:nav-base, '/404.html')))
            else map {"data" := $rec }
    else map {"data" := 'Output plain HTML page'}
};

(:~
 : Output TEI as HTML
 : @param $node the HTML node with the attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)
(: Cludge for TEI stylesheets to only return child of html body, better handling will need to be developed.:)
declare function app:display-work($node as node(), $model as map(*)) {
     tei2html:tei2html($model("data")/tei:TEI)
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
 : Display teiHeader  
:)
declare function app:teiHeader($node as node(), $model as map(*)){
    let $data := $model("data")/descendant::tei:teiHeader
    return tei2html:header($data)
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
            for $image in $model("data")//tei:pb[@facs]
            let $src := 
                if(starts-with($image/@facs,'https://') or starts-with($image/@facs,'http://')) then 
                    string($image/@facs) 
                else concat($config:image-root,'/',string($image/@facs))
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
                    if($f = 'tei') then
                        (
                        <a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.tei" class="btn btn-primary btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to view the TEI XML data for this work.">
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> TEI/XML
                        </a>, '&#160;')
                    else if($f = 'pdf') then                        
                        (<a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.pdf" class="btn btn-primary btn-xs" id="pdfBtn" data-toggle="tooltip" title="Click to view the PDF for this work.">
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> PDF
                        </a>, '&#160;')                         
                    else if($f = 'epub') then                        
                        (
                        <a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.epub" class="btn btn-primary btn-xs" id="epubBtn" data-toggle="tooltip" title="Click to view the EPUB for this work.">
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> EPUB
                        </a>, '&#160;')  
                   else if($f = 'print') then                        
                        (<a href="javascript:window.print();" type="button" class="btn btn-primary btn-xs" id="printBtn" data-toggle="tooltip" title="Click to send this page to the printer." >
                             <span class="glyphicon glyphicon-print" aria-hidden="true"></span>
                        </a>, '&#160;')  
                   else if($f = 'rdf') then
                        (<a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.rdf" class="btn btn-primary btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to view the RDF-XML data for this record.">
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> RDF/XML
                        </a>, '&#160;')
                  else if($f = 'ttl') then
                        (<a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.ttl" class="btn btn-primary btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to view the RDF-Turtle data for this record." >
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> RDF/TTL
                        </a>, '&#160;')
                  else if($f = 'notes') then
                        (<button class="btn btn-primary btn-xs" id="notesBtn" data-toggle="collapse" data-target="#teiViewNotes">
                            <span data-toggle="tooltip" title="View Notes">
                                <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span> Editorial Statements
                            </span></button>, '&#160;')   
                  else if($f = 'sources') then 
                        (<button class="btn btn-primary btn-xs" id="sourcesBtn" data-toggle="collapse" data-target="#teiViewSources">
                            <span data-toggle="tooltip" title="View Source Description">
                                <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span> Source Texts
                            </span></button>, '&#160;') 
                  else () 
            }            
        </div>
    else ()
};

(: Course pack display functions :)
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
         <div class="lic-well coursepack">
            <form class="form-inline" method="get" action="{string($coursepacks/@id)}" id="search">
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
                    <a href="{$config:nav-base}/modules/lib/coursepack.xql?action=delete&amp;coursepackid={string($coursepacks/@id)}" class="toolbar btn btn-primary" data-toggle="tooltip" title="Delete Coursepack">
                        <span class="glyphicon glyphicon-trash" aria-hidden="true"></span></a> 
                    {
                    if(request:get-parameter('view', '') = 'expanded') then 
                        <a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}?view=list" class="toolbar btn btn-primary" data-toggle="tooltip" title="List Coursepack Works"><span class="glyphicon glyphicon-th-list"/> List Works </a>
                    else 
                        <a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}?view=expanded" class="toolbar btn btn-primary" data-toggle="tooltip" title="Expand Coursepack Works to see text"><span class="glyphicon glyphicon-plus-sign"/> Expand Works </a>
                    }
                    <a href="javascript:window.print();" type="button" id="printBtn"  class="toolbar btn btn-primary" data-toggle="tooltip" title="Print Coursepack"><span class="glyphicon glyphicon-print" aria-hidden="true"></span> Print</a>
                    <a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}.pdf" class="toolbar btn btn-primary" id="pdfBtn" data-toggle="tooltip" title="Download Coursepack as PDF"><span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> PDF</a>
                    <a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}.epub" class="toolbar btn btn-primary" id="epubBtn" data-toggle="tooltip" title="Download Coursepack as EPUB"><span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> EPUB</a>
                    <a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}.tei" class="toolbar btn btn-primary" id="teiBtn" data-toggle="tooltip" title="Download Coursepack as TEI"><span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> TEI</a>
                    <a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}.txt" class="toolbar btn btn-primary" id="textBtn" data-toggle="tooltip" title="Download Coursepack as plain text"><span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> Text</a>
                </div>
                <p class="desc">{$coursepacks/*:desc}</p>
                 {
                 if($hits != '') then
                     (app:pageination($node, $model, 'title,author,pubDate'),app:show-hits($node, $model, 1, 10))
                 else if(data:create-query() != '') then
                     <div>No results.</div>
                 else 
                    for $work in $coursepacks/descendant-or-self::tei:TEI
                    let $title := $work/descendant::tei:title[1]/text()
                    let $id := document-uri(root($work))
                    return  
                        <div class="result row">
                            <span class="col-md-1">
                             <button data-url="{$config:nav-base}/modules/lib/coursepack.xql?action=deleteWork&amp;coursepackid={string($coursepacks/@id)}&amp;workid={$id}" class="removeWork btn btn-default">
                             <span class="glyphicon glyphicon-trash" aria-hidden="true"></span></button> 
                            </span>
                            <span class="col-md-11">{(
                                if(request:get-parameter('view', '') = 'expanded') then 
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
                                else tei2html:summary-view($work, (), $id[1])) }</span>
                        </div> 
                 }      
          </form>
        </div>
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
                        else ()    
                        )}
                </ul>
                else 
                <ul class="pagination pull-right">
                {(
                    if($sort-options != '') then data:sort-options($param-string, $start, $sort-options)
                    else(),
                    if($search-string != '') then   
                        <li class="pull-right"><a href="{request:get-url()}"><span class="glyphicon glyphicon-search"/> New</a></li>
                    else() 
                    )}
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
                        let $author := $hit/descendant::tei:titleStmt/descendant::tei:author/tei:persName/tei:name
                        let $name := normalize-space(string-join((if($author/@reg) then string($author/@reg) 
                                     else if($author/tei:surname) then 
                                        concat(string-join($author/tei:surname,' '),', ',string-join($author/tei:forename,' '))
                                     else $author//text()),' '))
                        group by $facet-grp-p := $name[1]
                        order by normalize-space(string($facet-grp-p)) ascending
                        return 
                            <author xmlns="http://www.w3.org/1999/xhtml" key="{normalize-space(string-join(($author[1]),''))}" name="{normalize-space(string($facet-grp-p))}" count="{count($hit)}">
                                {$hit}
                            </author>
                    else $hits
            }  
};

(:~
 : Simple browse works with sort options
 :)
declare %templates:wrap function app:list-contributors($node as node(), $model as map(*)) {
    let $contributors := doc($config:data-root || '/editors.xml')//tei:person
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
        where $author != ''
        return 
            <div class="result row">
                <span class="col-md-11">
                    <button class="getNestedResults btn btn-link" data-toggle="tooltip" title="View Works" data-author-id="{string($hit/@key)}">
                        <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span>
                    </button>{$author} ({string($hit/@count)} {if(xs:integer($hit/@count) gt 1) then ' works' else ' work'})
                    <div class="nestedResults"></div>
                 </span>
            </div>           
    (:Standard display/title :)
    else 
        let $per-page := if(not(empty($app:perpage))) then $app:perpage else $per-page
        for $hit at $p in subsequence($model("hits"), $start, $per-page)
        let $id := document-uri(root($hit))
        let $title := $hit/descendant::tei:title[1]/text()
        let $expanded := kwic:expand($hit)
        return
            <div class="result row">
                <span class="checkbox col-md-1"><input type="checkbox" name="target-texts" class="coursepack" value="{$id}" data-title="{$title}"/></span>
                <span class="col-md-11">
                {(tei2html:summary-view($hit, (), $id[1])) }
                {if($expanded//exist:match) then  
                    <span class="result-kwic">{tei2html:output-kwic($expanded, $id)}</span>
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
                 doc(concat($config:app-root,$facet-config-file))
             else ()
    return 
        if(not(empty($facet-config))) then 
            facet:html-list-facets-as-buttons(facet:count($hits, $facet-config/descendant::facet:facet-definition))
        else ()
};
