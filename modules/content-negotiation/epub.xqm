xquery version "3.0";
(:~
    A module for generating an EPUB file out of a TEI document.
    
    Largely based on code written by Joe Wicentowski.
    
    @version 0.1
    
    @see http://en.wikipedia.org/wiki/EPUB
    @see http://www.ibm.com/developerworks/edu/x-dw-x-epubtut.html
    @see http://code.google.com/p/epubcheck/
:)  


module namespace epub = "http://exist-db.org/xquery/epub";

import module namespace compression = "http://exist-db.org/xquery/compression";
import module namespace config="http://LiC.org/config" at "../config.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "tei2html.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function epub:epub($id as xs:string, $work as item()*) {
    epub:generate-epub($id, $work) 
};

declare function epub:generate-epub($id as xs:string, $work as item()*){
   let $fileDesc := $work//tei:teiHeader/tei:fileDesc
   let $title := normalize-space(string-join($fileDesc//tei:titleStmt/tei:title[1]/string(),' '))
   let $creator := normalize-space(string-join($fileDesc/tei:titleStmt/tei:author[1]/string(),' '))
   let $urn := document-uri($work)
   let $xhtml := epub:body-xhtml-entries($id, $work, $title, $creator, $urn)
   let $css := ($config:app-root || "/resources/css/epub.css")
   let $entries :=
        (
            epub:mimetype-entry(),
            epub:container-entry(),
            epub:content-opf-entry($id, $work, $title, $creator, $urn),
            epub:title-xhtml-entry($id, $work, $title, $creator, $urn),
            epub:stylesheet-entry($css),
            epub:toc-ncx-entry($id, $work, $title, $creator, $urn),
            epub:nav-entry($id, $work, $title, $creator, $urn),
            $xhtml
        )
    return
        $entries  
};

declare function epub:mimetype-entry() {
    <entry name="mimetype" type="text" method="store">application/epub+zip</entry>
};

declare function epub:container-entry() {
    let $container :=
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
            <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
            </rootfiles>
        </container>
    return
        <entry name="META-INF/container.xml" type="xml">{$container}</entry>
};

declare function epub:content-opf-entry($id as xs:string, $work as item()*, $title, $creator, $urn) {
    let $entries :=
        if(count($work/descendant::tei:text/tei:body/tei:div) gt 1) then
                for $div at $p in $work/descendant::tei:text/tei:front | $work/descendant::tei:text/tei:body/tei:div | $work/descendant::tei:text/tei:back
                let $head := if($div/descendant::tei:head[1]) then $div/descendant::tei:head[1] else if($div/ancestor-or-self::tei:front) then 'Front Matter' else if($div/ancestor-or-self::tei:back) then 'Back Matter'  else concat('Section ', $p)
                let $h-id := concat('n',$p)
                return 
                    <item xmlns="http://www.idpf.org/2007/opf" id="{$h-id}" href="{$h-id}.xhtml" media-type="application/xhtml+xml"/>
        else <item xmlns="http://www.idpf.org/2007/opf" id="n1" href="n1.xhtml" media-type="application/xhtml+xml"/>
    let $refs :=
        if(count($work/descendant::tei:text/tei:body/tei:div) gt 1) then
                for $div at $p in $work/descendant::tei:text/tei:front | $work/descendant::tei:text/tei:body/tei:div | $work/descendant::tei:text/tei:back
                let $head := if($div/descendant::tei:head[1]) then $div/descendant::tei:head[1] else if($div/ancestor-or-self::tei:front) then 'Front Matter' else if($div/ancestor-or-self::tei:back) then 'Back Matter'  else concat('Section ', $p)
                let $h-id := concat('n',$p)
                return 
                    <itemref xmlns="http://www.idpf.org/2007/opf" idref="{$h-id}"/>
        else <itemref xmlns="http://www.idpf.org/2007/opf" idref="n1"/>
    let $content-opf :=
        <package xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid" version="3.0">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:title>{$title}</dc:title>
                <dc:creator>{$creator}</dc:creator>
                <dc:identifier id="bookid">{$urn}</dc:identifier>
            </metadata>
            <manifest>
                <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
                <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
                <item id="title-page" href="title-page.xhtml" media-type="application/xhtml+xml"/>
                <item id="publication-page" href="publication-page.xhtml" media-type="application/xhtml+xml"/>
                {
                    $entries
                }
                <item id="css" href="stylesheet.css" media-type="text/css"/>
            </manifest>
            <spine toc="ncx">
                <itemref idref="title-page"/>
                <itemref idref="publication-page"/>
                {
                    $refs
                }
            </spine>
        </package>
    return
        <entry name="OEBPS/content.opf" type="xml">{$content-opf}</entry>
};

declare function epub:title-xhtml-entry($id, $work, $title, $creator, $urn) {
    let $title-xhtml := 
        <html xmlns="http://www.w3.org/1999/xhtml">
             <head>
                 <title>Title Page</title>
                 <link type="text/css" rel="stylesheet" href="stylesheet.css"/>
             </head>
             <body>
                 <div xmlns="http://www.w3.org/1999/xhtml" id="title">
                    <h1>{ $work/descendant::tei:titleStmt/tei:title/string()}</h1>
                    <h2 class="author">{ $work/descendant::tei:titleStmt/tei:author/string() }</h2>
                    {
                        for $resp in $work/descendant::tei:titleStmt/tei:respStmt
                        return
                            <p class="resp"><span class="respRole">{$resp/tei:resp/text()}</span>: {$resp/tei:name/text()}</p>
                    }
                   
                </div>
             </body>
         </html>
    return
        <entry name="OEBPS/title-page.xhtml" type="xml">{$title-xhtml}</entry>
};

declare function epub:publication-xhtml-entry($id as xs:string, $work as item()*, $title, $creator, $urn){
    let $xhtml := 
        <html xmlns="http://www.w3.org/1999/xhtml">
             <head>
                 <title>publication-page</title>
                 <link type="text/css" rel="stylesheet" href="stylesheet.css"/>
             </head>
             <body>
                <hr/>
                 {
                    if($work/descendant::tei:sourceDesc) then 
                            <div>
                                <h3>Sources </h3>
                                {epub:fix-namespaces(epub:tei2html($work/descendant::tei:sourceDesc/descendant::tei:imprint))}
                            </div>    
                    else ()
                 }
                 {
                    if($work/descendant::tei:encodingDesc/tei:encodingDesc) then 
                            <div>
                                <hr/>
                                <h3>Editorial Statements </h3>
                                {(
                                epub:fix-namespaces(epub:tei2html($work/descendant::tei:encodingDesc/tei:encodingDesc)),
                                epub:fix-namespaces(epub:tei2html($work/descendant::tei:encodingDesc/tei:editorialDecl)),
                                epub:fix-namespaces(epub:tei2html($work/descendant::tei:distributor))
                                )}
                            </div>    
                    else ()
                 }
                 <div class="citation">
                  <hr/><h3>Citation </h3>
                  {epub:citation($work)}
                </div>
             </body>
         </html>
    return
        <entry name="OEBPS/publication-page.xhtml" type="xml">{$xhtml}</entry>
};

declare function epub:body-xhtml-entries($id as xs:string, $work as item()*, $title, $creator, $urn){
    if(count($work/descendant::tei:text/tei:body/tei:div) gt 1) then
        for $div at $p in $work/descendant::tei:text/tei:front | $work/descendant::tei:text/tei:body/tei:div | $work/descendant::tei:text/tei:back
        let $head := if($div/descendant::tei:head[1]) then $div/descendant::tei:head[1] else if($div/ancestor-or-self::tei:front) then 'Front Matter' else if($div/ancestor-or-self::tei:back) then 'Back Matter'  else concat('Section ', $p)
        let $h-id := concat('n',$p)
        return 
            <entry name="OEBPS/{$h-id}.xhtml" type="xml">
                <html xmlns="http://www.w3.org/1999/xhtml">
                   <head>
                       <title>{$title} {$h-id}</title>
                       <link type="text/css" rel="stylesheet" href="stylesheet.css"/>
                   </head>
                   <body>
                      { epub:fix-namespaces(epub:tei2html($div))}
                      <hr/>
                      {if($div/descendant::tei:note[@target]) then 
                        <h2>Footnotes</h2>
                      else ()}
                      {
                        for $n in $div/descendant::tei:note[@target]
                        return 
                            <div class="footnote">
                               {if($n/@xml:id) then 
                                   <span class="tei-footnote-id" id="{ string($n/@xml:id) }">{string($n/@xml:id)}</span>
                                else ()}
                                <div class="indent">
                                    {epub:fix-namespaces(epub:tei2html($n/node()))}
                                    {if($n/@resp) then
                                        <span> - [{substring-after($n/@resp,'#')}]</span>
                                     else ()
                                    }
                                </div>
                            </div>
                      }
                   </body>
               </html>
            </entry>
    else 
        <entry name="OEBPS/n1.xhtml" type="xml">
          <html xmlns="http://www.w3.org/1999/xhtml">
             <head>
                 <title>{$title}</title>
                 <link type="text/css" rel="stylesheet" href="stylesheet.css"/>
             </head>
             <body>
                { epub:fix-namespaces(epub:tei2html($work/descendant::tei:text))}
                <hr/>
                {
                        for $n in $work/descendant::tei:text/descendant::tei:note[@target]
                        return 
                            <div class="tei-{local-name($n)} footnote">{(
                                if($n/@xml:id) then 
                                   <span class="tei-footnote-id" id="{ string($n/@xml:id) }">{string($n/@xml:id)}</span>
                                else (),
                                <div class="footnote indent">{epub:fix-namespaces(epub:tei2html($n/node()))}</div>
                            )}</div>
                      }
             </body>
         </html>
        </entry>
};

declare function epub:stylesheet-entry($css as xs:string) {
    <entry name="OEBPS/stylesheet.css" type="binary">{util:binary-doc($css)}</entry>
};

declare function epub:toc-ncx-entry($id as xs:string, $work as item()*, $title, $creator, $urn) {
    let $toc-ncx :=
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
            <head>
                <meta name="dtb:uid" content="{$urn}"/>
                <meta name="dtb:depth" content="2"/>
                <meta name="dtb:totalPageCount" content="0"/>
                <meta name="dtb:maxPageNumber" content="0"/>
            </head>
            <docTitle>
                <text>{$title}</text>
            </docTitle>
            <navMap>
                <navPoint id="title-page" playOrder="1">
                    <navLabel>
                        <text>Title</text>
                    </navLabel>
                    <content src="title-page.xhtml"/>
                </navPoint>
                <navPoint id="publication-page" playOrder="2">
                       <navLabel>
                           <text>Publication Page</text>
                       </navLabel>
                       <content src="publication-page.xhtml"/>
                   </navPoint>
                {
                    if(count($work/descendant::tei:text/tei:body/tei:div) gt 1) then
                       for $div at $p in $work/descendant::tei:text/tei:front | $work/descendant::tei:text/tei:body/tei:div | $work/descendant::tei:text/tei:back
                       let $head := if($div/descendant::tei:head[1]) then $div/descendant::tei:head[1] else if($div/ancestor-or-self::tei:front) then 'Front Matter' else if($div/ancestor-or-self::tei:back) then 'Back Matter'  else concat('Section ', $p)
                       let $h-id := concat('n',$p)
                       return 
                                <navPoint id="{$h-id}" playOrder="{$p + 2}">
                                    <navLabel>
                                        <text>{$head}</text>
                                    </navLabel>
                                    <content src="{$h-id}.xhtml"/>
                                </navPoint>
                    else 
                        <navPoint id="n1" playOrder="3">
                                    <navLabel>
                                        <text>Contents</text>
                                    </navLabel>
                                    <content src="n1.xhtml"/>
                                </navPoint>
                   }
            </navMap>
        </ncx>
    return
        <entry name="OEBPS/toc.ncx" type="xml">{$toc-ncx}</entry>
};


declare function epub:nav-entry($id, $work, $title, $creator, $urn) {
    let $toc :=
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
            <head>
                <title>Navigation</title>
                <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
            </head>
            <body>
                <nav epub:type="toc">
                <ol>
                    {
                        let $divs := $work/descendant::tei:text/tei:front | $work/descendant::tei:text/tei:body/tei:div | $work/descendant::tei:text/tei:back
                        for $div at $p in $divs
                        let $html := if($div/descendant::tei:head[1]) then $div/descendant::tei:head[1] else if($div/ancestor-or-self::tei:front) then 'Front Matter' else if($div/ancestor-or-self::tei:back) then 'Back Matter'  else concat('Section ', $p)
                        let $h-id := concat('n',$p)
                        return
                            <li>
                                <a href="{$h-id}.xhtml">{$html}</a>
                            </li>
                    }
                    </ol>
                </nav>
            </body>
        </html>
    return
        <entry name="OEBPS/nav.xhtml" type="xml">{$toc}</entry>
};


declare function epub:fix-namespaces($node as node()*) {
    typeswitch ($node)
        case element() return
            element { QName("http://www.w3.org/1999/xhtml", local-name($node)) } {
                $node/@*, for $child in $node/node() return epub:fix-namespaces($child)
            }
        default return
            $node
};

(:~
 : Simple TEI to HTML transformation
 : @param $node   
:)
declare function epub:tei2html($nodes as node()*) as item()* {
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
            case element(tei:category) return element ul {epub:tei2html($node/node())}
            case element(tei:catDesc) return element li {epub:tei2html($node/node())}
            case element(tei:castList) return 
                <div class="tei-castList">{(
                    if($node/tei:head) then
                       epub:tei2html($node/tei:head)
                    else if($node/tei:p) then 
                        <h3>{epub:tei2html($node/tei:p)}</h3>
                    else (),
                    if($node/tei:castItem) then
                        element dl {epub:tei2html($node/tei:castItem)}    
                    else 
                        <div>{epub:tei2html($node/node())}</div>
                    )}</div>
            case element(tei:castItem) return
                if($node/tei:role) then
                  (<dt class="tei-castItem">{epub:tei2html($node/tei:actor)}</dt>,
                     <dd class="castItem">{epub:tei2html($node/tei:role)}</dd>,
                     <dd class="castItem">{epub:tei2html($node/tei:roleDesc)}</dd>)  
                else <dt class="tei-castItem">{epub:tei2html($node/node())}</dt>
            case element(tei:foreign) return 
                <span dir="{if($node/@xml:lang = ('syr','ar','^syr')) then 'rtl' else 'ltr'}">{
                    (if($node/@xml:lang) then attribute lang { $node/@xml:lang } else (),
                    epub:tei2html($node/node()))
                }</span>        
            case element(tei:graphic) return
                epub:graphic($node)
            case element(tei:hi) return
                epub:hi($node)                
            case element(tei:i) return
                <i>{ epub:tei2html($node/node()) }</i>                
            case element(tei:l) return
                <span class="tei-l {if($node/@rend) then concat('tei-',$node/@rend) else ()}" id="{epub:get-id($node)}">
                {epub:tei2html($node/node())}
                {if($node/@n != '' and not($node/@n mod 5)) then 
                    <span class="tei-line-number"> [{string($node/@n)}]</span> 
                    else ()}
                </span>
            case element(tei:list) return
                if($node/@type='ordered') then
                    <ol>{ epub:tei2html($node/node()) }</ol>
                else 
                    <ul>{ epub:tei2html($node/node()) }</ul>
            case element(tei:item) return
                <li>{ epub:tei2html($node/node()) }</li>
            case element(tei:lb) return
                <br/>
            case element(tei:head) return
                <span class="tei-head {(if($node/@title) then ' tei-head-title' else (),if($node/@subtitle) then ' tei-head-subtitle' else ())}">{epub:tei2html($node/node())}</span>    
            case element(tei:imprint) return 
            <span class="tei-{local-name($node)}" id="{epub:get-id($node)}">
            {
                    if($node//tei:pubPlace//text()) then $node//tei:pubPlace[1]//text() else (),
                    if($node//tei:pubPlace//text() and $node//tei:publisher//text()) then ': ' else (),
                    if($node//tei:publisher//text()) then $node//tei:publisher[1]//text() else (),
                    if(not($node//tei:pubPlace) and not($node//tei:publisher) and $node//tei:title[@level='m']) then <abbr title="no publisher">n.p.</abbr> else (),
                    if($node//tei:date/preceding-sibling::*) then ', ' else (),
                    if($node//tei:date) then $node//tei:date else <abbr title="no date of publication">n.d.</abbr>,
                    if($node/following-sibling::tei:biblScope[@unit='series']) then ', ' else (),
                    if($node//tei:extent/@type = "online") then (' ',<a href="{$node//tei:extent}" class="tei-extent-link"><span class="glyphicon glyphicon-book"></span> View </a>) else $node//tei:extent,
                    if($node//tei:note) then <span class="tei-note">{epub:tei2html($node//tei:note)}</span> else ()
            }</span>
            case element(tei:note) return 
                if($node/@target) then ()
                else <span class="tei-{local-name($node)}">{ epub:tei2html($node/node()) }</span>
            case element(tei:pb) return 
                    <span class="tei-pb" data-num="{string($node/@n)}">{string($node/@n)}</span>
            case element(tei:persName) return 
                epub:persName($node)
            case element(tei:ref) return
               epub:ref($node)    
            case element(tei:title) return 
                epub:title($node)
            case element(tei:p) return 
                <p xmlns="http://www.w3.org/1999/xhtml" id="{epub:get-id($node)}">{ epub:tei2html($node/node()) }</p>  (: THIS IS WHERE THE ANCHORS ARE INSERTED! :)
            case element(tei:rs) return (: create a new function for RSs to insert the content of specific variables; as is, content of the node is inserted as tooltip title. could use content of source attribute or link as the # ref :)
               <a href="#" data-toggle="tooltip" title="{epub:tei2html($node/node())}">{ epub:tei2html($node/node()) }</a>                
            case element(tei:sp) return 
                <div class="row tei-sp">
                    <div class="col-md-3">{epub:tei2html($node/tei:speaker)}</div>
                    <div class="col-md-9">{epub:tei2html($node/tei:l)}</div>
                </div>
            case element(tei:seriesStmt) return 
                if($node/tei:idno[@type="coursepack"]) then () 
                else <span class="tei-{local-name($node)}">{ epub:tei2html($node/node()) }</span>
            case element() return
                <span class="tei-{local-name($node)} {if($node/@n) then ' tei-n' else ()}" id="{epub:get-id($node)}">{ epub:tei2html($node/node()) }</span>                
            default return epub:tei2html($node/node())
};

declare function epub:header($header as element(tei:teiHeader)) {
    let $titleStmt := $header//tei:titleStmt
    let $pubStmt := $header//tei:publicationStmt
    let $sourceDesc := $header//tei:sourceDesc
    let $authors := $header//tei:titleStmt/tei:author
    let $resps := $header//tei:respStmt
    let $imprints := $header//tei:sourceDesc/tei:imprint
    let $onlineImprints := $header//tei:sourceDesc/tei:imprint/tei:extent[@type="online"]
    let $publishers := $header//tei:sourceDesc/tei:imprint/tei:publisher
    return
        <div xmlns="http://www.w3.org/1999/xhtml" class="text-header">
            <h1>{$titleStmt/tei:title/text()} <br/>
            <small>By 
            {
                let $author-full-names :=
                    for $author in $authors//tei:name
                    return epub:persName($author)
                let $name-count := count($author-full-names)
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
            </small></h1>
            { if($resps != '') then 
                <ul>{
                for $n in $resps
                return
                    <li class="list-unstyled">{concat($n/descendant::tei:resp, ' by ', string-join($n/descendant::tei:name,', '))}</li>
                }</ul>
              else() 
            }

    </div>
};

(: tei persName display first name/last name/add name :)
declare function epub:persName($nodes as node()*) {
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
             return (epub:tei2html($part/node()), if ($i != $last) then ' ' else ()),
             if($name/tei:addName) then (', ',epub:tei2html($name/tei:addName)) else ())
        else epub:tei2html($name/node())
    }</span> 
};

(: tei persName display last name/first name/add name:)
declare function epub:persName-last-first($nodes as node()*) {
let $name := 
    if($nodes/descendant-or-self::tei:name) then $nodes/descendant-or-self::tei:name[1]
    else if($nodes/descendant-or-self::tei:persName) then $nodes/descendant-or-self::tei:persName[1] 
    else $nodes
return 
    <span class="tei-persName">{
      if($name/child::*) then 
        (
            $name/descendant-or-self::tei:surname[1], 
            ', ', 
            $name/descendant-or-self::tei:forename[1], 
            if($name/descendant-or-self::tei:addName) then 
                for $addName in $name/descendant-or-self::tei:addName
                return (', ',epub:tei2html($addName)) 
            else ()
            )
      else epub:tei2html($name/node())
    }</span>
};

declare function epub:graphic($node as element (tei:graphic)) {
let $id := string(root($node)/tei:TEI/@xml:id)
let $imgURL :=  if($node/@url) then 
                    if(starts-with($node/@url,'https://') or starts-with($node/@url,'http://')) then
                        string($node/@url)
                   else if(starts-with($node/@url,'/')) then 
                        concat($config:image-root,$id,string($node/@url))
                   else concat($config:image-root,$id,'/',string($node/@url))
                else ()                   
return 
    if($imgURL) then 
        <a href="{$imgURL}">
            <img xmlns="http://www.w3.org/1999/xhtml" class="tei-graphic">{(
            attribute src { $imgURL },
            if($node/@width) then 
                attribute width { $node/@width }
            else (),
            if($node/@style) then 
                attribute style { $node/@style }
            else ()
            )}</img>
        </a>
    else ()               
};

declare function epub:hi($node as element (tei:hi)) {
    if($node/@rend='italic') then 
        <em>{epub:tei2html($node/node())}</em>  
    else if($node/@rend='bold') then 
        <strong>{epub:tei2html($node/node())}</strong>
    else if($node/@rend=('superscript','sup')) then 
        <sup>{epub:tei2html($node/node())}</sup>
    else if($node/@rend=('subscript','sub')) then         
        <sub>{epub:tei2html($node/node())}</sub>
    else <span class="tei-hi tei-{$node/@rend}">{epub:tei2html($node/node())}</span>
};

declare function epub:ref($node as element (tei:ref)) {
    if($node/@corresp) then
        <span class="footnoteRef text">
            <a href="#{string($node/@corresp)}" class="showFootnote">{epub:tei2html($node/node())}</a>
            <sup class="tei-ref footnoteRef show-print">{string($node/@corresp)}</sup>
        </span>
    else if(starts-with($node/@target,'http')) then 
        <a href="{$node/@target}">{epub:tei2html($node/node())}</a>
    else epub:tei2html($node/node())
};

declare function epub:title($node as element (tei:title)) {
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
            epub:tei2html($node/node()))}</span>
};

declare function epub:annotations($node as node()*) { 
    <span class="tei-annotation-show" xmlns="http://www.w3.org/1999/xhtml">{
        (if($node/@xml:lang) then attribute lang { $node/@xml:lang } else (),
        epub:tei2html($node/node()))}</span>
};

declare %private function epub:get-id($node as element()) {
    if($node/@xml:id) then
        string($node/@xml:id)
    else generate-id($node)
};

(:~
 : Select citation type based on child elements
:)
declare function epub:citation($nodes as node()*) {
    let $persons :=     if($nodes/descendant::tei:author) then 
                            epub:emit-responsible-persons($nodes/descendant::tei:author,20)
                        else if($nodes/descendant::tei:editor[not(@role) or @role!='translator']) then 
                            (epub:emit-responsible-persons($nodes/tei:editor[not(@role) or @role!='translator'],20), 
                            if(count($nodes/descendant::tei:editor[not(@role) or @role!='translator']) gt 1) then ' eds., ' else ' ed., ')
                        else ()
    let $analytic := if($nodes/descendant::tei:analytic/tei:title) then
                        if(starts-with($nodes/descendant::tei:analytic/tei:title,'"')) then
                           $nodes/descendant::tei:analytic/tei:title
                        else concat('"',$nodes/descendant::tei:analytic/tei:title,'." ')
                     else()
    let $monograph := if($nodes/descendant::tei:monogr/tei:title) then
                        if($nodes/descendant::tei:monogr/tei:title[@type="sub"]) then 
                            concat($nodes/descendant::tei:monogr/tei:title[@type='main'],'; ',$nodes/descendant::tei:monogr/tei:title[@type="sub"])
                        else ()
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
        concat(if($persons != '') then concat(string-join($persons,''),'. ') else (),
        if($analytic != '') then string-join($analytic,'') else (),
        if($monograph != '') then string-join($monograph,'') else (),
        if($imprint != '') then concat(', ',string-join($imprint,'')) else (),
        if($biblScope != '') then concat(', ',string-join($biblScope,'')) else (),
        '. Literature in Context: An Open Anthology. ', request:get-url(),'. ', 'Accessed: ', current-dateTime())
    }</span>
};

(:~
 : Output monograph citation
:)
declare function epub:record($nodes) {
    let $titleStmt := $nodes/descendant::tei:titleStmt
    let $persons :=  concat(epub:emit-responsible-persons($titleStmt/tei:editor[@role='creator'],3), 
                        if(count($titleStmt/tei:editor) gt 1) then ' (eds.), ' else ' (ed.), ')
    let $id := $nodes/descendant-or-self::tei:publicationStmt[1]/tei:idno[1]                         
    return 
        ($persons, '"',epub:tei2html($titleStmt/tei:title[1]),'" in ',epub:tei2html($titleStmt/tei:title[@level='m'][1]),' last modified ',
        for $d in $nodes/descendant-or-self::tei:publicationStmt/tei:date[1] return if($d castable as xs:date) then format-date(xs:date($d), '[MNn] [D], [Y]') else string($d),', ',replace($id[1],'/tei','')) 
};

(:~
 : Output monograph citation
:)
declare function epub:monograph($nodes as node()*) {
    let $persons := if($nodes/tei:author) then 
                        concat(epub:emit-responsible-persons($nodes/tei:author,3),', ')
                    else if($nodes/tei:editor[not(@role) or @role!='translator']) then 
                        (epub:emit-responsible-persons($nodes/tei:editor[not(@role) or @role!='translator'],3), 
                        if(count($nodes/tei:editor[not(@role) or @role!='translator']) gt 1) then ' eds., ' else ' ed., ')
                    else ()
    return (
            if(deep-equal($nodes/tei:editor | $nodes/tei:author, $nodes/preceding-sibling::tei:monogr/tei:editor | $nodes/preceding-sibling::tei:monogr/tei:author )) then () else $persons, 
            epub:tei2html($nodes/tei:title[1]),
            if(count($nodes/tei:editor[@role='translator']) gt 0) then (epub:emit-responsible-persons($nodes/tei:editor[@role!='translator'],3),', trans. ') else (),
            if($nodes/tei:edition) then 
                concat(', ', $nodes/tei:edition[1]/text(),' ')
            else (),
            if($nodes/tei:biblScope[@unit='vol']) then
                concat(' ',epub:tei2html($nodes/tei:biblScope[@unit='vol']),' ')
            else (),
            if($nodes/following-sibling::tei:series) then epub:series($nodes/following-sibling::tei:series)
            else if($nodes/following-sibling::tei:monogr) then ', '
            else if($nodes/preceding-sibling::tei:monogr and $nodes/preceding-sibling::tei:monogr/tei:imprint[child::*[string-length(.) gt 0]]) then   
            (' (', $nodes/preceding-sibling::tei:monogr/tei:imprint,')')
            else if($nodes/tei:imprint[child::*[string-length(.) gt 0]]) then 
                concat(' (',epub:tei2html($nodes/tei:imprint[child::*[string-length(.) gt 0]][1]),')', 
                if($nodes/following-sibling::tei:monogr) then ', ' else() )
            else ()
        )
};

(:~
 : Output series citation
:)
declare function epub:series($nodes as node()*) {(
    if($nodes/preceding-sibling::tei:monogr/tei:title[@level='j']) then ' (=' 
    else if($nodes/preceding-sibling::tei:series) then '; '
    else ', ',
    if($nodes/tei:title) then epub:tei2html($nodes/tei:title[1]) else (),
    if($nodes/tei:biblScope) then 
        (',', 
        for $r in $nodes/tei:biblScope[@unit='series'] | $nodes/tei:biblScope[@unit='vol'] | $nodes/tei:biblScope[@unit='tomus']
        return (epub:tei2html($r), if($r[position() != last()]) then ',' else ())) 
    else (),
    if($nodes/preceding-sibling::tei:monogr/tei:title[@level='j']) then ')' else (),
    if($nodes/preceding-sibling::tei:monogr/tei:imprint and not($nodes/following-sibling::tei:series)) then 
        (' (',epub:tei2html($nodes/preceding-sibling::tei:monogr/tei:imprint),')')
    else ()
)};

(:~
 : Output analytic citation
:)
declare function epub:analytic($nodes as node()*) {
    let $persons := if($nodes/tei:author) then 
                        concat(epub:emit-responsible-persons($nodes/tei:author,20),', ')
                    else if($nodes/tei:editor[not(@role) or @role!='translator']) then 
                        (epub:emit-responsible-persons($nodes/tei:editor[not(@role) or @role!='translator'],20), 
                        if(count($nodes/tei:editor[not(@role) or @role!='translator']) gt 1) then ' eds., ' else ' ed., ')
                    else ()
    return (
            $persons, concat('"',epub:tei2html($nodes/tei:title[1]),if(not(ends-with($nodes/tei:title[1][starts-with(@xml:lang,'en')][1],'.|:|,'))) then '.' else (),'"'),            
            if(count($nodes/tei:editor[@role='translator']) gt 0) then (epub:emit-responsible-persons($nodes/tei:editor[@role!='translator'],3),', trans. ') else (),
            if($nodes/following-sibling::tei:monogr/tei:title[1][@level='m']) then 'in' else(),
            if($nodes/following-sibling::tei:monogr) then epub:monograph($nodes/following-sibling::tei:monogr) else())
};

(:~
 : Output authors/editors
:)
declare function epub:emit-responsible-persons($nodes as node()*, $num as xs:integer?) {
    let $persons := 
        let $limit := if($num) then $num else 3
        let $count := count($nodes)
        return 
            if($count = 1) then 
                epub:person($nodes)  
            else if($count = 2) then
                (epub:person($nodes[1]),' and ',epub:person($nodes[2]))            
            else 
                for $n at $p in subsequence($nodes, 1, $num)
                return 
                    if($p = ($num - 1)) then 
                        (normalize-space(epub:person($n)), ' and ')
                    else concat(normalize-space(epub:person($n)),', ')
    return replace(string-join($persons),'\s+$','')                    
};

(:~
 : Output authors/editors child elements. 
:)
declare function epub:person($nodes as node()*) {
    epub:persName-last-first($nodes)
};
