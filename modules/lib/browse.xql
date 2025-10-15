xquery version "3.1";
(: For dynamically loading browse and search functions.   :)

(: Import application modules. :)
import module namespace config="http://LiC.org/apps/config" at "../config.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "../content-negotiation/tei2html.xqm";
import module namespace data="http://LiC.org/apps/data" at "data.xqm";
import module namespace kwic="http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";

(: Namespaces :)
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace html="http://www.w3.org/1999/xhtml";

let $doc := request:get-parameter('doc', '')
let $annotationID := request:get-parameter('annotationID', '')
let $contributorID := request:get-parameter('contributorID', '')
let $authorID := request:get-parameter('authorID', '')
let $perpage := if(request:get-parameter('perPage', '') != '') then request:get-parameter('perPage', '') else 5
let $start := if(request:get-parameter('start', '') != '') then request:get-parameter('start', '') else 1
let $hits := data:search()
for $hit at $p in subsequence($hits, $start, $perpage)
let $id := document-uri(root($hit))
let $title := $hit/descendant::tei:title[1]/text()
let $expanded := kwic:expand($hit)
return 
    (<div class="result row">
        <span class="checkbox col-md-1"><input type="checkbox" name="target-texts" class="coursepack" value="{$id}" data-title="{$title}" aria-label="{$title}"/></span>
        <span class="col-md-11">{(tei2html:summary-view($hit, (), $id[1])) }
            {if($expanded//exist:match) then  
                <span class="result-kwic">{tei2html:output-kwic($expanded, $id)}</span>
             else ()}
        </span>

    </div>,
    if($p = $perpage and count($hits) gt $perpage) then
        <div class="get-more"><br/><a href="?authorID={$authorID}">All works <i class="bi bi-arrow-right-circle"></i></a></div>
    else ()
    )
(:
authors
let $author := $hit/descendant::tei:sourceDesc/descendant::tei:author
:)
