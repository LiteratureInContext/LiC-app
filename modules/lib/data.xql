xquery version "3.1";
(:~  
 : Basic data interactions, returns raw data for use in other modules   
 : Not a library module
 : @depreciated, use /modules/data.xql
:)

import module namespace config="http://LiC.org/apps/config" at "../config.xqm";
import module namespace data="http://LiC.org/apps/data" at "data.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "../content-negotiation/tei2html.xqm";

import module namespace functx="http://www.functx.com";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace util="http://exist-db.org/xquery/util";

(: Get posted data :)
let $query := 
            if(request:get-parameter('query', '')) then  request:get-parameter('query', '') 
            else if(request:get-parameter('view', '') = 'expand' and request:get-parameter('workid', '') != '') then
                let $coursepack := collection($config:app-root || '/coursepacks')/coursepack[@id = request:get-parameter('id', '')]
                let $workid := request:get-parameter('workid', '')
                let $work := $coursepack//work[@id = $workid]
                return 
                    if($work/text) then
                        for $text in $work//text
                        return 
                            <div>
                             <h4>Selected Text</h4>
                             {util:parse-html($text/text())}
                            </div>
                    else 
                        let $work := doc(xmldb:encode-uri($workid))
                        return 
                        <div>{(tei2html:header($work/descendant::tei:teiHeader),
                                    tei2html:tei2html($work/descendant::tei:text),
                                    let $notes := $work/descendant::tei:note[@target]
                                    return
                                        if($notes != '') then 
                                            <div class="footnote show-print">
                                                <h3>Footnotes</h3>
                                                {for $n in $notes
                                                 return <div class="tei-footnote"><span class="tei-footnote-id">{string($n/@target)}</span>{tei2html:tei2html($n/node())}</div>
                                                 }
                                            </div>
                                        else ()
                                    )}</div>
            else request:get-data() 

return $query 
(:
    (response:set-header("Content-Type", "application/json"), $results)
:)