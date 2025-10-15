xquery version "3.1";
(:~  
 : Basic data interactions, returns raw data for use in other modules   
 : Not a library module
:)

import module namespace config="http://LiC.org/apps/config" at "config.xqm";
import module namespace data="http://LiC.org/apps/data" at "lib/data.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "content-negotiation/tei2html.xqm";
import module namespace maps="http://LiC.org/apps/maps" at "lib/maps.xqm";

import module namespace functx="http://www.functx.com";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace util="http://exist-db.org/xquery/util";

(: Get posted data :)
let $results := 
            if(request:get-parameter('query', '')) then 
                if(request:get-parameter('query', '') = 'geojson') then
                    doc(xmldb:encode-uri(concat($config:app-root,'/resources/lodHelpers/geojson.xml')))
                else data:search()
            else if(request:get-parameter('recID', '')) then
                let $rec := collection($config:data-root)/tei:TEI[@xml:id=request:get-parameter('recID', '')][1]
                let $recID := concat($config:nav-base,'/work',substring-before(replace(document-uri(root($rec)),$config:data-root,''),'.xml'))
                return response:redirect-to(xs:anyURI($recID))   
            else if(request:get-parameter('facet-author', '')) then 
                data:search()
            else if(request:get-parameter('getPage', '') != '') then 
                let $data := data:get-document(request:get-parameter('workID', ''))
                return tei2html:get-page($data, request:get-parameter('getPage', ''))
            else if(request:get-parameter('view', '') = 'expand' and request:get-parameter('workid', '') != '') then
                let $coursepack := collection($config:app-root || '/coursepacks')/coursepack[@id = request:get-parameter('id', '')]
                let $workid := request:get-parameter('workid', '')
                let $work := $coursepack//work[@id = $workid]
                return 
                    if($work/text) then
                        for $text in $work/text
                        return 
                            <div>
                                 <h4>Selected Text</h4>
                                 {$text}
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
return 
    if(request:get-parameter('getPage', '') != '') then 
        $results
    else if(request:get-parameter('view', '') = 'expand' and request:get-parameter('workid', '') != '') then
        $results
    else if(request:get-parameter('facet-author', '')) then
        for $hit in $results
        let $title := $hit/descendant::tei:title[1]/text()
        let $id := document-uri(root($hit))
        return 
            <div class="result row">
                <span class="checkbox col-md-1"><input type="checkbox" name="target-texts" class="coursepack" value="{$id}" data-title="{$title}" aria-label="{$title}"/></span>
                    <span class="col-md-11">
                        {(tei2html:summary-view($hit, (), $id[1])) }
                    </span>
                </div>  
    else (response:set-header("Content-Type", "application/json"),
        serialize($results, 
            <output:serialization-parameters>
                <output:method>json</output:method>
            </output:serialization-parameters>))    