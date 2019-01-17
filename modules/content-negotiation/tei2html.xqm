xquery version "3.0";
(:~
 : Builds tei conversions. 
 : Used by oai, can be plugged into other outputs as well.
 :)
 
module namespace tei2html="http://syriaca.org/tei2html";
import module namespace config="http://LiC.org/config" at "../config.xqm";

declare namespace html="http://purl.org/dc/elements/1.1/";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xlink = "http://www.w3.org/1999/xlink";
declare namespace util="http://exist-db.org/xquery/util";

(:~
 : Simple TEI to HTML transformation
 : @param $node   
:)
declare function tei2html:tei2html($nodes as node()*) as item()* {
    for $node in $nodes
    return 
        typeswitch($node)
            case text() return $node
            case comment() return ()
            case element(tei:biblScope) return element span {
                let $unit := if($node/@unit = 'vol') then concat($node/@unit,'.') 
                             else if($node[@unit != '']) then string($node/@unit) 
                             else if($node[@type != '']) then string($node/@type)
                             else () 
                return 
                    if(matches($node/text(),'^\d')) then concat($unit,' ',$node/text())
                    else if(not($node/text()) and ($node/@to or $node/@from)) then  concat($unit,' ',$node/@from,' - ',$node/@to)
                    else $node/text()
            }
            case element(tei:category) return element ul {tei2html:tei2html($node/node())}
            case element(tei:catDesc) return element li {tei2html:tei2html($node/node())}
            case element(tei:foreign) return 
                <span dir="{if($node/@xml:lang = ('syr','ar','^syr')) then 'rtl' else 'ltr'}">{
                    (if($node/@xml:lang) then attribute lang { $node/@xml:lang } else (),
                    tei2html:tei2html($node/node()))
                }</span>        
            case element(tei:graphic) return
                tei2html:graphic($node)
            case element(tei:hi) return
                tei2html:hi($node)                
            case element(tei:i) return
                <i>{ tei2html:tei2html($node/node()) }</i>                
            case element(tei:l) return
                <span class="tei-l {if($node/@rend) then concat('tei-',$node/@rend) else ()}" id="{tei2html:get-id($node)}">{if($node/@n) then <span class="tei-line-number">{string($node/@n)}</span> else ()}{tei2html:tei2html($node/node())}</span>
            case element(tei:lb) return
                <br/>
            case element(tei:imprint) return 
            <span class="tei-{local-name($node)}" id="{tei2html:get-id($node)}">
            {
                    if($node//tei:pubPlace//text()) then $node//tei:pubPlace[1]//text() else (),
                    if($node//tei:pubPlace//text() and $node//tei:publisher//text()) then ': ' else (),
                    if($node//tei:publisher//text()) then $node//tei:publisher[1]//text() else (),
                    if(not($node//tei:pubPlace) and not($node//tei:publisher) and $node//tei:title[@level='m']) then <abbr title="no publisher">n.p.</abbr> else (),
                    if($node//tei:date/preceding-sibling::*) then ', ' else (),
                    if($node//tei:date) then $node//tei:date else <abbr title="no date of publication">n.d.</abbr>,
                    if($node/following-sibling::tei:biblScope[@unit='series']) then ', ' else (),
                    if($node//tei:extent/@type = "online") then (' ',<a href="{$node//tei:extent}" class="tei-extent-link"><span class="glyphicon glyphicon-book"></span> View </a>) else $node//tei:extent,
                    if($node//tei:note) then <span class="tei-note">{$node//tei:note}</span> else ()
            }</span>
            case element(tei:note) return 
                if($node/@target) then 
                    <span class="tei-{local-name($node)} footnote 
                        {(if($node/@type != '') then string($node/@type) else (), if($node/@place != '') then string($node/@place) else ())}">
                    {(
                    if($node/@xml:id) then 
                        (attribute id { $node/@xml:id }, <span class="tei-footnote-id">{string($node/@xml:id)}</span>)
                    else (),
                    tei2html:tei2html($node/node()) )}</span>
                else <span class="tei-{local-name($node)}">{ tei2html:tei2html($node/node()) }</span>
            case element(tei:pb) return 
                <span class="tei-pb">{string($node/@n)}</span>
            case element(tei:persName) return 
                <span class="tei-persName">{
                    if($node/child::*) then 
                        for $part in $node/child::*
                        order by $part/@sort ascending, string-join($part/descendant-or-self::text(),' ') descending
                        return tei2html:tei2html($part/node())
                    else tei2html:tei2html($node/node())
                }</span>
            case element(tei:ref) return
               tei2html:ref($node)    
            case element(tei:title) return 
                tei2html:title($node)
            case element(tei:p) return 
                <p xmlns="http://www.w3.org/1999/xhtml" id="{tei2html:get-id($node)}">{ tei2html:tei2html($node/node()) }</p>  (: THIS IS WHERE THE ANCHORS ARE INSERTED! :)
            case element(tei:rs) return (: create a new function for RSs to insert the content of specific variables; as is, content of the node is inserted as tooltip title. could use content of source attribute or link as the # ref :)
               <a href="#" data-toggle="tooltip" title="{tei2html:tei2html($node/node())}">{ tei2html:tei2html($node/node()) }</a>                
            case element(tei:seriesStmt) return 
                if($node/tei:idno[@type="coursepack"]) then () 
                else <span class="tei-{local-name($node)}">{ tei2html:tei2html($node/node()) }</span>
            case element(exist:match) return
                <span class="match" style="background-color:yellow;">{$node/text()}</span>
            case element() return
                <span class="tei-{local-name($node)}" id="{tei2html:get-id($node)}">{ tei2html:tei2html($node/node()) }</span>                
            default return tei2html:tei2html($node/node())
};

declare function tei2html:header($header as element(tei:teiHeader)) {
    let $titleStmt := $header//tei:titleStmt
    let $pubStmt := $header//tei:publicationStmt
    let $sourceDesc := $header//tei:sourceDesc
    let $authors := $header//tei:titleStmt/tei:author
    let $resps := $header//tei:respStmt
    let $imprints := $header//tei:sourceDesc/tei:imprint
    let $onlineImprints := $header//tei:sourceDesc/tei:imprint/tei:extent[@type="online"]
    let $publishers := $header//tei:sourceDesc/tei:imprint/tei:publisher

  (: link issue: works, but don't want it to display with @type=physical extent. need an or operator? or something else? :)
    return
        <div xmlns="http://www.w3.org/1999/xhtml" class="text-header">
            <h1>{$titleStmt/tei:title/text()}</h1>
            <h1><small>By 
            {
                let $author-full-names :=
                    for $author in $authors
                    return
                        concat($author//tei:forename, ' ', $author//tei:surname)
                let $name-count := count($authors)
                return
                    if ($name-count le 2) then
                        string-join($author-full-names, ' and ')
                    else
                        concat(
                            string-join(
                                $author-full-names[position() = (1 to last() - 1)]
                                , 
                                ', '),
                            ', and ',
                            $author-full-names[last()]
                        )
            }
            </small></h1><p></p>
        
            { 
                for $n in $resps
                return
                    <li class="list-unstyled">{concat($n/descendant::tei:resp, ' by ', string-join($n/descendant::tei:name,', '))}</li>
               
            }

    </div>
};

declare function tei2html:graphic($node as element (tei:graphic)) {
    <img xmlns="http://www.w3.org/1999/xhtml" class="tei-graphic">
        {attribute src { $node/@url },
        if($node/@width) then 
            attribute width { $node/@width }
        else (),
        if($node/@style) then 
            attribute style { $node/@style }
        else ()
        }
    </img>
};

declare function tei2html:hi($node as element (tei:hi)) {
    if($node/@rend='italic') then 
        <em>{tei2html:tei2html($node/node())}</em>  
    else if($node/@rend='bold') then 
        <strong>{tei2html:tei2html($node/node())}</strong>
    else if($node/@rend=('superscript','sup')) then 
        <sup>{tei2html:tei2html($node/node())}</sup>
    else if($node/@rend=('subscript','sub')) then         
        <sub>{tei2html:tei2html($node/node())}</sub>
    else <span class="tei-hi tei-{$node/@rend}">{tei2html:tei2html($node/node())}</span>
};

declare function tei2html:ref($node as element (tei:ref)) {
    if($node/@corresp) then 
      ($node, ' ', <sup class="tei-ref footnoteRef"><a href="#{string($node/@corresp)}" class="showFootnote">{string($node/@corresp)}</a></sup>)  
    else if(starts-with($node/@target,'http')) then 
        <a href="{$node/@target}">{tei2html:tei2html($node/node())}</a>
    else tei2html:tei2html($node/node())
};

declare function tei2html:title($node as element (tei:title)) {
    let $titleType := 
        if($node/@level='a') then 'title-analytic'
        else if($node/@level='m') then 'title-monographic'
        else if($node/@level='j') then 'title-journal'
        else if($node/@level='s') then 'title-series'
        else if($node/@level='u') then 'title-unpublished'
        else if($node/parent::tei:persName) then 'title-person'                             
        else ()
    return  
        <span class="tei-title {$titleType}" xmlns="http://www.w3.org/1999/xhtml">{
            (if($node/@xml:lang) then attribute lang { $node/@xml:lang } else (),
            tei2html:tei2html($node/node()))}</span>
};

declare %private function tei2html:get-id($node as element()) {
    if($node/@xml:id) then
        $node/@xml:id
    else if($node/@exist:id) then
        $node/@exist:id
    else generate-id($node)
};

(:
 : Used for short views of records, browse, search or related items display. 
:)
declare function tei2html:summary-view($nodes as node()*, $lang as xs:string?, $id as xs:string?) as item()* {
    let $title := $nodes/descendant-or-self::tei:title[1]      
    return 
        <div class="summary">
            <a href="{$config:nav-base}/work{substring-before(replace($id,$config:data-root,''),'.xml')}" dir="ltr">{tei2html:tei2html($title)}</a> 
            {if($nodes/descendant::tei:titleStmt/tei:author) then (' by ', tei2html:emit-responsible-persons($nodes/descendant::tei:titleStmt/tei:author,10))
            else ()}
            {if($nodes/descendant::tei:biblStruct) then 
                <span class="results-list-desc desc" dir="ltr" lang="en">
                    <label>Source: </label> {tei2html:citation($nodes/descendant::tei:teiHeader)}
                </span>
            else ()}
            {if($nodes/descendant-or-self::*[starts-with(@xml:id,'abstract')]) then 
                for $abstract in $nodes/descendant::*[starts-with(@xml:id,'abstract')]
                let $string := string-join($abstract/descendant-or-self::*/text(),' ')
                let $blurb := 
                    if(count(tokenize($string, '\W+')[. != '']) gt 25) then  
                        concat(string-join(for $w in tokenize($string, '\W+')[position() lt 25]
                        return $w,' '),'...')
                     else $string 
                return 
                    <span class="results-list-desc desc" dir="ltr" lang="en">{
                        if($abstract/descendant-or-self::tei:quote) then concat('"',normalize-space($blurb),'"')
                        else $blurb
                    }</span>
            else()}
            {
            if($id != '') then 
            <span class="results-list-desc uri"><span class="srp-label">URI: </span><a href="{$config:nav-base}/work{substring-before(replace($id,$config:data-root,''),'.xml')}">{$config:nav-base}/work{substring-before(replace($id,$config:data-root,''),'.xml')}</a></span>
            else()
            }
        </div>    
   
};

(:~
 : Select citation type based on child elements
:)
declare function tei2html:citation($nodes as node()*) {
    if($nodes/descendant::tei:monogr and not($nodes/descendant::tei:analytic)) then 
        tei2html:monograph($nodes/descendant::tei:monogr)
    else if($nodes/descendant::tei:analytic) then tei2html:analytic($nodes/descendant::tei:analytic)
    else tei2html:record($nodes/descendant-or-self::tei:teiHeader)
};

(:~
 : Output monograph citation
:)
declare function tei2html:record($nodes) {
    let $titleStmt := $nodes/descendant::tei:titleStmt
    let $persons :=  concat(tei2html:emit-responsible-persons($titleStmt/tei:editor[@role='creator'],3), 
                        if(count($titleStmt/tei:editor) gt 1) then ' (eds.), ' else ' (ed.), ')
    let $id := $nodes/descendant-or-self::tei:publicationStmt[1]/tei:idno[1]                         
    return 
        ($persons, '"',tei2html:tei2html($titleStmt/tei:title[1]),'" in ',tei2html:tei2html($titleStmt/tei:title[@level='m'][1]),' last modified ',
        for $d in $nodes/descendant-or-self::tei:publicationStmt/tei:date[1] return if($d castable as xs:date) then format-date(xs:date($d), '[MNn] [D], [Y]') else string($d),', ',replace($id[1],'/tei','')) 
};

(:~
 : Output monograph citation
:)
declare function tei2html:monograph($nodes as node()*) {
    let $persons := if($nodes/tei:author) then 
                        concat(tei2html:emit-responsible-persons($nodes/tei:author,3),', ')
                    else if($nodes/tei:editor[not(@role) or @role!='translator']) then 
                        (tei2html:emit-responsible-persons($nodes/tei:editor[not(@role) or @role!='translator'],3), 
                        if(count($nodes/tei:editor[not(@role) or @role!='translator']) gt 1) then ' eds., ' else ' ed., ')
                    else ()
    return (
            if(deep-equal($nodes/tei:editor | $nodes/tei:author, $nodes/preceding-sibling::tei:monogr/tei:editor | $nodes/preceding-sibling::tei:monogr/tei:author )) then () else $persons, 
            tei2html:tei2html($nodes/tei:title[1]),
            if(count($nodes/tei:editor[@role='translator']) gt 0) then (tei2html:emit-responsible-persons($nodes/tei:editor[@role!='translator'],3),', trans. ') else (),
            if($nodes/tei:edition) then 
                concat(', ', $nodes/tei:edition[1]/text(),' ')
            else (),
            if($nodes/tei:biblScope[@unit='vol']) then
                concat(' ',tei2html:tei2html($nodes/tei:biblScope[@unit='vol']),' ')
            else (),
            if($nodes/following-sibling::tei:series) then tei2html:series($nodes/following-sibling::tei:series)
            else if($nodes/following-sibling::tei:monogr) then ', '
            else if($nodes/preceding-sibling::tei:monogr and $nodes/preceding-sibling::tei:monogr/tei:imprint[child::*[string-length(.) gt 0]]) then   
            (' (', $nodes/preceding-sibling::tei:monogr/tei:imprint,')')
            else if($nodes/tei:imprint[child::*[string-length(.) gt 0]]) then 
                concat(' (',tei2html:tei2html($nodes/tei:imprint[child::*[string-length(.) gt 0]][1]),')', 
                if($nodes/following-sibling::tei:monogr) then ', ' else() )
            else ()
        )
};

(:~
 : Output series citation
:)
declare function tei2html:series($nodes as node()*) {(
    if($nodes/preceding-sibling::tei:monogr/tei:title[@level='j']) then ' (=' 
    else if($nodes/preceding-sibling::tei:series) then '; '
    else ', ',
    if($nodes/tei:title) then tei2html:tei2html($nodes/tei:title[1]) else (),
    if($nodes/tei:biblScope) then 
        (',', 
        for $r in $nodes/tei:biblScope[@unit='series'] | $nodes/tei:biblScope[@unit='vol'] | $nodes/tei:biblScope[@unit='tomus']
        return (tei2html:tei2html($r), if($r[position() != last()]) then ',' else ())) 
    else (),
    if($nodes/preceding-sibling::tei:monogr/tei:title[@level='j']) then ')' else (),
    if($nodes/preceding-sibling::tei:monogr/tei:imprint and not($nodes/following-sibling::tei:series)) then 
        (' (',tei2html:tei2html($nodes/preceding-sibling::tei:monogr/tei:imprint),')')
    else ()
)};

(:~
 : Output analytic citation
:)
declare function tei2html:analytic($nodes as node()*) {
    let $persons := if($nodes/tei:author) then 
                        concat(tei2html:emit-responsible-persons($nodes/tei:author,3),', ')
                    else if($nodes/tei:editor[not(@role) or @role!='translator']) then 
                        (tei2html:emit-responsible-persons($nodes/tei:editor[not(@role) or @role!='translator'],3), 
                        if(count($nodes/tei:editor[not(@role) or @role!='translator']) gt 1) then ' eds., ' else ' ed., ')
                    else 'No authors or Editors'
    return (
            $persons, 
            concat('"',tei2html:tei2html($nodes/tei:title[1]),if(not(ends-with($nodes/tei:title[1][starts-with(@xml:lang,'en')][1],'.|:|,'))) then '.' else (),'"'),            
            if(count($nodes/tei:editor[@role='translator']) gt 0) then (tei2html:emit-responsible-persons($nodes/tei:editor[@role!='translator'],3),', trans. ') else (),
            if($nodes/following-sibling::tei:monogr/tei:title[1][@level='m']) then 'in' else(),
            if($nodes/following-sibling::tei:monogr) then tei2html:monograph($nodes/following-sibling::tei:monogr) else()
        )
};

(:~
 : Output authors/editors
:)
declare function tei2html:emit-responsible-persons($nodes as node()*, $num as xs:integer?) {
    let $persons := 
        let $limit := if($num) then $num else 3
        let $count := count($nodes)
        return 
            if($count = 1) then 
                tei2html:person($nodes)  
            (:
            else if($count gt $num) then
                (for $n in subsequence($nodes, 1, $num)
                return normalize-space(tei2html:person($nodes)), ' et al.')
            :)                
            else if($count = 2) then
                (tei2html:person($nodes[1]),' and ',tei2html:person($nodes[2]))            
            else 
                for $n at $p in subsequence($nodes, 1, $num)
                return 
                    if($p = ($num - 1)) then 
                        (normalize-space(tei2html:person($n)), ' and ')
                    else concat(normalize-space(tei2html:person($n)),', ')
    return replace(string-join($persons),'\s+$','')                    
};

(:~
 : Output authors/editors child elements. 
:)
declare function tei2html:person($nodes as node()*) {
    if($nodes/descendant::tei:forename) then 
        concat($nodes/descendant::tei:forename,' ',$nodes/descendant::tei:surname)
    else string-join($nodes/descendant::text(),' ')
};

(:~ 
 : Reworked  KWIC to be more 'Google like' 
 : Passes content through  tei2html:kwic-format() to output only text and matches 
 : Note: could be made more robust to match proximity operator, it it is greater the 10 it may be an issue.
 : To do, pass search params to record, highlight hits in record 
   let $search-params := 
        string-join(
            for $param in request:get-parameter-names()
            return 
                if($param = ('fq','start')) then ()
                else if(request:get-parameter($param, '') = ' ') then ()
                else concat('&amp;',$param, '=',request:get-parameter($param, '')),'')
:)
declare function tei2html:output-kwic($nodes as node()*, $id as xs:string*){
    let $results := <results xmlns="http://www.w3.org/1999/xhtml">{tei2html:kwic-format($nodes)}</results>
    let $count := count($results//*:match)
    for $node at $p in subsequence($results//*:match,1,8)
    let $prev := $node/preceding-sibling::text()[1]
    let $next := $node/following-sibling::text()[1]
    let $prevString := 
        if(string-length($prev) gt 60) then 
            concat(' ...',substring($prev,string-length($prev) - 100, 100))
        else $prev
    let $nextString := 
        if(string-length($next) lt 100 ) then () 
        else concat(substring($next,1,100),'... ')        
    let $link := concat($config:nav-base,'/work',substring-before(replace($id,$config:data-root,''),'.xml'),'#',string($node/@id))
    (:concat($config:nav-base,'/',tokenize($id,'/')[last()],'#',$node/@n):)
    return 
        <span>{$prevString}&#160;<span class="match"><a href="{$link}">{$node/text()}</a></span>&#160;{$nextString}</span>
};

(:~
 : Strips results to just text and matches. 
 : Note, could pass though tei2html:tei2html() to hide hidden content (choice/orig)
:)
declare function tei2html:kwic-format($nodes as node()*){
    for $node in $nodes
    return 
        typeswitch($node)
            case text() return $node
            case comment() return ()
            case element(exist:match) return 
                <match xmlns="http://www.w3.org/1999/xhtml" id="{tei2html:get-id($node)}">
                    { $node/node() }
                </match>
            default return tei2html:kwic-format($node/node())                
};