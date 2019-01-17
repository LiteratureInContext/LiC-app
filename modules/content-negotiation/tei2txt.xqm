xquery version "3.0";
(:~
 : Builds tei conversions to plain text.
 :)
 
module namespace tei2txt="http://syriaca.org/tei2txt";
import module namespace tei2html="http://syriaca.org/tei2html" at "tei2html.xqm";
import module namespace config="http://LiC.org/config" at "../config.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace html="http://www.w3.org/1999/xhtml";

declare function tei2txt:typeswitch($nodes) {
    for $node in $nodes
    return 
        typeswitch($node)
            case text() return $node
            case comment() return ()
            case element(tei:pb) return 
                if($node/@n) then concat(' ', $node/@n,' ')
                else ()       
            case element(tei:lb) return 
                if($node/@n) then concat(' ', $node/@n,' ')
                else ()
            case element(tei:l) return 
                if($node/@n) then concat(' ', $node/@n,' ',tei2txt:typeswitch($node/node()))
                else tei2txt:typeswitch($node/node())
            case element(tei:teiHeader) return 
                normalize-space(string-join((tei2html:citation($node)),''))
            (:case element (html:span) return 
                if($node/@class[contains(.,'title-monographic') or contains(.,'title-journal')]) then 
                    ('\i',tei2txt:typeswitch($node/node()))
                else tei2txt:typeswitch($node/node()):)
            default return tei2txt:typeswitch($node/node())
};

declare function tei2txt:tei2txt($nodes as node()*) {
    tei2txt:typeswitch($nodes)
};
