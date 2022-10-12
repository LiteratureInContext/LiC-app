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

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function epub:epub($id as xs:string, $work as item()*) {
    if($work/descendant-or-self::coursepack) then
        let $title := string($work/@title)
        let $creator := string($work/@user)
        let $urn := document-uri(root($work/descendant-or-self::coursepack))
        return epub:generate-epub-coursepack($title, $creator, $work, $urn, ($config:app-root || "/resources/css/epub.css"), $id) 
    else 
        let $root := $work
        let $fileDesc := $root//tei:teiHeader/tei:fileDesc
        let $title := normalize-space(string-join($fileDesc//tei:titleStmt/tei:title[1]/string(),' '))
        let $creator := normalize-space(string-join($fileDesc/tei:titleStmt/tei:author[1]/string(),' '))
        let $urn := document-uri($root)
        return epub:generate-epub($title, $creator, $root, $urn, ($config:app-root || "/resources/css/epub.css"), $id)
};

(:~
    Main function of the EPUB module for assembling EPUB files: 
    Takes the elements required for an EPUB document (wrapped in <entry> elements), 
    and uses the compression:zip() function to returns a complete EPUB document.

    @param $title the dc:title of the EPUB
    @param $creator the dc:creator of the EPUB
    @param $text the tei:text element for the file, which contains the divs to be processed into the EPUB
    @param $urn the urn to use in the NCX file
    @param $db-path-to-resources the db path to the required static resources (cover.jpg, stylesheet.css)
    @param $filename the name of the EPUB file, sans file extension
    @return serialized EPUB file
    
    @see http://demo.exist-db.org/exist/functions/compression/zip
:)
declare function epub:generate-epub($title, $creator, $doc as item()*, $urn, $db-path-to-resources, $filename) {
    let $entries :=
        (
            epub:mimetype-entry(),
            epub:container-entry(),
            epub:content-opf-entry($title, $creator, $urn, $doc),
            epub:title-xhtml-entry($doc),
            epub:table-of-contents-xhtml-entry($title, $doc, false()),
            epub:body-xhtml-entries($doc),
            epub:stylesheet-entry($db-path-to-resources),
            epub:toc-ncx-entry($urn, $title, $doc)
        )
    return
        $entries
};

declare function epub:generate-epub-coursepack($title, $creator, $doc as item()*, $urn, $db-path-to-resources, $filename) {
    let $entries :=
        (
            epub:mimetype-entry(),
            epub:container-entry(),
            epub:content-opf-entry-coursepack($title, $creator, $urn, $doc),
            epub:title-xhtml-entry-coursepack($doc),
            epub:table-of-contents-xhtml-entry-coursepack($title, $doc, false()),
            epub:body-xhtml-entries-coursepack($doc),
            epub:stylesheet-entry($db-path-to-resources),
            epub:toc-ncx-entry-coursepack($urn, $title, $doc)
        )
    return
        $entries
};

(:~ 
    Helper function, returns the mimetype entry.
    Note that the EPUB specification requires that the mimetype file be uncompressed.  
    We can ensure the mimetype file is uncompressed by passing compression:zip() an entry element
    with a method attribute of "store".
    
    @return the mimetype entry
:)
declare function epub:mimetype-entry() {
    <entry name="mimetype" type="text" method="store">application/epub+zip</entry>
};

(:~ 
    Helper function, returns the META-INF/container.xml entry.

    @return the META-INF/container.xml entry
:)
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

(:~ 
    Helper function, returns the OEBPS/content.opf entry.

    @param $title the dc:title of the EPUB
    @param $creator the dc:creator of the EPUB
    @param $text the tei:text element for the file, which contains the divs to be processed into the EPUB
    @return the OEBPS/content.opf entry
:)
declare function epub:content-opf-entry($title, $creator, $urn, $text as item()*) {
    let $content-opf := 
        <package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0" unique-identifier="bookid">
            <metadata>
                <dc:title>{$title}</dc:title>
                <dc:creator>{$creator}</dc:creator>
                <dc:identifier id="bookid">{$urn}</dc:identifier>
                <dc:language>en-US</dc:language>
            </metadata>
            <manifest>
                <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
                <item id="title" href="title.html" media-type="application/xhtml+xml"/>
                <item id="table-of-contents" href="table-of-contents.html" media-type="application/xhtml+xml"/>
                { 
                if($text//tei:body/tei:div) then
                    for $div at $p in $text//tei:body/tei:div
                    let $h-id := if($div/@xml:id) then $div/@xml:id else if($div/@n)  then string($div/@n) else concat('n',$p)
                    return <item test="2" id="{$h-id}" href="{$h-id}.html" media-type="application/xhtml+xml"/>
                else ()
                }
                {
                for $image in $text//tei:graphic[@url]
                return
                    <item id="{$image/@url}" href="images/{$image/@url}.png" media-type="image/png"/>
                }
            </manifest>
            <spine toc="ncx">
                <itemref idref="title"/>
                <itemref idref="table-of-contents"/>
                {
                (: get just divs for TOC :)
                    for $div at $p in $text//tei:body/tei:div
                    let $h-id := if($div/@xml:id) then $div/@xml:id else if($div/@n)  then string($div/@n) else concat('n',$p)
                    return 
                        <itemref idref="{$h-id}"/>
                }
            </spine>
            <guide>
                <reference href="table-of-contents.html" type="toc" title="Table of Contents"/>
                {                    
                (: first text div :)
                    let $first-text-div := $text//tei:body/tei:div[1]
                    let $id := if($first-text-div/@xml:id) then $first-text-div/@xml:id else if($first-text-div/@n)  then string($first-text-div/@n) else 'n1' 
                    let $title := if($first-text-div/tei:head) then $first-text-div/tei:head/descendant-or-self::*[not(self::tei:ref) and not(self::tei:note)]/text() else if($first-text-div/@n)  then string($first-text-div/@n) else if($first-text-div/@xml:id) then string($first-text-div/@xml:id) else 'Entry'
                    return 
                        <reference href="{$id}.html" type="text" title="{$title}"/>
                }
                {
                (: index div :)
                if ($text/id('index')) then
                    <reference href="index.html" type="index" title="Index"/>
                else 
                    ()
                }
            </guide>
        </package>
    return
        <entry name="OEBPS/content.opf" type="xml">{$content-opf}</entry>
};

declare function epub:content-opf-entry-coursepack($title, $creator, $urn, $text as item()*) {
    let $content-opf := 
        <package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0" unique-identifier="bookid">
            <metadata>
                <dc:title>{$title}</dc:title>
                <dc:creator>{$creator}</dc:creator>
                <dc:identifier id="bookid">{$urn}</dc:identifier>
                <dc:language>en-US</dc:language>
            </metadata>
            <manifest>
                <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
                <item id="title" href="title.html" media-type="application/xhtml+xml"/>
                <item id="table-of-contents" href="table-of-contents.html" media-type="application/xhtml+xml"/>
                {
                for $item at $p in $text//*:work
                let $epubID := concat('n',$p)
                group by $workID := $item/@id
                return 
                    <item id="{$epubID[1]}" href="{$epubID[1]}.html" media-type="application/xhtml+xml"/>}
                {
                for $image in $text//tei:graphic[@url]
                return
                    <item id="{$image/@url}" href="images/{$image/@url}.png" media-type="image/png"/>
                }
            </manifest>
            <spine toc="ncx">
                <itemref idref="title"/>
                <itemref idref="table-of-contents"/>
                {
                (: get just divs for TOC :)
                for $item at $p in $text//*:work
                let $epubID := concat('n',$p)
                group by $workID := $item/@id
                return <itemref idref="{$epubID[1]}"/>
                }
            </spine>
            <guide>
                <reference href="table-of-contents.html" type="toc" title="Table of Contents"/>
                {                    
                (: first text div :)
                for $item at $p in $text//*:work[1]
                let $epubID := concat('n',$p)
                let $title := if($item//*:text) then concat('Selections from',$item/*:title[1]/text()) else $item/*:title[1]/text()
                group by $workID := $item/@id                
                return <reference href="n1.html" type="text" title="{$title}"/>                
                }
                {
                (: index div :)
                if ($text/id('index')) then
                    <reference href="index.html" type="index" title="Index"/>
                else 
                    ()
                }
            </guide>
        </package>
    return
        <entry name="OEBPS/content.opf" type="xml">{$content-opf}</entry>
};

(:~ 
    Helper function, creates the OEBPS/title.html file.

    @param $volume the volume's ID
    @return the entry for the OEBPS/title.html file
:)
declare function epub:title-xhtml-entry($doc) {
    let $title := 'Title page'
    let $body := epub:title-xhtml-body($doc//tei:fileDesc)
    let $title-xhtml := epub:assemble-xhtml($title, $body)
    return
        <entry name="OEBPS/title.html" type="xml">{$title-xhtml}</entry>
};

declare function epub:title-xhtml-entry-coursepack($doc) {
    let $title := 'Title page'
    let $body := epub:title-xhtml-body-coursepack($doc/descendant-or-self::*:coursepack)
    let $title-xhtml := epub:assemble-xhtml($title, $body)
    return
        <entry name="OEBPS/title.html" type="xml">{$title-xhtml}</entry>
};

(:~ 
    Helper function, creates the OEBPS/cover.html file.

    @param $volume the volume's ID
    @return the entry for the OEBPS/cover.html file
:)
declare function epub:title-xhtml-body($fileDesc as item()*) {
    <div xmlns="http://www.w3.org/1999/xhtml" id="title">
        <h2 class="author">{ $fileDesc/tei:titleStmt/tei:author/string() }</h2>
        <h1>
            { $fileDesc/tei:titleStmt/tei:title/string()}
        </h1>
        <ul>
        {
            for $resp in $fileDesc/tei:titleStmt/tei:respStmt
            return
                <li class="resp"><span class="respRole">{$resp/tei:resp/text()}</span>: {$resp/tei:name/text()}</li>
        }
        </ul>
        { epub:fix-namespaces(epub:tei2epub($fileDesc/tei:publicationStmt)) }
        { epub:fix-namespaces(epub:tei2epub($fileDesc/tei:sourceDesc)) }
    </div>
};

declare function epub:title-xhtml-body-coursepack($fileDesc as item()*) {
    <div xmlns="http://www.w3.org/1999/xhtml" id="title">
        <h2 class="author">{ string($fileDesc/@user) }</h2>
        <h1>
            { string($fileDesc/@title)}
        </h1>
        { epub:fix-namespaces(epub:tei2epub($fileDesc/tei:publicationStmt)) }
        { epub:fix-namespaces(epub:tei2epub($fileDesc/tei:sourceDesc)) }
    </div>
};

(:~ 
    Helper function, creates the XHTML files for the body of the EPUB.

    @param $text the tei:text element for the file, which contains the divs to be processed into the EPUB
    @return the serialized XHTML page, wrapped in an entry element
:)
declare function epub:body-xhtml-entries($doc) {                    
        for $div at $p in $doc//tei:body/tei:div
        let $title := if($div/tei:head) then $div/tei:head/descendant-or-self::*[not(self::tei:ref) and not(self::tei:note)]/text() else if($div/@n)  then string($div/@n) else if($div/@xml:id) then string($div/@xml:id) else 'Entry' 
        let $body := epub:tei2epub($div)
        let $body-xhtml:= epub:assemble-xhtml($title, epub:fix-namespaces($body))
        let $id := if($div/@xml:id) then $div/@xml:id else if($div/@n)  then string($div/@n) else concat('n',$p)
        return
            <entry name="{concat('OEBPS/', $id, '.html')}" type="xml">{$body-xhtml}</entry>
};

declare function epub:body-xhtml-entries-coursepack($doc) {
        for $item at $p in $doc//tei:TEI[not(ancestor::*:coursepack)][descendant::tei:titleStmt/tei:title[1] != '']
        let $epubID := concat('n',$p)
        let $id := document-uri(root($item))
        let $title := if($doc//*:work[@id = $id]/text) then concat('Selections from',$item/descendant::tei:titleStmt/tei:title[1]/text()) else $item/descendant::tei:titleStmt/tei:title[1]/text() 
        let $body := if($doc//*:work[@id = $id]/*:text) then
                        epub:tei2epub($doc//*:work[@id = $id]/*:text/child::*)
                     else epub:tei2epub($item/descendant::tei:body)
        let $body-xhtml:= epub:assemble-xhtml($title, epub:fix-namespaces($body))
        group by $workID := $id
        return 
            <entry name="{concat('OEBPS/', $epubID, '.html')}" type="xml">{$body-xhtml}</entry>
};

(:~ 
    Helper function, creates the CSS entry for the EPUB.

    @param $db-path-to-css the db path to the required static resources (cover.jpg, stylesheet.css)
    @return the CSS entry
:)
declare function epub:stylesheet-entry($db-path-to-css) {
    <entry name="OEBPS/stylesheet.css" type="binary">{util:binary-doc($db-path-to-css)}</entry>
};

(:~ 
    Helper function, creates the OEBPS/toc.ncx file.

    @param $urn the EPUB's urn
    @param $text the tei:text element for the file, which contains the divs to be processed into the EPUB
    @return the NCX element's entry
:)
declare function epub:toc-ncx-entry($urn, $title, $text) { 
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
                <navPoint id="navpoint-title" playOrder="1">
                    <navLabel>
                        <text>Title</text>
                    </navLabel>
                    <content src="title.html"/>
                </navPoint>
                <navPoint id="navpoint-table-of-contents" playOrder="2">
                    <navLabel>
                        <text>Table of Contents</text>
                    </navLabel>
                    <content src="table-of-contents.html"/>
                </navPoint>
                {epub:toc-ncx-div($text//tei:body, 2)}
            </navMap>
        </ncx>
    return 
        <entry name="OEBPS/toc.ncx" type="xml">{$toc-ncx}</entry>
};

declare function epub:toc-ncx-entry-coursepack($urn, $title, $text) { 
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
                <navPoint id="navpoint-title" playOrder="1">
                    <navLabel>
                        <text>Title</text>
                    </navLabel>
                    <content src="title.html"/>
                </navPoint>
                <navPoint id="navpoint-table-of-contents" playOrder="2">
                    <navLabel>
                        <text>Table of Contents</text>
                    </navLabel>
                    <content src="table-of-contents.html"/>
                </navPoint>
                { epub:toc-ncx-tei($text, 2) }
            </navMap>
        </ncx>
    return 
        <entry name="OEBPS/toc.ncx" type="xml">{$toc-ncx}</entry>
};

declare function epub:toc-ncx-tei($root as item()*, $start as xs:int) {        
    for $item at $p in $root//tei:TEI[not(ancestor::coursepack)][descendant::tei:titleStmt/tei:title[1] != '']
    let $epubID := concat('n',$p)
    let $id := document-uri(root($item))
    let $title := if($root//work[@id = $id]/text) then concat('Selections from',$item/descendant::tei:titleStmt/tei:title[1]/text()) else $item/descendant::tei:titleStmt/tei:title[1]/text()  
    let $lastFile := $root//tei:TEI[not(ancestor::coursepack)][descendant::tei:titleStmt/tei:title[1] != ''][last()]
    let $lastFileID := concat('n',count($root//tei:TEI[not(ancestor::coursepack)][descendant::tei:titleStmt/tei:title[1] != '']))
    let $index := count($p) + 1
    group by $workID := $id
    return 
        <navPoint id="navpoint-{$epubID}" playOrder="{$start + $index}" xmlns="http://www.daisy.org/z3986/2005/ncx/">
            <navLabel>
                <text>{$title}</text>
            </navLabel>
            <content src="{$lastFileID}.html#{$epubID}"/>
            { epub:toc-ncx-div($item, $start)}
        </navPoint>
};


declare function epub:toc-ncx-div($root as element(), $start as xs:int) {        
    for $div at $p in $root/tei:div
    let $id := if($div/@xml:id) then $div/@xml:id else if($div/@n)  then string($div/@n) else concat('n',$p)
    let $title := if($div/tei:head) then $div/tei:head/descendant-or-self::*[not(self::tei:ref) and not(self::tei:note)]/text() else if($div/@n)  then string($div/@n) else if($div/@xml:id) then string($div/@xml:id) else 'Entry'
    let $lastFile := $div/ancestor-or-self::tei:div[last()]
    let $lastFileID := if($lastFile/@xml:id) then string($lastFile/@xml:id) else if($lastFile/@n)  then string($lastFile/@n) else concat('n',count($root/tei:div))
    let $index := $p + count($div/ancestor::tei:div) + 1
    return
        <navPoint id="navpoint-{$id}" playOrder="{$start + $index}" xmlns="http://www.daisy.org/z3986/2005/ncx/">
            <navLabel>
                <text>{$title}</text>
            </navLabel>
            <content src="{$lastFileID}.html#{$id}"/>
            { epub:toc-ncx-div($div, $start)}
        </navPoint>
};

(:~ 
    Helper function, creates the OEBPS/table-of-contents.html file.

    @param $title the page's title
    @param $text the tei:text element for the file, which contains the divs to be processed into the EPUB
    @return the entry for the OEBPS/table-of-contents.html file
:)
declare function epub:table-of-contents-xhtml-entry($title, $doc, $suppress-documents) {
    let $body := 
        <div xmlns="http://www.w3.org/1999/xhtml" id="table-of-contents">
            <h2>Contents</h2>
            <ul>{                  
                     for $div at $p in $doc//tei:body/tei:div
                     let $title := if($div/tei:head) then $div/tei:head/descendant-or-self::*[not(self::tei:ref) and not(self::tei:note)]/text() else if($div/@n)  then string($div/@n) else if($div/@xml:id) then string($div/@xml:id) else 'Entry'
                     let $id := if($div/@xml:id) then $div/@xml:id else if($div/@n)  then string($div/@n) else concat('n',$p) 
                     return
                         <li>
                             <a href="{$id}.html#{$id}">
                             {$title}
                             </a>
                         </li>
            }</ul>
        </div>
    let $table-of-contents-xhtml := epub:assemble-xhtml($title, $body)
    return 
        <entry name="OEBPS/table-of-contents.html" type="xml">{$table-of-contents-xhtml}</entry>
};

declare function epub:table-of-contents-xhtml-entry-coursepack($title, $doc, $suppress-documents) {
    let $body := 
        <div xmlns="http://www.w3.org/1999/xhtml" id="table-of-contents">
            <h2>Contents</h2>
            <ul>{
                    for $item at $p in $doc//tei:TEI[not(ancestor::*:coursepack)][descendant::tei:titleStmt/tei:title[1] != '']
                    let $epubID := concat('n',$p)
                    let $id := document-uri(root($item))
                    let $title := if($doc//*:work[@id = $id]/*:text) then concat('Selections from ',$item/descendant::tei:titleStmt/tei:title[1]/text()) else $item/descendant::tei:titleStmt/tei:title[1]/text()
                    group by $workID := $id
                    return
                         <li class="coursepack">
                             <a href="{$epubID}.html#{$epubID}">
                             {$title}
                             </a>
                         </li>
            }</ul>
        </div>
    let $table-of-contents-xhtml := epub:assemble-xhtml($title, $body)
    return 
        <entry name="OEBPS/table-of-contents.html" type="xml">{$table-of-contents-xhtml}</entry>
};

(:~ 
    Helper function, contains the basic XHTML shell used by all XHTML files in the EPUB package.

    @param $title the page's title
    @param $body the body content
    @return the serialized XHTML element
:)
declare function epub:assemble-xhtml($title, $body) {
    <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
            <title>{$title}</title>
            <link type="text/css" rel="stylesheet" href="stylesheet.css"/>
        </head>
        <body>
            {$body}
        </body>
    </html>
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

(: EPUB html output :)
(:~
 : Simple TEI to HTML transformation
 : @param $node   
:)
declare function epub:tei2epub($nodes as node()*) as item()* {
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
            case element(tei:category) return element ul {epub:tei2epub($node/node())}
            case element(tei:catDesc) return element li {epub:tei2epub($node/node())}
            case element(tei:castList) return 
                <div class="tei-castList">{(
                    if($node/tei:head) then
                       epub:tei2epub($node/tei:head)
                    else (),
                    element dl {epub:tei2epub($node/tei:castItem)})}</div>
            case element(tei:castItem) return
                if($node/tei:role) then
                  (<dt class="tei-castItem">{epub:tei2epub($node/tei:actor)}</dt>,
                     <dd class="castItem">{epub:tei2epub($node/tei:role)}</dd>,
                     <dd class="castItem">{epub:tei2epub($node/tei:roleDesc)}</dd>)  
                else <dt class="tei-castItem">{epub:tei2epub($node/node())}</dt>
            case element(tei:foreign) return 
                <span dir="{if($node/@xml:lang = ('syr','ar','^syr')) then 'rtl' else 'ltr'}">{
                    (if($node/@xml:lang) then attribute lang { $node/@xml:lang } else (),
                    epub:tei2epub($node/node()))
                }</span>        
            case element(tei:graphic) return
                epub:graphic($node)
            case element(tei:hi) return
                epub:hi($node)                
            case element(tei:i) return
                <i>{ epub:tei2epub($node/node()) }</i>                
            case element(tei:l) return
                <span class="tei-l {if($node/@rend) then concat('tei-',$node/@rend) else ()}" id="{epub:get-id($node)}">{if($node/@n) then <span class="tei-line-number">{string($node/@n)}</span> else ()}{epub:tei2epub($node/node())}</span>
            case element(tei:lb) return
                <br/>
            case element(tei:head) return
                <span class="tei-head {(if($node/@title) then ' tei-head-title' else (),if($node/@subtitle) then ' tei-head-subtitle' else ())}">{epub:tei2epub($node/node())}</span>    
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
                    if($node//tei:note) then <span class="tei-note">{epub:tei2epub($node//tei:note)}</span> else ()
            }</span>
            case element(tei:note) return 
                if($node/@target) then 
                    <aside id="{ string($node/@xml:id) }" epub:type="footnote" class="tei-{local-name($node)} footnote 
                        {(
                            if($node/@type != '') then string($node/@type) 
                            else (), 
                            if($node/@place != '') then string($node/@place) 
                            else ())}">
                    {(
                    epub:tei2epub($node/node()),
                    if($node/@resp) then
                        <span class="tei-resp"> - [<a href="{$config:nav-base}/contributors.html?contributorID={substring-after($node/@resp,'#')}">{substring-after($node/@resp,'#')}</a>]</span>
                    else ()
                    )}</aside>
                else <span class="tei-{local-name($node)}">{ epub:tei2epub($node/node()) }</span>
            case element(tei:pb) return 
                    <span class="tei-pb" data-num="{string($node/@n)}">{string($node/@n)}</span>
            case element(tei:persName) return 
                epub:persName($node)
            case element(tei:ref) return
               epub:ref($node)    
            case element(tei:title) return 
                epub:title($node)
            case element(tei:text) return 
                epub:tei2epub($node/node()) 
            case element(tei:p) return 
                <p xmlns="http://www.w3.org/1999/xhtml" id="{epub:get-id($node)}">{ epub:tei2epub($node/node()) }</p>  (: THIS IS WHERE THE ANCHORS ARE INSERTED! :)
            case element(tei:rs) return (: create a new function for RSs to insert the content of specific variables; as is, content of the node is inserted as tooltip title. could use content of source attribute or link as the # ref :)
               <a href="#" data-toggle="tooltip" title="{epub:tei2epub($node/node())}">{ epub:tei2epub($node/node()) }</a>                
            case element(tei:sp) return 
                <div class="row tei-sp">
                    <div class="col-md-3">{epub:tei2epub($node/tei:speaker)}</div>
                    <div class="col-md-9">{epub:tei2epub($node/tei:l)}</div>
                </div>
            case element(tei:seriesStmt) return 
                if($node/tei:idno[@type="coursepack"]) then () 
                else <span class="tei-{local-name($node)}">{ epub:tei2epub($node/node()) }</span>
            case element(exist:match) return
                <span class="match" style="background-color:yellow;">{$node/text()}</span>
            case element() return
                <span class="tei-{local-name($node)} {if($node/@n) then ' tei-n' else ()}" id="{epub:get-id($node)}">{ epub:tei2epub($node/node()) }</span>                
            default return epub:tei2epub($node/node())
};

declare function epub:get-id($node as element()) {
    if($node/@xml:id) then
        string($node/@xml:id)
    else if($node/@exist:id) then
        string($node/@exist:id)
    else generate-id($node)
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
             return (epub:tei2epub($part/node()), if ($i != $last) then ' ' else ()),
             if($name/tei:addName) then (', ',epub:tei2epub($name/tei:addName)) else ())
        else epub:tei2epub($name/node())
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
                return (', ',epub:tei2epub($addName)) 
            else ()
            )
      else epub:tei2epub($name/node())
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
        <em>{epub:tei2epub($node/node())}</em>  
    else if($node/@rend='bold') then 
        <strong>{epub:tei2epub($node/node())}</strong>
    else if($node/@rend=('superscript','sup')) then 
        <sup>{epub:tei2epub($node/node())}</sup>
    else if($node/@rend=('subscript','sub')) then         
        <sub>{epub:tei2epub($node/node())}</sub>
    else <span class="tei-hi tei-{$node/@rend}">{epub:tei2epub($node/node())}</span>
};

declare function epub:ref($node as element (tei:ref)) {
    if($node/@corresp) then
        <span class="footnoteRef text">
            <a href="#{string($node/@corresp)}" class="showFootnote" epub:type="noteref">{epub:tei2epub($node/node())}</a>
        </span>
    else if(starts-with($node/@target,'http')) then 
        <a href="{$node/@target}">{epub:tei2epub($node/node())}</a>
    else epub:tei2epub($node/node())
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
            epub:tei2epub($node/node()))}</span>
};

declare function epub:annotations($node as node()*) { 
    <span class="tei-annotation-show" xmlns="http://www.w3.org/1999/xhtml">{
        (if($node/@xml:lang) then attribute lang { $node/@xml:lang } else (),
        epub:tei2epub($node/node()))}</span>
};
