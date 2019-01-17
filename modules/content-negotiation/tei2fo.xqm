xquery version "3.0";

module namespace tei2fo="http://LiC.org/tei2fo";
import module namespace config="http://LiC.org/config" at "../config.xqm";

declare namespace fo="http://www.w3.org/1999/XSL/Format";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function tei2fo:tei2fo($nodes as node()*) {
    for $node in $nodes
    return
        typeswitch ($node)
            case element(tei:TEI) return
                tei2fo:tei2fo($node/tei:text)
            case element(tei:text) return
                tei2fo:tei2fo($node//tei:body)
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
            case element(tei:div) return
                    <fo:block page-break-after="always" id="{generate-id($node)}">
                        {tei2fo:tei2fo($node/node())}
                    </fo:block>
            case element(tei:graphic) return
                <fo:block space-after="10pt">
				    <fo:external-graphic src="url({$node/@url})"/>
				    {
				        if($node/@width) then 
                            attribute width { $node/@width }
                        else ()
                    }
			     </fo:block>			     
            case element(tei:head) return
                let $level := count($node/ancestor-or-self::tei:div)
                return
                    if ($level = 1) then
                        <fo:block font-size="20pt" font-family="Arial, Helvetica, sans-serif" 
                            space-after="16mm" margin-top="28mm">{ tei2fo:tei2fo($node/node()) }</fo:block>
                    else
                        <fo:block font-size="16pt" font-weight="bold" space-after="10mm" margin-top="16mm"
                            font-family="Arial, Helvetica, sans-serif">
                            <fo:marker marker-class-name="titel">
                                {$node/text()}
                            </fo:marker>
                            { tei2fo:tei2fo($node/node()) }
                        </fo:block>
            case element(tei:hi) return
                if($node/@render='bold') then
                    <fo:inline font-weight="bold">{tei2fo:tei2fo($node/node())}</fo:inline>   
                else if($node/@render='italic') then 
                    <fo:inline font-style="italic">{tei2fo:tei2fo($node/node())}</fo:inline>
                else if($node/@render='sup') then
                    <fo:inline baseline-shift="super" font-size="8pt">{tei2fo:tei2fo($node/node())}</fo:inline>
                else if($node/@render='sub') then
                    <fo:inline baseline-shift="sub" font-size="8pt">{tei2fo:tei2fo($node/node())}</fo:inline>
                else tei2fo:tei2fo($node/node())
            case element(tei:speaker) return
                <fo:block font-style="italic" space-after=".25em">
                {tei2fo:tei2fo($node/node())}
                </fo:block>
            case element(tei:l) return
                <fo:block>{tei2fo:tei2fo($node/node())}</fo:block>
            case element(tei:lb) return
                <fo:block></fo:block>
            case element(tei:lg) return
                <fo:block space-after="8mm">{tei2fo:tei2fo($node/node())}</fo:block>                
            case element(tei:ab) return
                <fo:block space-after="8mm">{tei2fo:tei2fo($node/node())}</fo:block>
            case element(tei:stage) return
                <fo:block space-after="8mm" font-style="italic">{tei2fo:tei2fo($node/node())}</fo:block>
            case element(tei:title) return
                <fo:block font-size="20pt" font-family="Arial, Helvetica, sans-serif" 
                            space-after="16mm" margin-top="28mm">{ tei2fo:tei2fo($node/node()) }</fo:block>
            case element() return
                tei2fo:tei2fo($node/node())
            default return
                $node
};

declare function tei2fo:titlepage($data as node())   {
    <fo:page-sequence master-reference="contents">
        <fo:flow flow-name="xsl-region-body" font-family="Times, Times New Roman, serif">
            <fo:block font-size="44pt" text-align="center">
            { 
                if($data/descendant-or-self::coursepack) then
                    string($data/descendant-or-self::coursepack/@title)
                else $data/descendant::tei:fileDesc/tei:titleStmt/tei:title/text() 
            }
            </fo:block>
            <fo:block text-align="center" font-size="30pt" font-style="italic" space-before="2em" space-after="2em">
            {   
                if($data/descendant-or-self::coursepack) then
                   $data/descendant-or-self::coursepack/desc 
                else ('by ', $data/descendant::tei:fileDesc/tei:titleStmt/tei:author/text()) 
            }
            </fo:block>
        </fo:flow>                    
    </fo:page-sequence>
};

declare function tei2fo:table-of-contents($data as element()) {
    <fo:page-sequence master-reference="contents">
        <fo:flow flow-name="xsl-region-body" font-family="Times, Times New Roman, serif">
        <fo:block font-size="30pt" space-after="1em" font-family="Arial, Helvetica, sans-serif">Table of Contents</fo:block>
        {
            if($data/descendant-or-self::coursepack) then 
                for $toc in $data/descendant-or-self::tei:TEI
                let $title := $toc/descendant::tei:title[1]/text()
                return 
                    <fo:block space-after="3mm">
                        <fo:block text-align-last="justify">
                            {$title}
                            <fo:leader leader-pattern="dots"/>
                            <fo:page-number-citation ref-id="{generate-id($title)}"/>
                        </fo:block>
                    </fo:block>                    
            else 
                for $toc at $toc-count in $data/tei:text/tei:body/tei:div[tei:head]
                return
                    <fo:block space-after="3mm">
                        <fo:block text-align-last="justify">
                            {$toc/tei:head/text()}
                            <fo:leader leader-pattern="dots"/>
                            <fo:page-number-citation ref-id="{generate-id($toc)}"/>
                        </fo:block>
                    </fo:block>
        }
        </fo:flow>
    </fo:page-sequence>
};

declare function tei2fo:main($data as node()*) {
    <fo:root xmlns:fo="http://www.w3.org/1999/XSL/Format">
        <fo:layout-master-set>
            <fo:simple-page-master master-name="contents" page-width="8.5in" page-height="11in" margin-top="0.25in" margin-bottom="0.5in" margin-left="0.5in" margin-right="0.5in">
                <fo:region-body margin="0.5in" margin-bottom="1in"/>
                <fo:region-before extent="0.75in"/>
                <fo:region-after extent="0.2in"/>
            </fo:simple-page-master>
        </fo:layout-master-set>
        { tei2fo:titlepage($data) }
        { tei2fo:table-of-contents($data) }
        <fo:page-sequence master-reference="contents">
            <fo:static-content flow-name="xsl-region-after">
                <fo:block border-top-style="solid" border-top-color="#666666" border-top-width=".015in" padding-top=".025in" margin-bottom="0in" padding-after="0in" padding-bottom="0">
                    <fo:block color="gray" padding-top="0in" margin-top="-0.015in" border-top-style="solid" border-top-color="#gray" border-top-width=".01in">
                    <fo:block margin-top="4pt">
                        <fo:block text-align="center"></fo:block>
                            <fo:block text-align="center"> Page <fo:page-number/></fo:block>
                        </fo:block>
                    </fo:block>
                </fo:block>
            </fo:static-content>
            <fo:flow flow-name="xsl-region-body" font-family="Times, Times New Roman, serif">
                <fo:block>
                    { for $work in $data/descendant-or-self::tei:TEI
                      return tei2fo:tei2fo($work) }
                </fo:block>
            </fo:flow>
        </fo:page-sequence>
    </fo:root>
};