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
import module namespace tei2html="http://syriaca.org/tei2html" at "tei2html.xqm";
import module namespace config="http://LiC.org/apps/config" at "../config.xqm";
declare namespace html="http://www.w3.org/1999/xhtml";
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
        { epub:fix-namespaces(tei2html:tei2html($fileDesc/tei:publicationStmt)) }
        { epub:fix-namespaces(tei2html:tei2html($fileDesc/tei:sourceDesc)) }
    </div>
};

declare function epub:title-xhtml-body-coursepack($fileDesc as item()*) {
    <div xmlns="http://www.w3.org/1999/xhtml" id="title">
        <h2 class="author">{ string($fileDesc/@user) }</h2>
        <h1>
            { string($fileDesc/@title)}
        </h1>
        { epub:fix-namespaces(tei2html:tei2html($fileDesc/tei:publicationStmt)) }
        { epub:fix-namespaces(tei2html:tei2html($fileDesc/tei:sourceDesc)) }
    </div>
};

(:~ 
    Helper function, creates the XHTML files for the body of the EPUB.

    @param $text the tei:text element for the file, which contains the divs to be processed into the EPUB
    @return the serialized XHTML page, wrapped in an entry element
    
    NOTE: this is where footnotes need to be grabbed, but are not. 
:)
declare function epub:body-xhtml-entries($doc) {                    
        for $div at $p in $doc//tei:body/tei:div
        let $title := if($div/tei:head) then $div/tei:head/descendant-or-self::*[not(self::tei:ref) and not(self::tei:note)]/text() else if($div/@n)  then string($div/@n) else if($div/@xml:id) then string($div/@xml:id) else 'Entry' 
        let $footnotes := $doc/descendant::tei:note[@target]
        let $tei := <TEI xmlns="http://www.tei-c.org/ns/1.0">{($div,$footnotes)}</TEI>
        let $body := tei2html:tei2html($tei)
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
                        tei2html:tei2html($doc//*:work[@id = $id]/*:text/child::*)
                     else tei2html:tei2html($item/descendant::tei:body)
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
                {epub:toc-ncx-div($text//tei:text, 2)}
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
(:footnote
<span class="footnoteRef text"><a href="#moroccoCase" class="showFootnote">neat
    morocco case</a><sup class="tei-ref footnoteRef show-print">moroccoCase</sup></span>
    
    
    <a href="chapter.xhtml#myNote" epub:type="noteref">1</a></p>
    
    <aside id="myNote" epub:type="footnote"><p style="direction:rtl">Text in popup</p></aside>
    
    
    <span class="tei-footnote-id " id="moroccoCase">
:)
declare function epub:fix-namespaces($node as node()*) {
    typeswitch ($node)
        case element() return
            if(local-name($node) = 'span') then 
                if(contains($node/@class,'footnoteRef')) then 
                    for $ref in $node/*:a
                    return ('&#160;', <a xmlns="http://www.w3.org/1999/xhtml" href="{$ref/@href}" epub:type="noteref">{$ref//text()}</a>)
                else if(contains($node/@class,'footnote')) then 
                    let $id := $node/*/@id[1]
                    return 
                    <aside xmlns="http://www.w3.org/1999/xhtml" id="{$id}" epub:type="footnote">
                        {for $child in $node/child::*[not(@class="tei-footnote-id ")] return epub:fix-namespaces($child)}
                    </aside>
                else 
                    element { QName("http://www.w3.org/1999/xhtml", local-name($node)) } {
                        $node/@*, for $child in $node/node() return epub:fix-namespaces($child)
                    }
            else 
                element { QName("http://www.w3.org/1999/xhtml", local-name($node)) } {
                    $node/@*, for $child in $node/node() return epub:fix-namespaces($child)
                }
        default return
            $node
};