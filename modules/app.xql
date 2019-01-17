xquery version "3.1";
(: Main application module for LiC: Literature in Context application :)
module namespace app="http://LiC.org/templates";

(: Import eXist modules:)
import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://LiC.org/config" at "config.xqm";
import module namespace kwic="http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";
import module namespace functx="http://www.functx.com";

(: Import application modules. :)
import module namespace tei2html="http://syriaca.org/tei2html" at "content-negotiation/tei2html.xqm";
import module namespace data="http://LiC.org/data" at "lib/data.xqm";

(: Namespaces :)
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
 : Select page view, record or html content
 : If no record is found redirect to 404
 : @param $node the HTML node with the attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)
declare function app:get-work($node as node(), $model as map(*)) {
     if(request:get-parameter('id', '') != '' or request:get-parameter('doc', '') != '') then
        let $rec := data:get-document()
        return 
            if(empty($rec)) then 
                (: Debugging ('No record found. ',xmldb:encode-uri($config:data-root || "/" || request:get-parameter('doc', '') || '.xml')):)
                response:redirect-to(xs:anyURI(concat($config:nav-base, '/404.html')))
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
       <div class="pageImages well">
       <h4>Page images</h4>
       {
            let $root := root($model("data"))
            let $path := document-uri($root)
            let $filename := util:document-name($root)
            let $folder := substring-before($path, concat('/',$filename))
            let $page-images-root := 
                    if($config:image-root != '') then  
                        concat($config:image-root,replace($folder, $config:data-root,''))
                    else replace($folder,'/db/','/exist/')
            for $image in $model("data")//tei:pb[@facs]
            let $src := concat($page-images-root,'/',string($image/@facs))
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
        <div class="dataFormats pull-right">
            {
                for $f in tokenize($formats,',')
                return 
                    if($f = 'tei') then
                        (
                        <a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.tei" class="btn btn-default btn-xs" id="teiBtn" title="Click to view the TEI XML data for this work.">
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> TEI/XML
                        </a>, '&#160;')
                    else if($f = 'pdf') then                        
                        (<a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.pdf" class="btn btn-default btn-xs" id="pdfBtn" data-toggle="tooltip" title="Click to view the PDF for this work.">
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> PDF
                        </a>, '&#160;')                         
                    else if($f = 'epub') then                        
                        (
                        <a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.epub" class="btn btn-default btn-xs" id="epubBtn" data-toggle="tooltip" title="Click to view the EPUB for this work.">
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> EPUB
                        </a>, '&#160;')  
                   else if($f = 'print') then                        
                        (<a href="javascript:window.print();" type="button" class="btn btn-default btn-xs" id="printBtn" data-toggle="tooltip" title="Click to send this page to the printer." >
                             <span class="glyphicon glyphicon-print" aria-hidden="true"></span>
                        </a>, '&#160;')  
                   else if($f = 'rdf') then
                        (<a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.rdf" class="btn btn-default btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to view the RDF-XML data for this record.">
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> RDF/XML
                        </a>, '&#160;')
                  else if($f = 'ttl') then
                        (<a href="{$config:nav-base}/work/{request:get-parameter('doc', '')}.ttl" class="btn btn-default btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to view the RDF-Turtle data for this record." >
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> RDF/TTL
                        </a>, '&#160;')
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
        <div class="coursepack indent-large">
            <h1>No matching Coursepack. </h1>
            <p>To create a new coursepack browse or search the list of <a href="index.html">works</a>.</p>
            <p><a href="{$config:nav-base}/coursepack.html">Browse list</a></p>
        </div>
     else if(request:get-parameter('id', '') != '') then 
             <div class="coursepack">
            <form class="form-inline" method="get" action="{string($coursepacks/@id)}" id="search">
                <div class="coursepack search-box no-print" style="padding:1em; background-color:#F8F8F8;">
                    <label class="coursepackToolbar">Coursepack Toolbar: </label><br/>
                        <a href="{$config:nav-base}/modules/lib/coursepack.xql?action=delete&amp;coursepackid={string($coursepacks/@id)}" class="toolbar btn btn-info">
                        <span class="glyphicon glyphicon-trash" aria-hidden="true"></span> Delete Coursepack </a> 
                        <a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}?view=list" class="toolbar btn btn-info"><span class="glyphicon glyphicon-th-list"/> List </a>
                        <a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}?view=expanded" class="toolbar btn btn-info"><span class="glyphicon glyphicon-plus-sign"/> Expand Works </a>
                        <div class="form-group">
                            <input type="text" class="form-control" id="query" name="query" placeholder="Search String"/>
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
                        <button type="submit" class="btn btn-info"><span class="glyphicon glyphicon-search"/></button> 
                        <label class="coursepackToolbar">Output :&#160;</label> 
                        <a href="javascript:window.print();" type="button" id="printBtn"  class="toolbar btn btn-info"><span class="glyphicon glyphicon-print" aria-hidden="true"></span> Print</a>
                        <a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}.pdf" class="toolbar btn btn-info" id="pdfBtn"><span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> PDF</a>
                        <a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}.epub" class="toolbar btn btn-info" id="epubBtn"><span class="glyphicon glyphicon-print" aria-hidden="true"></span> EPUB</a>
                        <a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}.tei" class="toolbar btn btn-info" id="teiBtn"><span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> TEI</a>
                        <a href="{$config:nav-base}/coursepack/{string($coursepacks/@id)}.txt" class="toolbar btn btn-info" id="textBtn"><span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> Text</a>
                </div>
                <p class="bg-info">{$coursepacks/*:desc}</p>
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
        <div class="coursepack indent-large">
            <h1>Available Coursepacks</h1>
            {
            for $coursepack in $coursepacks
            return 
                <div class="indent" style="padding:.25em;">
                    <a href="{$config:nav-base}/coursepack/{string($coursepack/child::*/@id)}">{string($coursepack/child::*/@title)}</a>
                    <p>{$coursepack/child::*/desc/text()}</p>
                </div>          
            }
        </div>
};

(:~
 : Display paging functions in html templates
:)
declare %templates:wrap function app:pageination($node as node()*, $model as map(*), $sort-options as xs:string*){
   data:pages($model("hits"), $app:start, $app:perpage,app:search-string(), $sort-options)
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
    let $sort-element := 
        if(request:get-parameter('sort-element', '') != '') then request:get-parameter('sort-element', '')
        else ()
    return          
        map { "hits" :=
                for $hit in collection($config:data-root)//tei:TEI
                order by data:filter-sort-string(data:add-sort-options($hit, $sort-element))
                return $hit
        }  
};

(:~
 : Output the search result as a div, using the kwic module to summarize full text matches.            
:)
declare 
    %templates:wrap
    %templates:default("start", 1)
    %templates:default("per-page", 10)
function app:show-hits($node as node()*, $model as map(*), $start as xs:integer, $per-page as xs:integer) {
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
        if(empty($queryExpr) or $queryExpr = "") then
            let $cached := session:get-attribute("search.LiC")
            return
                map {
                    "hits" := $cached,
                    "query" := session:get-attribute("search.LiC.query")
                }
        else
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
                if($parameter = ('start','sort-element','field','target-texts','narrow')) then ()
                else if($parameter = 'query') then 
                        (<span class="query-value">{request:get-parameter($parameter, '')}&#160;</span>, ' in ', <span class="param">{request:get-parameter('field', '')}</span>,'&#160;')
                else (<span class="param">{replace(concat(upper-case(substring($parameter,1,1)),substring($parameter,2)),'-',' ')}: </span>,<span class="match">{request:get-parameter($parameter, '')}&#160; </span>)    
            else ())
            }
    </span>
};