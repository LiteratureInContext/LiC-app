xquery version "3.0";

module namespace tei2fo="http://LiC.org/tei2fo";
import module namespace config="http://LiC.org/config" at "../config.xqm";

declare namespace fo="http://www.w3.org/1999/XSL/Format";
declare namespace tei="http://www.tei-c.org/ns/1.0";

(: Global style variables :)
declare variable $tei2fo:global-flow-styles {(
    attribute font-family {'Times'},
    attribute font-size {'10pt'},
    attribute line-height {'2'},
    attribute text-align {'justify'},
    attribute orphans {'3'},
    attribute widows {'3'}
    )};
declare variable $tei2fo:h1 {(
    attribute font-size{'18pt'},
    attribute margin-top {'2em'},
    attribute space-before{'1em'},
    attribute space-after{'1em'}
    )};
declare variable $tei2fo:h2 {(
    attribute font-size{'16pt'},
    attribute space-before{'1em'},
    attribute space-after{'1em'}
    )};
declare variable $tei2fo:h3 {(
    attribute font-size{'12pt'},
    attribute space-before{'.5em'},
    attribute space-after{'.5em'}
    )};
declare variable $tei2fo:basic-inline-element-attributes {(attribute margin-left{'8pt'},
    attribute padding-right{'8pt'}
    )};
declare variable $tei2fo:basic-block-element-attributes {(
    attribute space-before {'1em'},
    attribute space-after {'1em'}
    )};
declare variable $tei2fo:indented-block-element-attributes {
    attribute margin-left {'2em'}
    };    

declare variable $tei2fo:link-attributes {
    attribute color {'#0645AD'}
    };    

declare variable $tei2fo:line-number-attributes {(
   attribute font-size {"8pt"},
   attribute color {"#666666"}
    )};

(: Simple typeswitch for tei elements :)
declare function tei2fo:tei2fo($nodes as node()*, $p) {
    for $node in $nodes
    return
        typeswitch ($node)  
            case text() return $node
            case comment() return ()
            (: A :)
            case element(tei:ab) return
                <fo:block space-after="8mm">{tei2fo:tei2fo($node/node(),$p)}</fo:block>            
            (: C :)
            case element(tei:castList) return 
                <fo:block>
                    {(
                    $tei2fo:basic-block-element-attributes,
                    if($node/tei:head) then
                        <fo:block>{$tei2fo:h3}{tei2fo:tei2fo($node/tei:head,$p)}</fo:block>
                    else (),
                    <fo:block margin-left="1em">{tei2fo:tei2fo($node/tei:role,$p)}</fo:block>,
                    <fo:block margin-left="2em">{tei2fo:tei2fo($node/tei:roleDesc,$p)}</fo:block>
                    )}
                </fo:block>                        
            (: D :)
            case element(tei:div) return
                    <fo:block page-break-after="always">
                        {$tei2fo:basic-block-element-attributes}
                        {tei2fo:tei2fo($node/node(),$p)}
                    </fo:block>
            case element(tei:docImprint) return 
                if($node/parent::tei:titlePage) then 
                    <fo:block font-size="12pt" margin-top="5em">{$tei2fo:basic-block-element-attributes}
                        {tei2fo:tei2fo($node/node(),$p)}   
                    </fo:block>
                else tei2fo:tei2fo($node/node(),$p)
            (: F :)                    
            case element(tei:front) return 
                <fo:block page-break-after="always" border-bottom-style="1mm" border-top-style="1mm">
                    {$tei2fo:basic-block-element-attributes}
                    {tei2fo:tei2fo($node/node(),$p)}
                </fo:block>
            (: G :)                
            case element(tei:graphic) return ()
                (:<fo:external-graphic width="100%" content-width="scale-down-to-fit" scaling="uniform" src="url({$node/@url})"/>:)
            (: H :)
            case element(tei:head) return
                let $level := count($node/ancestor-or-self::tei:div)
                return
                    if ($level = 1) then
                        <fo:block>{$tei2fo:h1}{ tei2fo:tei2fo($node/node(),$p) }</fo:block>
                    else
                        <fo:block>{$tei2fo:h2}
                            <fo:marker marker-class-name="titel">
                                {$node/text()}
                            </fo:marker>
                            { tei2fo:tei2fo($node/node(),$p) }
                        </fo:block>            
            case element(tei:hi) return
                if($node/@rend='bold') then
                    <fo:inline font-weight="bold">{$tei2fo:basic-inline-element-attributes}{tei2fo:tei2fo($node/node(),$p)}</fo:inline>   
                else if($node/@rend='italic') then 
                    <fo:inline font-style="italic">{$tei2fo:basic-inline-element-attributes}{tei2fo:tei2fo($node/node(),$p)}</fo:inline>
                else if($node/@rend=('superscript','sup')) then
                    <fo:inline vertical-align="super" font-size="8pt">{tei2fo:tei2fo($node/node(),$p)}</fo:inline>
                else if($node/@rend=('subscript','sub')) then
                    <fo:inline vertical-align="sub" font-size="8pt">{tei2fo:tei2fo($node/node(),$p)}</fo:inline>
                else if($node/@rend='smallcaps') then 
                    <fo:inline font-variant="smallcaps">{$tei2fo:basic-inline-element-attributes}{tei2fo:tei2fo($node/node(),$p)}</fo:inline>
                else if($node/@rend='underline') then 
                    <fo:inline text-decoration="underline">{$tei2fo:basic-inline-element-attributes}{tei2fo:tei2fo($node/node(),$p)}</fo:inline>                    
                else tei2fo:tei2fo($node/node(),$p) 
            (: L :)
            case element(tei:l) return
                <fo:block>
                    {if($node/@rend='italic') then
                        attribute font-style { 'italic' }
                     else if($node/@rend='bold') then
                        attribute font-weight { 'bold' }
                     else if($node/@rend=('superscript','sup')) then
                        (attribute vertical-align { 'sup' },
                        attribute font-size { '8pt' }
                        )
                     else if($node/@rend=('subscript','sub')) then
                        (attribute vertical-align { 'sub' },
                        attribute font-size { '8pt' }
                        )                                                
                     else ()}
                    {if($node/@n) then <fo:inline>{$tei2fo:line-number-attributes}{$tei2fo:basic-inline-element-attributes}{string($node/@n)}</fo:inline>
                    else ()}                     
                    {tei2fo:tei2fo($node/node(),$p)}
                </fo:block> 
            case element(tei:lb) return
                <fo:block/>
            case element(tei:lg) return
                <fo:block>{$tei2fo:basic-block-element-attributes}{tei2fo:tei2fo($node/node(),$p)}</fo:block>
            (: N :)
            case element(tei:note) return 
                if($node/@target) then () 
                else <fo:block>{$tei2fo:basic-block-element-attributes}{ tei2fo:tei2fo($node/node(),$p) }</fo:block>
            (: P :)
            case element(tei:p) return 
                <fo:block>{$tei2fo:basic-block-element-attributes}{ tei2fo:tei2fo($node/node(),$p) }</fo:block>            
            case element(tei:pb) return 
                <fo:block text-align="center">{$tei2fo:basic-block-element-attributes} - {string($node/@n)} - </fo:block>
            (: R :)
            case element(tei:ref) return
                   if($node/@corresp) then 
                        (
                        <fo:basic-link internal-destination="{
                            if($p gt 1) then 
                                concat('work',$p,'-',string($node/@corresp)) 
                            else string($node/@corresp
                            )
                            }">
                        <fo:inline text-decoration="underline">{tei2fo:tei2fo($node/node(),$p)}</fo:inline>, 
                        <fo:inline baseline-shift="super" font-size="8pt">
                            {$tei2fo:link-attributes}{string($node/@corresp)}
                        </fo:inline>
                        </fo:basic-link>
                        )  
                   else if(starts-with($node/@target,'http')) then 
                      <fo:basic-link external-destination="url({$node/@target})">{$tei2fo:link-attributes}{tei2fo:tei2fo($node/node(),$p)}</fo:basic-link>
                   else tei2fo:tei2fo($node/node(),$p)            
            (: S :)
            case element(tei:sp) return 
                <fo:block>
                    {(
                    $tei2fo:basic-block-element-attributes,
                    <fo:table>
                        {$tei2fo:basic-block-element-attributes}
                        <fo:table-column column-width="20%"/>
                        <fo:table-column column-width="80%"/>
                        <fo:table-body>
                                   <fo:table-row>
                                       <fo:table-cell>
                                           <fo:block margin-bottom="1.5em">{tei2fo:tei2fo($node/tei:speaker,$p)} </fo:block>
                                       </fo:table-cell>
                                       <fo:table-cell>
                                           <fo:block>{tei2fo:tei2fo($node/tei:l,$p)}</fo:block>
                                       </fo:table-cell>
                                   </fo:table-row>  
                            </fo:table-body>
                    </fo:table>
                    )}
                </fo:block>
            case element(tei:speaker) return
                <fo:block font-style="italic" space-after=".25em">
                {tei2fo:tei2fo($node/node(),$p)}
                </fo:block> 
            case element(tei:stage) return
                <fo:block space-after="8mm" font-style="italic">{tei2fo:tei2fo($node/node(),$p)}</fo:block>    
            (: T :)
            case element(tei:TEI) return
                tei2fo:tei2fo($node/tei:text,$p)
            case element(tei:text) return
                tei2fo:tei2fo($node/node(),$p)			     
            case element(tei:title) return
                <fo:block>{$tei2fo:h1}{ tei2fo:tei2fo($node/node(),$p) }</fo:block>
            case element(tei:titlePage) return 
                <fo:block font-size="16pt" text-align="center">{$tei2fo:basic-block-element-attributes}
                    {tei2fo:tei2fo($node/node(),$p)}
                </fo:block>
            case element() return
                tei2fo:tei2fo($node/node(),$p)
            default return tei2fo:tei2fo($node/node(),$p)
};

(: Get or generate ids:)
declare %private function tei2fo:get-id($node as element(), $p) {
    if($node/@xml:id) then
        if($p gt 1) then concat('work',$p,'-',$node/@xml:id) else $node/@xml:id
    else if($node/@exist:id) then
        if($p gt 1) then concat('work',$p,'-',$node/@exist:id) else $node/@exist:id
    else generate-id($node)
};

(: Footnotes section :)
declare function tei2fo:footnotes($nodes,$p) {
if($nodes//tei:note[@target]) then 
<fo:block>
    <fo:block>{$tei2fo:h2}Footnotes</fo:block> 
        {
        if($nodes//tei:note[@target]) then
            <fo:table>{$tei2fo:basic-block-element-attributes}
                <fo:table-column column-width="10%"/>
                <fo:table-column column-width="90%"/>
                <fo:table-body>{
                   for $node in $nodes//tei:note[@target]
                   return
                       <fo:table-row>
                           <fo:table-cell>
                               {(if($node/@xml:id) then 
                                 (: WS:Note, this causes issues with coursepacks that may have duplicate IDs
                                 attribute id { tei2fo:get-id($node, $p) } 
                                 :) ''
                               else (), 
                               <fo:block margin-bottom="1.5em">{$tei2fo:basic-inline-element-attributes} {string($node/@xml:id)} </fo:block>)}
                           </fo:table-cell>
                           <fo:table-cell>
                               <fo:block>{tei2fo:tei2fo($node/node(),$p)}</fo:block>
                               {if($node/@resp) then
                                   <fo:block margin-bottom="1.5em"> - [{substring-after($node/@resp,'#')}]</fo:block>
                               else ()}
                           </fo:table-cell>
                       </fo:table-row>  
                   }
                </fo:table-body>
            </fo:table>
        else 
            for $node in $nodes
            return tei2fo:tei2fo($node/node(),$p)
        }
</fo:block>
else ()
};


(: Coursepacks section :)
declare function tei2fo:coursepacks($nodes) {
<fo:block>
    <fo:block>{$tei2fo:h2}Footnotes</fo:block> 
        {
        if($nodes//tei:note[@target]) then 
            <fo:table>{$tei2fo:basic-block-element-attributes}
             <fo:table-column column-width="10%"/>
             <fo:table-column column-width="90%"/>
             <fo:table-body>{
                for $node in $nodes//tei:note[@target]
                return
                    <fo:table-row>
                        <fo:table-cell>
                            {(if($node/@xml:id) then 
                               (: WS:Note, this causes issues with coursepacks that may have duplicate IDs
                               attribute id { $node/@xml:id }
                               :) ''
                            else (), 
                            <fo:block margin-bottom="1.5em">{$tei2fo:basic-inline-element-attributes} {string($node/@xml:id)} </fo:block>)}
                        </fo:table-cell>
                        <fo:table-cell>
                            <fo:block>{tei2fo:tei2fo($node/node(),$p)}</fo:block>
                            <fo:block margin-bottom="1.5em"> - [{substring-after($node/@resp,'#')}]</fo:block>
                        </fo:table-cell>
                    </fo:table-row>  
                }
             </fo:table-body>
         </fo:table>
        else             
            for $node in $nodes
            return tei2fo:tei2fo($node/node(),$p)
        }
</fo:block>
};


declare function tei2fo:titlepage($data as node()*)   {
    <fo:page-sequence master-reference="contents">
        <fo:flow flow-name="xsl-region-body">
            {$tei2fo:global-flow-styles}
            <fo:block font-size="44pt" text-align="center">
            { 
                if($data/descendant-or-self::coursepack) then
                    string($data/descendant-or-self::coursepack/@title | $data/descendant-or-self::coursepack/title )
                else $data//tei:titleStmt/tei:title/text() 
            }
            </fo:block>
            <fo:block text-align="center" font-size="24pt" space-before="2em" space-after="2em">
            {   
                if($data/descendant-or-self::coursepack) then
                   $data/descendant-or-self::coursepack/desc/text() 
                else 
                    let $authors := $data//tei:titleStmt/tei:author
                    let $author-full-names :=
                        for $author in $authors
                        return
                            concat($author//tei:forename[1], ' ', $author//tei:surname[1])
                    let $name-count := count($authors)
                    return
                    concat('By ',
                        if ($name-count le 2) then
                            string-join($author-full-names, ' and ')
                        else
                            concat(
                                string-join($author-full-names[position() = (1 to last() - 1)], 
                                ', '),', and ',$author-full-names[last()]))
                                                
            }
            </fo:block>
            <fo:block text-align="center" font-size="12pt" font-style="italic" space-before="4em" space-after="2em">
            {   
                if($data/descendant-or-self::coursepack) then ()
                else 
                    for $n in $data/descendant::tei:teiHeader/descendant::tei:respStmt
                    return concat($n/descendant::tei:resp, ' by ', string-join($n/descendant::tei:name,', ')) 
            }
            </fo:block>
        </fo:flow>                   
    </fo:page-sequence>
};

declare function tei2fo:table-of-contents($data as node()*) {
    <fo:page-sequence master-reference="contents">
        <fo:flow flow-name="xsl-region-body">
        <fo:block font-size="30pt" space-after="1em">Table of Contents</fo:block>
        {
            if($data/descendant-or-self::coursepack) then 
                for $toc at $p in $data//tei:TEI[descendant::tei:titleStmt/tei:title[1] != '']
                let $id := document-uri(root($toc))
                let $title := if($data//work[@id = $id]/text) then concat('Selections from',$toc/descendant::tei:titleStmt/tei:title[1]/text()) else $toc/descendant::tei:titleStmt/tei:title[1]/text()
                group by $workID := $id
                return 
                    <fo:block space-after="0.15in">
                        <fo:block text-align-last="justify">
                            {$title}
                            <fo:leader leader-pattern="dots"/>
                            <fo:page-number-citation ref-id="n{$p[1]}"/>
                        </fo:block>
                    </fo:block>     
            else 
                for $toc at $p in $data/tei:text/tei:body/tei:div[tei:head]
                return
                    <fo:block space-after="0.15in">
                        <fo:block text-align-last="justify">
                            {$toc/tei:head/descendant-or-self::*[not(self::tei:note)]/text()}
                            <fo:leader leader-pattern="dots"/>
                            <fo:page-number-citation ref-id="n{$p}"/>
                        </fo:block>
                    </fo:block>
        }
        </fo:flow>
    </fo:page-sequence>
};

declare function tei2fo:main($data as node()*) {
   <fo:root xmlns:fo="http://www.w3.org/1999/XSL/Format">
    <fo:layout-master-set>
      <fo:simple-page-master master-name="contents">
        <fo:region-body margin="0.5in" margin-bottom="1in"/>
        <fo:region-before extent="0.75in"/>
        <fo:region-after extent="0.25in"/>
      </fo:simple-page-master>
    </fo:layout-master-set>
    { tei2fo:titlepage($data) }
    { if($data/descendant-or-self::coursepack or count($data/descendant-or-self::tei:div[tei:head]) gt 1) then tei2fo:table-of-contents($data) else () }   
    <fo:page-sequence master-reference="contents">
        <fo:static-content flow-name="xsl-region-after">
            <fo:block border-top-style="solid" border-top-color="#666666" border-top-width=".015in" padding-top=".025in" margin-bottom="0in" padding-after="0in" padding-bottom="0">
                    <fo:block margin-top="4pt">
                        <fo:block text-align="center">
                            Page <fo:page-number/>
                        </fo:block>
                    </fo:block>
            </fo:block>
        </fo:static-content>
      <fo:flow flow-name="xsl-region-body" font-family="Times, Times New Roman, serif">
        <fo:block>{ 
                    if($data/descendant-or-self::coursepack) then 
                        let $coursepack := $data/descendant-or-self::coursepack
                        for $work at $p in $data//tei:TEI[descendant::tei:titleStmt/tei:title[1] != '']
                        let $title := $work/descendant::tei:title[1]/text()
                        let $id := document-uri(root($work))
                        let $selection := if($coursepack//work[@id = $id]/text) then
                                             for $text in $coursepack//work[@id = $id]/text
                                             return 
                                                (<fo:block font-size="18pt" text-align="center">Selected Text</fo:block>,
                                                tei2fo:tei2fo($text, $p))
                                        else()
                        group by $workID := $id
                        return
                            (<fo:block page-break-before="always">
                                    <fo:block font-size="24pt" text-align="center" id="n{$p[1]}">{if($selection != '') then 'Selections from: ' else ()}{$title}</fo:block>
                                    <fo:block text-align="center" font-size="18pt" space-before="2em" space-after="2em">{
                                        let $authors := $work//tei:titleStmt/tei:author
                                        let $author-full-names :=
                                            for $author in $authors
                                            return concat($author//tei:forename[1], ' ', $author//tei:surname[1])
                                        let $name-count := count($authors)
                                        return concat('By ', if ($name-count le 2) then string-join($author-full-names, ' and ') else concat(string-join($author-full-names[position() = (1 to last() - 1)], ', '),', and ',$author-full-names[last()]))                                          
                                    }</fo:block>
                                    <fo:block text-align="center" font-size="10pt" font-style="italic" space-before="4em" space-after="2em">{
                                        for $n in $work/descendant::tei:teiHeader/descendant::tei:respStmt
                                        return concat($n/descendant::tei:resp, ' by ', string-join($n/descendant::tei:name,', ')) 
                                    }</fo:block>
                                </fo:block>,
                                if($selection != '') then
                                    $selection  
                                else(  
                                    tei2fo:tei2fo($work, $p), 
                                    tei2fo:footnotes($work, $p))
                                    )   
                    else 
                        for $work at $p in $data/descendant-or-self::tei:TEI
                        return (
                            tei2fo:tei2fo($work, $p), 
                            tei2fo:footnotes($work, $p))
                    }
                </fo:block>
      </fo:flow>
    </fo:page-sequence>
   </fo:root>
};