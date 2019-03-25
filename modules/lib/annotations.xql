xquery version "3.1";
(: For dynamically loading functions.  :)

(: Import application modules. :)
import module namespace config="http://LiC.org/config" at "../config.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "../content-negotiation/tei2html.xqm";
import module namespace data="http://LiC.org/data" at "data.xqm";

(: Namespaces :)
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace html="http://www.w3.org/1999/xhtml";

(: get first 5 annotations for specified contributor :)
(:let $annotations := $model("records")//tei:text/descendant::tei:note[@resp= 'editors.xml#' || $id]:)
declare function local:get-annotations($contributorID as xs:string?) {
<div xmlns="http://www.w3.org/1999/xhtml" class="indent">{
    let $annotations := collection($config:data-root)//tei:text/descendant::tei:note[@resp= 'editors.xml#' || $contributorID]
    return 
        (for $annotation at $p in $annotations
        group by $workID := document-uri(root($annotation))
        let $work := $annotation/ancestor-or-self::tei:TEI
        let $title := $work/descendant::tei:titleStmt/tei:title
        let $url := concat($config:nav-base,'/work',substring-before(replace($workID,$config:data-root,''),'.xml'))
        for $group in subsequence($title,1,5)
        order by normalize-space($title[1]) ascending
        return 
            <div class="annotations">
                <span class="title">
                    <button class="getAnnotated btn btn-link" data-toggle="tooltip" title="View annotations" data-work-id="{$workID}" data-contributor-id="{$contributorID}">
                        <span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span>
                    </button> 
                    <a href="{$url}" class="link-to-work" data-toggle="tooltip" title="Go to work"><span class="glyphicon glyphicon-book" aria-hidden="true"></span></a>&#160;
                    {tei2html:tei2html($title)} ({count($annotation)} annotations)</span>
                    <div class="annotationsResults"></div>
            </div>,
        if(count($annotations) = 0) then
            <p>No annotations at this time</p>
        else if(count($annotations) gt 1) then
            <div class="get-more"><br/><a href="contributors.html?contributorID={$contributorID}">See all annotations <span class="glyphicon glyphicon-circle-arrow-right" aria-hidden="true"></span></a></div>
        else()    
    )}
</div>
};

(: Get all the elements with annotations for a specified work :)
declare function local:get-annotated($tei as node()*, $contributorID as xs:string?) {
<div xmlns="http://www.w3.org/1999/xhtml">{
    let $annotations := $tei//tei:text/descendant::tei:note[@resp= 'editors.xml#' || $contributorID]
    for $annotation in $annotations
    let $annotationID := string($annotation/@xml:id)
    let $snippet := $tei//*[@corresp= $annotationID]
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
declare function local:get-text-annotations($tei as node()*, $contributorID as xs:string?) {
<div xmlns="http://www.w3.org/1999/xhtml">{
    let $annotations := $tei//tei:titleStmt//*[@ref= 'editors.xml#' || $contributorID] | $tei//tei:teiHeader/descendant::tei:note[@resp= 'editors.xml#' || $contributorID]
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
declare function local:get-annotation($tei as node()*, $contributorID as xs:string?, $annotationID as xs:string?) {
<div xmlns="http://www.w3.org/1999/xhtml">{
    let $annotations := local:get-annotated($tei, $contributorID)
    let $annotation := $annotations//tei:text/descendant::tei:note[@xml:id = $annotationID]
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
        else if($contributorID != '' and $doc = '') then 
            local:get-annotations($contributorID)
        else 
            (response:set-status-code( 404 ),
                <response status="fail">
                    <message>No TEI record specified</message>
                </response>)
