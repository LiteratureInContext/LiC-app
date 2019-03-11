xquery version "3.1";
(: For dynamicly loading functions.  :)

(: Import application modules. :)
import module namespace config="http://LiC.org/config" at "../config.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "../content-negotiation/tei2html.xqm";
import module namespace data="http://LiC.org/data" at "data.xqm";

(: Namespaces :)
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace html="http://www.w3.org/1999/xhtml";

(: Get all the elements with annotations :)
declare function local:get-annotated($tei as node()*, $contributor-id as xs:string?) {
<div xmlns="http://www.w3.org/1999/xhtml">{
    let $annotations := $tei//tei:text/descendant::tei:note[@resp= 'editors.xml#' || $contributor-id]
    for $annotation in $annotations
    let $annotation-id := string($annotation/@xml:id)
    let $snippet := $tei//*[@corresp= $annotation-id]
    return 
    <div>
        <span class="annotation-snippet">
            <!--<button class="btn btn-link" type="button" data-toggle="collapse" data-target="#collapse{$annotation-id}" aria-expanded="false" aria-controls="collapseExample">+/-</button>-->
            {tei2html:annotations($snippet)} 
        </span>
        <div class="indent lic-well">
            <span class="annotation">{tei2html:annotations($annotation)} </span>
        </div>
    </div>
}</div>
};

(: Get all the elements with annotations :)
declare function local:get-text-annotations($tei as node()*, $contributor-id as xs:string?) {
<div xmlns="http://www.w3.org/1999/xhtml">{
    let $annotations := $tei//tei:titleStmt//*[@ref= 'editors.xml#' || $contributor-id] | $tei//tei:teiHeader/descendant::tei:note[@resp= 'editors.xml#' || $contributor-id]
    for $annotation in $annotations
    return 
    <div>
        <div class="indent lic-well">
            <span class="annotation">{
            (: If respStmt:)
            if($annotation/ancestor-or-self::tei:respStmt) then
                ('Role: ', tei2html:annotations($annotation/ancestor-or-self::tei:respStmt/tei:resp))
            else if($annotation/ancestor-or-self::tei:editor) then 
                'Role: Editor'
            else tei2html:annotations($annotation)
            } </span>
        </div>
    </div>
}</div>
};

(: Get annotations for selected element :)
declare function local:get-annotation($tei as node()*, $contributor-id as xs:string?, $annotation-id as xs:string?) {
<div xmlns="http://www.w3.org/1999/xhtml">{
    let $annotations := local:get-annotated($tei, $contributor-id)
    let $annotation := $annotations//tei:text/descendant::tei:note[@xml:id = $annotation-id]
    return 
    <span class="annotation">{tei2html:annotations($annotation)} </span>
}</div>    
};

let $doc := request:get-parameter('doc', '')
let $annotationID := request:get-parameter('annotationID', '')
let $contributorID := request:get-parameter('contributorID', '')
return 
    if($doc != '') then 
        let $tei := 
            if(starts-with($doc,$config:data-root)) then 
                doc(xmldb:encode-uri($doc))
            else doc(xmldb:encode-uri($config:data-root || "/" || request:get-parameter('doc', '')))
        return 
            if(not(empty($tei))) then
                if(request:get-parameter('type', '') = 'text') then
                    local:get-text-annotations($tei, $contributorID)
                else if($annotationID != '') then 
                    local:get-annotation($tei,$contributorID,$annotationID)
                else if($contributorID != '') then 
                    local:get-annotated($tei, $contributorID)
                else 
                    (response:set-status-code( 404 ),
                        <response status="fail">
                            <message>No contributor specified found</message>
                        </response>)
            else 
                (response:set-status-code( 404 ),
                    <response status="fail">
                        <message>No TEI record found</message>
                    </response>)
        else 
            (response:set-status-code( 404 ),
                <response status="fail">
                    <message>No TEI record specified</message>
                </response>)
