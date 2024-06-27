xquery version "3.0";
(:~
 : Builds tei conversions. 
 : Used by oai, can be plugged into other outputs as well.
 :)
 
module namespace tei2html="http://syriaca.org/tei2html";
import module namespace config="http://LiC.org/apps/config" at "../config.xqm";
import module namespace data="http://LiC.org/apps/data" at "../lib/data.xqm";

declare namespace html="http://purl.org/dc/elements/1.1/";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xlink = "http://www.w3.org/1999/xlink";
declare namespace util="http://exist-db.org/xquery/util";
(:declare boundary-space preserve;:)

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
            case element(tei:castList) return 
                <div class="tei-castList">{(
                    if($node/tei:head) then
                       tei2html:tei2html($node/tei:head)
                    else (),
                    element dl {tei2html:tei2html($node/tei:castItem)})}</div>
            case element(tei:castItem) return
                if($node/tei:role) then
                  (<dt class="tei-castItem">{tei2html:tei2html($node/tei:actor)}</dt>,
                     <dd class="castItem">{tei2html:tei2html($node/tei:role)}</dd>,
                     <dd class="castItem">{tei2html:tei2html($node/tei:roleDesc)}</dd>)  
                else <dt class="tei-castItem">{tei2html:tei2html($node/node())}</dt>
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
            case element(tei:head) return
                <span class="tei-head {(if($node/@title) then ' tei-head-title' else (),if($node/@subtitle) then ' tei-head-subtitle' else ())}">{tei2html:tei2html($node/node())}</span>    
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
                    if($node//tei:note) then 
                        if($node//tei:note[@type="sidenote"]) then 
                            <span class="tei-note tei-sidenote">{tei2html:tei2html($node//tei:note)}</span>
                        else <span class="tei-note">{tei2html:tei2html($node//tei:note)}</span> 
                   else ()
            }</span>
            case element(tei:note) return 
                if($node/@target) then 
                    <span class="tei-{local-name($node)} footnote 
                        {(
                            if($node/@type != '') then string($node/@type) 
                            else (), 
                            if($node/@place != '') then string($node/@place) 
                            else (),
                            if($node/@type="sidenote") then 'tei-sidenote'
                            else ())}">
                    {(
                    if($node/@xml:id) then 
                       <span class="tei-footnote-id {if($node/@type="sidenote") then 'tei-sidenote' else ()}" id="{ string($node/@xml:id) }">{string($node/@xml:id)}</span>
                    else (),
                    <span>{tei2html:tei2html($node/node())}</span>,
                    if($node/descendant::tei:ref[contains(@target,'youtube')]) then 
                        tei2html:youTube($node/descendant::tei:ref[contains(@target,'youtube')])
                    else (),
                    if($node/@resp) then
                        <span class="tei-resp"> - [<a href="{$config:nav-base}/contributors.html?contributorID={substring-after($node/@resp,'#')}">{substring-after($node/@resp,'#')}</a>]</span>
                    else ()
                    )}</span>
                else <span class="tei-{local-name($node)} {if($node/@type="sidenote") then ' tei-sidenote' else ()}">{( tei2html:tei2html($node/node()),
                    if($node/descendant::tei:ref[contains(@target,'youtube')]) then 
                        tei2html:youTube($node/descendant::tei:ref[contains(@target,'youtube')])
                    else ())
                    }</span>
            case element(tei:pb) return 
                    <span class="tei-pb" data-num="{string($node/@n)}">{string($node/@n)}</span>
            case element(tei:persName) return 
                tei2html:persName($node)
            case element(tei:ref) return
               tei2html:ref($node)    
            case element(tei:title) return 
                tei2html:title($node)
            case element(tei:text) return 
                if($node/descendant::tei:pb[@facs] and request:get-parameter('view', '') = 'pageImages') then
                    tei2html:page-chunk($node)
                else tei2html:tei2html($node/node()) 
            case element(tei:p) return 
                if($node/ancestor::tei:note[@target]) then 
                    <span class="tei-p" xmlns="http://www.w3.org/1999/xhtml" id="{tei2html:get-id($node)}">{ tei2html:tei2html($node/node()) }</span>  (: THIS IS WHERE THE ANCHORS ARE INSERTED! :)
                else <p xmlns="http://www.w3.org/1999/xhtml" id="{tei2html:get-id($node)}">{ tei2html:tei2html($node/node()) }</p>  (: THIS IS WHERE THE ANCHORS ARE INSERTED! :)
            case element(tei:rs) return (: create a new function for RSs to insert the content of specific variables; as is, content of the node is inserted as tooltip title. could use content of source attribute or link as the # ref :)
               <a href="#" data-toggle="tooltip" title="{tei2html:tei2html($node/node())}">{ tei2html:tei2html($node/node()) }</a>                
            case element(tei:sp) return 
                <div class="row tei-sp">
                    <div class="col-md-3">{tei2html:tei2html($node/tei:speaker)}</div>
                    <div class="col-md-9">{tei2html:tei2html($node/tei:l)}</div>
                </div>
            case element(tei:seriesStmt) return 
                if($node/tei:idno[@type="coursepack"]) then () 
                else <span class="tei-{local-name($node)}">{ tei2html:tei2html($node/node()) }</span>
            case element(exist:match) return
                <span class="match" style="background-color:yellow;">{$node/text()}</span>
            case element() return
                <span class="tei-{local-name($node)} {if($node/@n) then ' tei-n' else ()}" id="{tei2html:get-id($node)}">{ tei2html:tei2html($node/node()) }</span>                
            default return tei2html:tei2html($node/node())
};

(:
 : Testing Lazy load here: 
 : 
:)
declare function tei2html:page-chunk($nodes as node()*){  
    let $pages := $nodes/descendant::tei:pb
    let $workID := substring-before(replace(document-uri(root($nodes)),$config:data-root,''),'.xml')
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
                (<div class="hidden">{tei2html:tei2html($nodes//tei:note)}</div>,
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
                                           <a href="{$src}"><img src="{$src}" width="100%" alt="Page {string($image/@n)}"/></a>
                                           <span class="caption">Page {string($image/@n)}</span>
                                      </span>
                         else ()
                     }</div>
                 </div>)
    return 
    (<script type="text/javascript" src="{$config:nav-base}/resources/js/lazyload.js"/>,$firstPage,
    for $pb at $i in subsequence($pages, 2, $count)
    return
        <div class="lazyLoad lazyContent" data-src="{$config:nav-base}/modules/data.xql" data-page="{$i+1}" data-work="{$workID}"></div>
     )
};

(: for loading specific pages :)
declare function tei2html:get-page($nodes as node()*, $page as item()*){  
    let $pages := $nodes/descendant::tei:pb
    let $workID := substring-before(replace(document-uri(root($nodes)),$config:data-root,''),'.xml')
    let $page := if($page castable as xs:integer) then xs:integer($page) else 0
    for $current in $pages[$page]
    let $ms1 := $current
    let $ms2 := if($current/following::tei:pb) then $current/following::tei:pb[1] else ()(:($nodes//element())[last()]:) 
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
                <div class="tei-page-chunk row" n="{string($current/@n)}" ms1="{string($ms1/@n)}" ms2="{string($ms2/@n)}">
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
};

(: end chunk functions :)
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
            <h1>{$titleStmt/tei:title/text()} <br/>
            <small>By 
            {
                let $author-full-names :=
                    for $author in $authors//tei:name
                    return tei2html:persName($author)
                let $name-count := count($author-full-names)
                return 
                    if ($name-count eq 1) then
                        $author-full-names
                    else if ($name-count eq 2) then
                        concat($author-full-names[1], ' and ',$author-full-names[last()])    
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
            </small></h1>
            { 
            if($resps != '' and not(contains(document-uri(root($header)),'/data/headnotes'))) then 
                <div>{string-join(
                for $n in $resps
                for $resp in $n/descendant::tei:resp
                let $names := $resp/following-sibling::tei:name[preceding-sibling::tei:resp]
                return concat($resp, ' by ', string-join($names,', '))
                ,'. ')}</div>
              else() 
            }

    </div>
};

(: tei persName display first name/last name/add name :)
declare function tei2html:persName($nodes as node()*) {
let $name := 
    if($nodes/descendant-or-self::tei:name) then $nodes/descendant-or-self::tei:name
    else if($nodes/descendant-or-self::tei:persName) then $nodes/descendant-or-self::tei:persName 
    else $nodes
return 
    <span class="tei-persName">{
        if($name/@reg) then string($name/@reg)
        else if($name/child::*) then 
            (
            let $last := count($name/child::*[not(self::tei:addName)]) 
            for $part at $i in $name/child::*[not(self::tei:addName)]
             order by $part/@sort ascending, string-join($part/descendant-or-self::text(),' ') descending
             return (tei2html:tei2html($part/node()), if ($i != $last) then ' ' else ()),
             if($name/tei:addName) then (', ',tei2html:tei2html($name/tei:addName)) else ())
        else tei2html:tei2html($name/node())
    }</span> 
};

(: tei persName display last name/first name/add name:)
declare function tei2html:persName-last-first($nodes as node()*) {
let $name := 
    if($nodes/descendant-or-self::tei:name) then $nodes/descendant-or-self::tei:name[1]
    else if($nodes/descendant-or-self::tei:persName) then $nodes/descendant-or-self::tei:persName[1] 
    else $nodes
return 
    <span class="tei-persName">{
      if($name/child::*) then
        let $formatedName := 
            (
            normalize-space($name/descendant-or-self::tei:surname[1]),', ',normalize-space($name/descendant-or-self::tei:forename[1]), 
            if($name/descendant-or-self::tei:addName) then 
                for $addName in $name/descendant-or-self::tei:addName
                return (', ',tei2html:tei2html($addName)) 
            else ()
            )
        return replace(normalize-space(string-join($formatedName,'')),' , ',', ')    
      else tei2html:tei2html($name/node())
    }</span>
};

declare function tei2html:graphic($node as element (tei:graphic)) {
let $id := string(root($node)/tei:TEI/@xml:id)
let $imgURL :=  if($node/@url) then 
                    if(starts-with($node/@url,'https://') or starts-with($node/@url,'http://')) then
                        string($node/@url)
                   else if(starts-with($node/@url,'/')) then 
                        concat($config:image-root,$id,string($node/@url))
                   else concat($config:image-root,$id,'/',string($node/@url))
                else () 
let $alt :=    if($node/@alt) then string($node/@alt) else if($node/@title) then $node/@title else 'graphic'
let $type := if(ends-with($imgURL,'.mp3')) then 'audio' 
             else 'image'
return 
    if($imgURL) then
        if($type = 'audio') then 
            <div class="audio">
                <audio controls="controls">
                  <source src="{$imgURL}" type="audio/mpeg"/>
                </audio>
            </div>   
        else 
            <span class="graphic">{
                (<a href="{$imgURL}">
                    <img xmlns="http://www.w3.org/1999/xhtml" class="tei-graphic">{(
                    attribute src { $imgURL },
                    attribute alt { $alt },
                    attribute title { $alt },
                    if($node/@width) then 
                        attribute width { $node/@width }
                    else (),
                    if($node/@style) then 
                        attribute style { $node/@style }
                    else ()
                    )}</img>
                </a>,
                    if($node/@desc or $node/@source) then 
                        <span class="imgCaption">
                        {
                            if($node/@source) then 
                              <span class="imgSource">Source: <a href="{$node/@source}">{if($node/@desc) then string($node/@desc) else string($node/@source) }</a></span>  
                            else ()
                        }
                        </span>
                    else ())}
            </span>   
    else ()               
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

declare function tei2html:youTube($node as element (tei:ref)) {
    <div class="embedVideo graphic" xmlns="http://www.w3.org/1999/xhtml">
        {let $videoID := substring-after($node/@target,'v=')
         let $embedURL := concat('https://www.youtube.com/embed/',$videoID)
         return 
         (: Does not work for youtub, but may work for plain mp4 files 
            <video width="320" height="240" controls="controls">
              <source src="{$embedURL}" type="video/mp4"/>
            </video>
         :)
            (
            <br/>,
            <iframe src="{$embedURL}" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" width="560" height="315"></iframe>,
             <br/>,
             <a href="{$node/@target}">{if($node[. != '']) then $node/text() else string($node/@target)}</a>
             )
             
        }
    </div>
};
declare function tei2html:ref($node as element (tei:ref)) {
    if($node/@corresp) then
        <span class="footnoteRef text">
            <a href="#{string($node/@corresp)}" class="showFootnote">{tei2html:tei2html($node/node())}</a>
            <sup class="tei-ref footnoteRef show-print">{string($node/@corresp)}</sup>
        </span>
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

declare function tei2html:annotations($node as node()*) { 
    <span class="tei-annotation-show" xmlns="http://www.w3.org/1999/xhtml">{
        (if($node/@xml:lang) then attribute lang { $node/@xml:lang } else (),
        tei2html:tei2html($node/node()))}</span>
};

declare %private function tei2html:get-id($node as element()) {
   (: if($node/@xml:id) then
        string($node/@xml:id)
    else if($node/@exist:id) then
        string($node/@exist:id)
    else if($node/@id) then
        string($node/@id)     
    else util:node-id($node)
    :)concat('nodeID',substring(string(util:node-id($node)),2))
};

(:
 : Used for short views of records, browse, search or related items display. 
:)
declare function tei2html:summary-view($nodes as node()*, $lang as xs:string?, $id as xs:string?) as item()* {
    let $title := $nodes/descendant-or-self::tei:title[1]      
    return 
        <span class="summary">
        {if(contains($id,'/headnotes')) then <strong>Headnote: </strong> else()}
            <a href="{$config:nav-base}/work{substring-before(replace($id,$config:data-root,''),'.xml')}" dir="ltr">{tei2html:tei2html($title)}</a> 
            {if($nodes/descendant::tei:titleStmt/tei:author//tei:name) then 
                (' by ', tei2html:emit-responsible-persons($nodes/descendant::tei:titleStmt//tei:author//tei:name,10))
             else if($nodes/descendant::tei:titleStmt/tei:author) then
                (' by ', tei2html:emit-responsible-persons($nodes/descendant::tei:titleStmt//tei:author,10))
            else ()}
            {if($nodes/descendant::tei:biblStruct) then 
                <span class="results-list-desc desc" dir="ltr" lang="en">
                    <strong>Source: </strong> 
                    { let $monograph := $nodes/descendant::tei:sourceDesc[1]/descendant::tei:monogr[1]
                      return 
                        (tei2html:tei2html($monograph/tei:title),
                        if($monograph/tei:imprint) then 
                          concat(' (',
                           normalize-space(string($monograph/tei:imprint[1]/tei:pubPlace[1])),
                           if($monograph/tei:imprint/tei:publisher) then 
                            concat(': ', normalize-space(string($monograph/tei:imprint[1]/tei:publisher[1])))
                           else (),
                           if($monograph/tei:imprint/tei:date) then 
                            concat(', ', normalize-space(string($monograph/tei:imprint[1]/tei:date[1])))
                           else ()
                           ,') ')
                        else ())
                        }
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
            {(:
            if($id != '') then 
            <span class="results-list-desc uri"><span class="srp-label">URI: </span><a href="{$config:nav-base}/work{substring-before(replace($id,$config:data-root,''),'.xml')}">{$config:nav-base}/work{substring-before(replace($id,$config:data-root,''),'.xml')}</a></span>
            else()
            :)''}
        </span>    
   
};


(: Embed COinS into HTML :)
declare function tei2html:COinS($nodes as node()*){
    let $source := $nodes/descendant-or-self::tei:sourceDesc
    let $constants := concat('url_ver=Z39.88-2004&amp;ctx_ver=Z39.88-2004&amp;rfr_id=',
                    encode-for-uri('info:sid/anthology.lib.virginia.edu:work'),
                    '&amp;rft_val_fmt=', encode-for-uri('info:ofi/fmt:kev:mtx:book'))
    let $root := root($source)
    let $id := if($root/@xml:id) then
                    string($root/@xml:id)
                else if($root/@exist:id) then
                    string($root/@exist:id)
                else generate-id($root)
    let $idURI := concat('&amp;rft_id=',$id)                
    let $genre := '&amp;rft.genre=book'
    let $title :=  for $t in $source/descendant::tei:analytic/tei:title | $source/tei:monogr/tei:title
                   return concat('&amp;rft.title=',encode-for-uri(normalize-space(string-join($t,''))))
    let $author := for $a at $i in $source/descendant::tei:monogr/tei:author
                   return 
                        if($i = 1 and $a/tei:forename) then
                            concat('&amp;rft.aulast=', encode-for-uri(normalize-space(string-join($a/tei:surname,' '))),
                            '&amp;rft.aufirst=', encode-for-uri(normalize-space(string-join($a/tei:forename,' '))))
                        else concat('&amp;rft.au=', encode-for-uri(normalize-space(string-join($a,' '))))
    let $publisher := for $p in $source/descendant::tei:imprint[1]/tei:publisher[1]
                      return concat('&amp;rft.publisher=', encode-for-uri(normalize-space(string-join($p,''))))                      
    let $place := for $p in $source/descendant::tei:imprint[1]/tei:pubPlace[1]   
                  return concat('&amp;rft.publisher=', encode-for-uri(normalize-space(string-join($p))))
    let $date :=  for $d in $source/descendant::tei:imprint[1]/tei:date[1]   
                  return concat('&amp;rft.date=', encode-for-uri(normalize-space(string-join($d,' '))))
    let $pages := for $page in $source/descendant::tei:biblScope
                  return concat('&amp;rft.tpages=',encode-for-uri(normalize-space(string-join($page,' '))))                  
    let $citation := 
        concat($constants,$idURI,$genre,
            string-join($title,''),
            string-join($author,''),
            string-join($publisher,''),
            string-join($place,''),
            string-join($date,''),
            string-join($pages,''))
    return <span xmlns="http://www.w3.org/1999/xhtml" class="Z3988" title="{$citation}"><!-- --></span>
};

(:~
 : Select citation type based on child elements
:)
declare function tei2html:citation($nodes as node()*) {
    let $persons :=     if($nodes/descendant::tei:author) then 
                            tei2html:emit-responsible-persons($nodes/descendant::tei:author,20)
                        else if($nodes/descendant::tei:editor[not(@role) or @role!='translator']) then 
                            (tei2html:emit-responsible-persons($nodes/tei:editor[not(@role) or @role!='translator'],20), 
                            if(count($nodes/descendant::tei:editor[not(@role) or @role!='translator']) gt 1) then ' eds., ' else ' ed., ')
                        else ()
    let $analytic := if($nodes/descendant::tei:analytic/tei:title) then
                        if(starts-with($nodes/descendant::tei:analytic/tei:title,'"')) then
                           $nodes/descendant::tei:analytic/tei:title/text()
                        else concat('"',$nodes/descendant::tei:analytic/tei:title,'" ')
                     else()
    let $monograph := if($nodes/descendant::tei:monogr/tei:title) then
                        if($nodes/descendant::tei:monogr/tei:title[@type="sub"]) then 
                           concat($nodes/descendant::tei:monogr/tei:title[@type='main'],'; ',$nodes/descendant::tei:monogr/tei:title[@type="sub"])
                        else $nodes/descendant::tei:monogr/tei:title/text()
                     else() 
    let $imprint := if($nodes/descendant::tei:monogr/descendant::tei:imprint) then
                        (if($nodes/descendant::tei:monogr/descendant::tei:imprint[1]/descendant::tei:publisher[1]) then 
                            $nodes/descendant::tei:monogr/descendant::tei:imprint[1]/descendant::tei:publisher[1]/text()
                        else (),
                        if($nodes/descendant::tei:monogr/descendant::tei:imprint[1]/descendant::tei:date[1]) then
                            concat(', ',$nodes/descendant::tei:monogr/descendant::tei:imprint[1]/descendant::tei:date[1]/text())
                        else ()
                        )
                    else ()
    let $biblScope :=  if($nodes/descendant::tei:biblScope) then 
                            $nodes/descendant::tei:biblScope/text() 
                       else()                   
    return 
    <span class="citation">{
        (if($persons != '') then concat(string-join($persons,''),'. ') else (),
        if($analytic != '') then <span class="title-analytic">{$analytic}</span> else (),
        if($analytic != '') then '. ' else(),
        if($monograph != '') then <span class="title-monograph"> {$monograph}</span> else (),
        if($imprint != '') then concat(', ',string-join($imprint,'')) else (),
        if($biblScope != '') then concat(', ',string-join($biblScope,'')) else (),
        if($analytic != '' or $monograph != '' or $imprint != '' or $biblScope != '') then '. ' 
        else concat('"',$nodes/descendant::tei:title[1],'." '))
        }
        <em> Literature in Context: An Open Anthology. </em>
        {concat(request:get-url(),'. ', 'Accessed: ', current-dateTime())}
    </span>
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
                        concat(tei2html:emit-responsible-persons($nodes/tei:author,20),', ')
                    else if($nodes/tei:editor[not(@role) or @role!='translator']) then 
                        (tei2html:emit-responsible-persons($nodes/tei:editor[not(@role) or @role!='translator'],20), 
                        if(count($nodes/tei:editor[not(@role) or @role!='translator']) gt 1) then ' eds., ' else ' ed., ')
                    else ()
    return (
            $persons, concat('"',tei2html:tei2html($nodes/tei:title[1]),if(not(ends-with($nodes/tei:title[1][starts-with(@xml:lang,'en')][1],'.|:|,'))) then '.' else (),'"'),            
            if(count($nodes/tei:editor[@role='translator']) gt 0) then (tei2html:emit-responsible-persons($nodes/tei:editor[@role!='translator'],3),', trans. ') else (),
            if($nodes/following-sibling::tei:monogr/tei:title[1][@level='m']) then 'in' else(),
            if($nodes/following-sibling::tei:monogr) then tei2html:monograph($nodes/following-sibling::tei:monogr) else())
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
            else if($count = 2) then
                (tei2html:person($nodes[1]),' and ',string-join($nodes[2], ' '))            
            else 
                for $n at $p in subsequence($nodes, 1, $num)
                return 
                    if($p = ($num - 1)) then 
                        (normalize-space(tei2html:person($n)), ' and ')
                    else concat(normalize-space(string-join($nodes[2], ' ')),', ')
    return replace(string-join($persons),'\s+$','')                    
};

(:~
 : Output authors/editors child elements. 
:)
declare function tei2html:person($nodes as node()*) {
    tei2html:persName-last-first($nodes)
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
    let $results := $nodes
    for $node at $p in subsequence($results//*:match,1,5)
    let $prev := $node/preceding-sibling::text()[1]
    let $next := $node/following-sibling::text()[1]
    let $prevString := 
        if(string-length($prev) gt 60) then 
            concat(' ...',substring($prev,string-length($prev) - 100, 100))
        else $prev
    let $nextString := 
        if(string-length($next) lt 100 ) then () 
        else concat(substring($next,1,100),'... ')  
    
    (:let $searchID := tei2html:get-id($node/parent::*[1]/parent::*[1])
    let $workPath := concat($config:nav-base,'/work',substring-before(replace($id,$config:data-root,''),'.xml'))
    let $link := concat($workPath,'?searchTerm=',$node/text())
    :)
    return 
        <span>{$prevString}&#160;<span class="match">{$node/text()}</span>&#160;{$nextString}</span>
     (: <span>{$prevString}&#160;<span class="match"><a href="{$link}">{$node/text()}</a></span>&#160;{$nextString}</span>:)
};

(:~
 : Strips results to just text and matches. 
 : Note, could pass though tei2html:tei2html() to hide hidden content (choice/orig)
:)
(:
declare function tei2html:kwic-format($nodes as node()*){
    for $node in $nodes
    return 
        typeswitch($node)
            case text() return $node
            case comment() return ()
            case element(exist:match) return 
                <match xmlns="http://www.w3.org/1999/xhtml" id="{tei2html:get-id($node/parent::element()[1])}">
                    { $node/node() }
                </match>
            default return tei2html:kwic-format($node/node())                
};
:)