xquery version "3.1";
(:~  
 : Basic data interactions, returns raw data for use in other modules  
 : Used by ../app.xql and content-negotiation/content-negotiation.xql  
:)

module namespace data="http://LiC.org/data";
import module namespace config="http://LiC.org/config" at "config.xqm";
import module namespace functx="http://www.functx.com";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace util="http://exist-db.org/xquery/util";

(:~
 : Return document by id/tei:idno or document path
 : Return by ID if @param $id
 : Return by document path if @param $doc
 : @param $id return document by id or tei:idno
 : @param $doc return document path relative to data-root
:)
declare function data:get-document() {
    (: Get document by id or tei:idno:)
    if(request:get-parameter('id', '') != '') then   
        if(not(empty(collection($config:data-root)//id(request:get-parameter('id', ''))))) then 
           root(collection($config:data-root)/id(request:get-parameter('id', '')))
        else root(collection($config:data-root)//tei:idno[. = request:get-parameter('id', '')])
    (: Get document by document path. :)
    else if(request:get-parameter('doc', '') != '') then 
        if(starts-with(request:get-parameter('doc', ''),$config:data-root)) then 
            doc(xmldb:encode-uri(request:get-parameter('doc', '') || '.xml'))
        else doc(xmldb:encode-uri($config:data-root || "/" || request:get-parameter('doc', '') || '.xml'))
    else ()
};

(:~
 : Return Coursepack and Coursepack content
 : @param $id Coursepack id
:)
declare function data:get-coursepacks() {
    if(request:get-parameter('id', '') != '') then 
        (collection($config:app-root || '/coursepacks')//*[@id = (request:get-parameter('id', ''))],
        collection($config:data-root)/tei:TEI[descendant::tei:idno[@type='coursepack'][. = request:get-parameter('id', '')]])
    else 
        collection($config:app-root || '/coursepacks') 
};

(:~
 : Return Coursepack and Coursepack content
 : @param $id Coursepack id
:)
declare function data:search-coursepacks() {
    if(request:get-parameter('id', '') != '') then 
        let $eval-string := concat("collection('",$config:data-root,"')/tei:TEI[descendant::tei:idno[@type='coursepack'][. = '",request:get-parameter('id', ''),"']]",data:create-query())
        return  
            if(request:get-parameter('sort-element', '') != ('','relevance')) then 
                for $hit in util:eval($eval-string)
                order by data:filter-sort-string(data:add-sort-options($hit, request:get-parameter('sort-element', '')))
                return $hit
            else 
                for $hit in util:eval($eval-string)
                order by ft:score($hit) descending
                return $hit
    else ()
};

(:~
 : Main search functions.
 : Build a search based on search parameters. 
 : Add sort options. 
:)
declare function data:search() {
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
        if(request:get-parameter('sort-element', '') != ('','relevance')) then 
            for $hit in util:eval($eval-string)
            order by data:filter-sort-string(data:add-sort-options($hit, request:get-parameter('sort-element', '')))
            return $hit
        else 
            for $hit in util:eval($eval-string)
            order by ft:score($hit) descending
            return $hit
};    

(:~   
 : Builds general search string.
:)
declare function data:create-query() as xs:string?{
    let $field := request:get-parameter('field', '')
    let $query := data:clean-string(request:get-parameter('query', ''))
    return 
        if($query != '') then 
            if($field = 'title') then
                concat("[descendant::tei:titleStmt/tei:title[ft:query(.,'",$query,"',data:search-options())]]")
            else if($field = 'author') then
                concat("[descendant::tei:titleStmt/tei:author[ft:query(.,'",$query,"',data:search-options())] or descendant::tei:titleStmt/tei:editor[ft:query(.,'",$query,"',data:search-options())]]")
            else if($field = 'annotation') then
                concat("[descendant::tei:note[ft:query(.,'",$query,"',data:search-options())]]")
            else if(request:get-parameter('annotation', '') = 'true') then
                concat("[descendant::tei:text[ft:query(.,'",$query,"',data:search-options())] or descendant::tei:note[ft:query(.,'",$query,"',data:search-options())]]")
            else concat("[descendant::tei:text[ft:query(.,'",$query,"',data:search-options())]]")
        else ()
      
};

(:
 : General search function to pass in any tei element. 
 : @param $element element name must have a lucene index defined on the element
 : @param $query query text to be searched. 
:)
declare function data:element-search($element, $query){
    if(exists($element) and $element != '') then 
        concat("[ft:query(descendant::tei:",$element,",'",data:clean-string($query),"',data:search-options())]") 
    else '' 
};

(:
 : General search function to pass in any tei element. 
 : @param $element element name must have a lucene index defined on the element
 : @param $query query text to be searched. 
:)
declare function data:xpath-search($xpath, $query){
    if(exists($query) and $query != '') then 
        concat("[ft:query(",$xpath,",'",data:clean-string($query),"',data:search-options())]") 
    else '' 
};

(:~
 : Search options passed to ft:query functions
:)
declare function data:search-options(){
    <options>
        <default-operator>and</default-operator>
        <phrase-slop>1</phrase-slop>
        <leading-wildcard>yes</leading-wildcard>
        <filter-rewrite>yes</filter-rewrite>
    </options>
};

(:~
 : Cleans search parameters to replace bad/undesirable data in strings
 : @param-string parameter string to be cleaned
:)
declare function data:clean-string($string){
let $query-string := $string
let $query-string := 
	   if (functx:number-of-matches($query-string, '"') mod 2) then 
	       replace($query-string, '"', ' ')
	   else $query-string   (:if there is an uneven number of quotation marks, delete all quotation marks.:)
let $query-string := 
	   if ((functx:number-of-matches($query-string, '\(') + functx:number-of-matches($query-string, '\)')) mod 2 eq 0) 
	   then $query-string
	   else translate($query-string, '()', ' ') (:if there is an uneven number of parentheses, delete all parentheses.:)
let $query-string := 
	   if ((functx:number-of-matches($query-string, '\[') + functx:number-of-matches($query-string, '\]')) mod 2 eq 0) 
	   then $query-string
	   else translate($query-string, '[]', ' ') (:if there is an uneven number of brackets, delete all brackets.:)
let $query-string := replace($string,"'","''")	   
return 
    if(matches($query-string,"(^\*$)|(^\?$)")) then 'Invalid Search String, please try again.' (: Must enter some text with wildcard searches:)
    else replace(replace($query-string,'<|>|@|&amp;',''), '(\.|\[|\]|\\|\||\-|\^|\$|\+|\{|\}|\(|\)|(/))','\\$1')

};

(: Paging and sorting :)
(:~ 
 : Adds sort filter based on sort prameter
 : Additional options can be added here, with matching xpath expressions. 
 : @param $hit hits from query
 : @param $sort-element element to sort on, defaults to title. 
:)
declare function data:add-sort-options($hit, $sort-element as xs:string?){
    if($sort-element != '') then
        if($sort-element = 'title') then 
            $hit/descendant::tei:titleStmt/descendant::tei:title[1]
        else if($sort-element = 'author') then 
            if($hit/descendant::tei:titleStmt/descendant::tei:author[1]) then 
                if($hit/descendant::tei:titleStmt/descendant::tei:author[1]/descendant-or-self::tei:surname) then 
                    $hit/descendant::tei:titleStmt/descendant::tei:author[1]/descendant-or-self::tei:surname[1]
                else $hit/descendant::tei:titleStmt/descendant::tei:author[1]
            else 
                if($hit/descendant::tei:titleStmt/descendant::tei:editor[1]/descendant-or-self::tei:surname) then 
                    $hit/descendant::tei:titleStmt/descendant::tei:editor[1]/descendant-or-self::tei:surname[1]
                else $hit/descendant::tei:titleStmt/descendant::tei:editor[1]
        else if($sort-element = 'pubDate') then 
            $hit/descendant::tei:titleStmt/descendant::tei:imprint[1]/descendant-or-self::tei:date[1]
        else if($sort-element = 'pubPlace') then 
            $hit/descendant::tei:titleStmt/descendant::tei:imprint[1]/descendant-or-self::tei:pubPlace[1]
        else if($sort-element = 'persDate') then
            if($hit/descendant::tei:birth) then $hit/descendant::tei:birth/@when
            else if($hit/descendant::tei:death) then $hit/descendant::tei:death/@when
            else ()
        else $hit
    else $hit
};

(:~
 : Strips English titles of non-sort characters as established by Syriaca.org
 : Used for alphabetizing
 : @param $string 
 :)
declare function data:filter-sort-string($string as node()*) as xs:string* {
    replace(normalize-space(string-join($string,'')),'^[^\p{L}]+|^[aA]\s+|^[aA]l-|^[aA]n\s|^[oO]n\s+[aA]\s+|^[oO]n\s+|^[tT]he\s+[^\p{L}]+|^[tT]he\s+|^A\s+|^''De|[0-9]*','')
};

(:~
 : Build paging menu for search results, includes search string
 : $param @hits hits as nodes
 : $param @start start number passed from url
 : $param @perpage number of hits to show 
 : $param @sort include search options 
:)
declare function data:pages(
    $hits as node()*, 
    $start as xs:integer?, 
    $perpage as xs:integer?, 
    $search-string as xs:string*,
    $sort-options as xs:string*){
let $perpage := if($perpage) then xs:integer($perpage) else 20
let $start := if($start) then $start else 1
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
            {
            if($search-string != '') then             
                <div class="col-sm-5 search-string">
                    <h3 class="hit-count paging">Search results:</h3>
                    <p class="col-md-offset-1 hit-count">{$total-result-count} matches for {$search-string}</p>        
                 </div>
             else ()
             }
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
                        <li class="pull-right"><a href="search.html"><span class="glyphicon glyphicon-search"/> New</a></li>
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
 : Build sort options menu for search/browse results
 : $param @param-string search parameters passed from URL, empty for browse
 : $param @start start number passed from url 
 : $param @options include search options a comma separated list
:)
declare function data:sort-options($param-string as xs:string?, $start as xs:integer?, $options as xs:string*){
<li xmlns="http://www.w3.org/1999/xhtml">
    <div class="btn-group">
        <div class="dropdown"><button class="btn btn-default dropdown-toggle" type="button" id="dropdownMenu1" data-toggle="dropdown" aria-expanded="true">Sort <span class="caret"/></button>
            <ul class="dropdown-menu pull-right" role="menu" aria-labelledby="dropdownMenu1">
                {
                    for $option in tokenize($options,',')
                    return 
                    <li role="presentation">
                        <a role="menuitem" tabindex="-1" href="{concat(replace($param-string,'&amp;sort-element=(\w+)', ''),$start,'&amp;sort-element=',$option)}" id="rel">
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
</li>
};

