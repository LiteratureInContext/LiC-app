xquery version "3.0";

module namespace tei2fo="http://LiC.org/apps/tei2fo";
import module namespace config="http://LiC.org/apps/config" at "../config.xqm";

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
                <fo:block space-after="8mm">{tei2fo:get-id($node,$p)}{tei2fo:tei2fo($node/node(),$p)}</fo:block>            
            (: C :)
            case element(tei:castList) return 
                <fo:block>{tei2fo:get-id($node,$p)}
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
                    {tei2fo:get-id($node,$p)}
                        {$tei2fo:basic-block-element-attributes}
                        {tei2fo:tei2fo($node/node(),$p)}
                    </fo:block>
            case element(tei:docImprint) return 
                if($node/parent::tei:titlePage) then 
                    <fo:block font-size="12pt" margin-top="5em">{tei2fo:get-id($node,$p)}{$tei2fo:basic-block-element-attributes}
                        {tei2fo:tei2fo($node/node(),$p)}   
                    </fo:block>
                else tei2fo:tei2fo($node/node(),$p)
            (: F :)                    
            case element(tei:front) return 
                <fo:block page-break-after="always" border-bottom="1mm" border-top="1mm">{tei2fo:get-id($node,$p)}
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
                        <fo:block>{tei2fo:get-id($node,$p)}{$tei2fo:h1}{ tei2fo:tei2fo($node/node(),$p) }</fo:block>
                    else
                        <fo:block>{tei2fo:get-id($node,$p)}{$tei2fo:h2}
                            <fo:marker marker-class-name="titel">
                                {$node/text()}
                            </fo:marker>
                            { tei2fo:tei2fo($node/node(),$p) }
                        </fo:block>            
            case element(tei:hi) return
                if($node/@rend='bold') then
                    <fo:inline font-weight="bold">{tei2fo:get-id($node,$p)}{$tei2fo:basic-inline-element-attributes}{tei2fo:tei2fo($node/node(),$p)}</fo:inline>   
                else if($node/@rend='italic') then 
                    <fo:inline font-style="italic">{tei2fo:get-id($node,$p)}{$tei2fo:basic-inline-element-attributes}{tei2fo:tei2fo($node/node(),$p)}</fo:inline>
                else if($node/@rend=('superscript','sup')) then
                    <fo:inline vertical-align="super" font-size="8pt">{tei2fo:get-id($node,$p)}{tei2fo:tei2fo($node/node(),$p)}</fo:inline>
                else if($node/@rend=('subscript','sub')) then
                    <fo:inline vertical-align="sub" font-size="8pt">{tei2fo:get-id($node,$p)}{tei2fo:tei2fo($node/node(),$p)}</fo:inline>
                else if($node/@rend='smallcaps') then 
                    <fo:inline font-variant="smallcaps">{tei2fo:get-id($node,$p)}{$tei2fo:basic-inline-element-attributes}{tei2fo:tei2fo($node/node(),$p)}</fo:inline>
                else if($node/@rend='underline') then 
                    <fo:inline text-decoration="underline">{tei2fo:get-id($node,$p)}{$tei2fo:basic-inline-element-attributes}{tei2fo:tei2fo($node/node(),$p)}</fo:inline>                    
                else tei2fo:tei2fo($node/node(),$p) 
            (: I :)
            case element(tei:imprint) return
                <fo:block>
            {
                    if($node//tei:pubPlace//text()) then $node//tei:pubPlace[1]//text() else (),
                    if($node//tei:pubPlace//text() and $node//tei:publisher//text()) then ': ' else (),
                    if($node//tei:publisher//text()) then $node//tei:publisher[1]//text() else (),
                    if(not($node//tei:pubPlace) and not($node//tei:publisher) and $node//tei:title[@level='m']) then 'n.p.' else (),
                    if($node//tei:date/preceding-sibling::*) then ', ' else (),
                    if($node//tei:date) then $node//tei:date else 'n.d.',
                    if($node/following-sibling::tei:biblScope[@unit='series']) then ', ' else (),
                    if($node//tei:extent/@type = "online") then (' ',<fo:basic-link external-destination="url({$node//tei:extent})"> View </fo:basic-link>) else $node//tei:extent,
                    if($node//tei:note) then 
                        if($node//tei:note[@type="sidenote"]) then 
                            <fo:block>{$tei2fo:basic-block-element-attributes}{tei2fo:tei2fo($node//tei:note,$p)}</fo:block>
                        else <fo:block>{$tei2fo:basic-block-element-attributes}{tei2fo:tei2fo($node//tei:note,$p)}</fo:block> 
                   else ()
            }</fo:block>
            (: L :)
            case element(tei:l) return
                <fo:block>{tei2fo:get-id($node,$p)}
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
                <fo:block>{tei2fo:get-id($node,$p)}{$tei2fo:basic-block-element-attributes}{tei2fo:tei2fo($node/node(),$p)}</fo:block>
            (: N :)
            case element(tei:note) return 
                if($node/@target) then () 
                else <fo:block>{tei2fo:get-id($node,$p)}{$tei2fo:basic-block-element-attributes}{ tei2fo:tei2fo($node/node(),$p) }</fo:block>
            (: P :)
            case element(tei:p) return 
                <fo:block>{tei2fo:get-id($node,$p)}{$tei2fo:basic-block-element-attributes}{ tei2fo:tei2fo($node/node(),$p) }</fo:block>            
            case element(tei:pb) return 
                <fo:block text-align="center">{tei2fo:get-id($node,$p)}{$tei2fo:basic-block-element-attributes} - {string($node/@n)} - </fo:block>
            (: R :)
            case element(tei:ref) return
                   if($node/@corresp) then 
                        (
                        <fo:basic-link internal-destination="{
                            if($p gt 1) then 
                               concat('work',$p,'-',string($node/@corresp)) 
                            else string($node/@corresp)
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
                if($node/tei:castItem) then 
                    <fo:block>{tei2fo:get-id($node,$p)}
                        {(
                        $tei2fo:basic-block-element-attributes,
                        <fo:table>
                            {$tei2fo:basic-block-element-attributes}
                            <fo:table-column column-width="20%"/>
                            <fo:table-column column-width="80%"/>
                            <fo:table-body>{
                                for $node in $node/tei:castItem
                                return
                                       <fo:table-row>
                                           <fo:table-cell>
                                               <fo:block margin-bottom="1.5em">{tei2fo:tei2fo($node/tei:speaker,$p)} </fo:block>
                                           </fo:table-cell>
                                           <fo:table-cell>
                                               <fo:block>{tei2fo:tei2fo($node/tei:l,$p)}</fo:block>
                                           </fo:table-cell>
                                       </fo:table-row>  
                                   }
                                </fo:table-body>
                        </fo:table>
                        )}
                    </fo:block>
                else 
                    <fo:block>{tei2fo:get-id($node,$p)}
                        {(
                            $tei2fo:basic-block-element-attributes,
                            tei2fo:tei2fo($node/node(),$p)
                         )}
                    </fo:block>
            case element(tei:speaker) return
                <fo:block font-style="italic" space-after=".25em">{tei2fo:get-id($node,$p)}
                {tei2fo:tei2fo($node/node(),$p)}
                </fo:block> 
            case element(tei:stage) return
                <fo:block space-after="8mm" font-style="italic">{tei2fo:get-id($node,$p)}{tei2fo:tei2fo($node/node(),$p)}</fo:block>    
            (: T :)
            case element(tei:TEI) return
                tei2fo:tei2fo($node/tei:text,$p)
            case element(tei:text) return
                tei2fo:tei2fo($node/node(),$p)			     
            case element(tei:title) return
                <fo:block>{tei2fo:get-id($node,$p)}{$tei2fo:h1}{ tei2fo:tei2fo($node/node(),$p) }</fo:block>
            case element(tei:titlePage) return 
                <fo:block font-size="16pt" text-align="center">{tei2fo:get-id($node,$p)}{$tei2fo:basic-block-element-attributes}
                    {tei2fo:tei2fo($node/node(),$p)}
                </fo:block>
            case element(tei:titlePart) return 
                <fo:block font-size="16pt" text-align="center">{tei2fo:get-id($node,$p)}{$tei2fo:basic-block-element-attributes}
                    {tei2fo:tei2fo($node/node(),$p) (:normalize-space(string-join($node/descendant::text(),'')):)}
                </fo:block>
            case element() return
                tei2fo:tei2fo($node/node(),$p)
            default return tei2fo:tei2fo($node/node(),$p)
};


(: Get or generate ids:)
declare %private function tei2fo:get-id($node as element(), $p) {
let $id := 
    if($node/@xml:id) then
        if($p gt 1) then concat('work',$p,'-',$node/@xml:id) else string($node/@xml:id)
    else ()
return 
    if($id != '') then
        attribute id {$id}
    else ()    
};



(: Footnotes section :)
declare function tei2fo:footnotes($nodes,$p) {
    if($nodes//tei:note[@target]) then 
        <fo:block>
            <fo:block>{$tei2fo:h2}Notes</fo:block> 
            {
                for $node in $nodes//tei:note[@target]
                return
                ( 
                <fo:block>{tei2fo:get-id($node,$p)}{$tei2fo:basic-inline-element-attributes} {string($node/@xml:id)} </fo:block>,
                <fo:block>{$tei2fo:basic-inline-element-attributes} {tei2fo:tei2fo($node/node(),$p)}</fo:block>,
                    if($node/@resp) then
                        <fo:block margin-bottom="1.5em"> - [{substring-after($node/@resp,'#')}]</fo:block>
                     else ()
                    )
                }
        </fo:block>
        else ()
};


(: Coursepacks section :)
declare function tei2fo:coursepacks($nodes) {
if($nodes//tei:note[@target]) then 
<fo:block>
    <fo:block>{tei2fo:get-id($node,$p)}{$tei2fo:h2}Footnotes</fo:block> 
        {
            for $node in $nodes//tei:note[@target]
            return
                  (
                  <fo:block margin-bottom="1.5em">{$tei2fo:basic-inline-element-attributes} {string($node/@xml:id)} </fo:block>,
                  <fo:block>{tei2fo:tei2fo($node/node(),$p)}</fo:block>,
                  <fo:block margin-bottom="1.5em"> - [{substring-after($node/@resp,'#')}]</fo:block>)
         }
</fo:block>
else
    <fo:block>{tei2fo:get-id($node,$p)}
        {tei2fo:tei2fo($node/node(),$p)}
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
            <fo:block text-align="center" font-size="18pt" space-before="2em" space-after="2em">
            {   
                if($data/descendant-or-self::coursepack) then
                   concat('Instructor: ', $data/descendant-or-self::coursepack/instructor/text()) 
                else 
                    let $authors := $data//tei:titleStmt/tei:author
                    let $author-full-names :=
                        for $author in $authors
                        return concat($author/descendant::tei:forename[1], ' ', $author/descendant::tei:surname[1])
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
                if($data/descendant-or-self::coursepack) then 
                    $data/descendant-or-self::coursepack/desc/text()
                else (:WS:NOTE COME BACK TO THIS:)
                    for $n in $data/descendant::tei:teiHeader/descendant::tei:respStmt
                    return concat($n/descendant::tei:resp, ' by ', string-join($n/descendant::tei:name[1]/text(),', '))
            }
            </fo:block>
        </fo:flow>                   
    </fo:page-sequence>
};

declare function tei2fo:table-of-contents($data as node()*) {
    <fo:page-sequence master-reference="contents">
        <fo:flow flow-name="xsl-region-body" font-family="Times, Times New Roman, serif">
        <fo:block font-size="30pt" space-after="1em">Table of Contents</fo:block>
        {
            if($data/descendant-or-self::coursepack) then 
                for $work at $p in $data/descendant-or-self::*:coursepack/*:work
                let $title := 
                    if($data/text) then 
                        concat('Selections from',$work/*:title[1]/text())
                    else $work/descendant::*:title[1]/text()
                order by xs:integer($work/@num)
                return 
                    <fo:block text-align-last="justify">
                        <fo:basic-link internal-destination="n{$p}">
                            {$title}
                            <!-- Dot Leaders -->
                            <fo:leader leader-length.minimum="12pt" 
                                       leader-length.optimum="40pt" 
                                       leader-length.maximum="100%" 
                                       leader-pattern="dots"/>
                            <!-- Target Page Number -->
                            <fo:page-number-citation ref-id="n{$p}"/>
                        </fo:basic-link>
                    </fo:block>

            else 
                for $toc at $p in $data/tei:text/tei:body/tei:div[tei:head]
                return
                    <fo:block text-align-last="justify">
                        <fo:basic-link internal-destination="n{$p}">
                            {$toc/tei:head/descendant-or-self::*[not(self::tei:note)]/text()}
                            <!-- Dot Leaders -->
                            <fo:leader leader-length.minimum="12pt" 
                                       leader-length.optimum="40pt" 
                                       leader-length.maximum="100%" 
                                       leader-pattern="dots"/>
                            <!-- Target Page Number -->
                            <fo:page-number-citation ref-id="n{$p}"/>
                        </fo:basic-link>
                    </fo:block>
        }
        </fo:flow>
    </fo:page-sequence>
};

declare function tei2fo:main($data as node()*) {
   <fo:root xmlns:fo="http://www.w3.org/1999/XSL/Format">
    <fo:layout-master-set>
      <fo:simple-page-master master-name="contents" page-height="11in" page-width="8.5in">
        <fo:region-body margin="1in"/>
        <fo:region-before extent="0.55in"/>
        <fo:region-after extent="0.55in"/>
      </fo:simple-page-master>
    </fo:layout-master-set>
    { tei2fo:titlepage($data) }
    { if($data/descendant-or-self::coursepack or count($data/descendant-or-self::tei:div[tei:head]) gt 1) then tei2fo:table-of-contents($data) else () }   
    <fo:page-sequence master-reference="contents">
        <fo:static-content flow-name="xsl-region-after">
            <fo:block font-size="8pt" color="#555555" margin-bottom="0.025in" margin-right=".25in"  margin-left=".25in" border-top="1pt solid #555555">
                    <fo:block margin-top="4pt">
                        
                        { if($data/descendant-or-self::coursepack) then
                            <fo:block text-align="right" padding-after="0.25in">Coursepack Page <fo:page-number/></fo:block>
                          else <fo:block text-align="center"><fo:page-number/></fo:block>
                        }
                    </fo:block>
            </fo:block>
        </fo:static-content>
      <fo:flow flow-name="xsl-region-body" font-family="Times, Times New Roman, serif">
        <fo:block>{ 
                    if($data/descendant-or-self::coursepack) then 
                        for $work at $p in $data/descendant-or-self::*:coursepack/*:work
                        let $workID := substring-before(tokenize($work/@id,'/')[last()],'.xml')
                        let $tei := $data/descendant::tei:TEI[@xml:id = $workID] 
                        let $title := 
                            if($data/text) then 
                                concat('Selections from',$work/*:title[1]/text())
                            else $tei/descendant::*:title[1]/text()
                        let $selection := if($work/text) then
                                             for $text in $work/text
                                             return 
                                                (<fo:block font-size="18pt" text-align="center">Selected Text</fo:block>,
                                                tei2fo:tei2fo($text, $p))
                                        else()
                        order by xs:integer($work/@num)
                        return 
                            (<fo:block page-break-before="always" id="n{$p}">
                                    <fo:block font-size="24pt" text-align="center">{if($selection != '') then 'Selections from: ' else ()}{$title}</fo:block>
                                    <fo:block text-align="center" font-size="18pt" space-before="2em" space-after="2em">{
                                        let $authors := $tei/descendant::tei:titleStmt/tei:author
                                        let $author-full-names :=
                                            for $author in $authors
                                            return concat($author/descendant::tei:forename[1], ' ', $author/descendant::tei:surname[1])
                                        let $name-count := count($authors)
                                        return concat('By ', if ($name-count le 2) then string-join($author-full-names, ' and ') else concat(string-join($author-full-names[position() = (1 to last() - 1)], ', '),', and ',$author-full-names[last()]))                                          
                                    }</fo:block>
                                    <fo:block text-align="center" font-size="10pt" font-style="italic" space-before="4em" space-after="2em">{
                                        for $n in $tei/descendant::tei:teiHeader/descendant::tei:respStmt
                                        return concat($n/descendant::tei:resp, ' by ', string-join($n/descendant::tei:name,', ')) 
                                    }</fo:block>
                                    <fo:block text-align="center" font-size="8pt" space-before="4em" space-after="2em">
                                        <fo:block font-size="10pt">Sources </fo:block>,
                                        {tei2fo:tei2fo($tei/descendant::tei:sourceDesc/descendant::tei:imprint, $p)}
                                    </fo:block>
                                </fo:block>,
                                <fo:block page-break-before="always">
                                    {if($selection != '') then
                                        $selection  
                                    else(  
                                        tei2fo:tei2fo($tei, $p), 
                                        tei2fo:footnotes($tei, $p))
                                        }
                                </fo:block>)   
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