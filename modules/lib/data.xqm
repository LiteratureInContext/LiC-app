xquery version "3.1";
(:~  
 : Basic data interactions, returns raw data for use in other modules  
 : Used by ../app.xql and content-negotiation/content-negotiation.xql  
:)

module namespace data="http://LiC.org/data";
import module namespace config="http://LiC.org/config" at "config.xqm";
import module namespace facet="http://expath.org/ns/facet" at "facet.xqm";
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
        let $coursepack := collection($config:app-root || '/coursepacks')/coursepack[@id = request:get-parameter('id', '')]
        let $docs := for $rec in $coursepack//work
                     return doc(string($rec/@id))
        return 
            ($coursepack, $docs)
    else 
        collection($config:app-root || '/coursepacks') 
};

(:~
 : Return Coursepack and Coursepack content
 : @param $id Coursepack id
:)
declare function data:search-coursepacks() {
    if(request:get-parameter('id', '') != '') then 
        let $coursepack := data:get-coursepacks()
        let $eval-string := concat("$coursepack/tei:TEI",data:create-query())
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
    let $facet-config-file := 'facet-def.xml'
    let $filters := if(request:get-parameter('authorID', '')) then 
                        concat("[descendant::tei:sourceDesc/descendant::tei:author[normalize-space(.) = '",request:get-parameter('authorID', ''),"']]")
                    else()
    let $queryExpr := concat(data:create-query(), $filters)                   
    let $docs := 
                if(request:get-parameter('narrow', '') = 'true' and request:get-parameter('target-texts', '') != '') then
                        for $doc in request:get-parameter('target-texts', '')
                        return doc($doc)
                else ()                        
    let $eval-string := 
                if(request:get-parameter('narrow', '') = 'true' and request:get-parameter('target-texts', '') != '') then
                    concat("$docs/tei:TEI",$queryExpr,facet:facet-filter(doc(concat($config:app-root,'/',$facet-config-file))))                       
                else concat("collection('",$config:data-root,"')/tei:TEI",$queryExpr,facet:facet-filter(doc(concat($config:app-root,'/',$facet-config-file))))
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
            else concat("[descendant::tei:text[ft:query(.,'",$query,"',data:search-options())] or descendant::tei:teiHeader[ft:query(.,'",$query,"',data:search-options())]]")
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