xquery version "3.0";

module namespace jsonld="http://syriaca.org/jsonld";
(:~
 : Module returns coordinates as geoJSON
 : Formats include geoJSON 
 : @author Winona Salesky <wsalesky@gmail.com>
 : @authored 2014-06-25
:)

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace sparql="http://www.w3.org/2005/sparql-results#";
declare namespace json = "http://www.json.org";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function jsonld:sparql-JSON($results){
    for $node in $results
    return 
        typeswitch($node)
            case text() return $node
            case comment() return ()
            case element(sparql:variable) return element vars {string($node/@*:name)}
            case element(sparql:result) return element bindings {jsonld:sparql-JSON($node/node())}
            case element(sparql:binding) return element {string($node/@*:name)} {
                for $n in $node/node()
                return 
                    (element type {local-name($n)},
                     element value {normalize-space($n/text())},
                     if($n/@xml:lang) then 
                        element {xs:QName('xml:lang')} {string($n/@xml:lang)}
                     else()
                    )
            }
            case element() return jsonld:passthru($node)
            default return jsonld:sparql-JSON($node/node())
};

declare function jsonld:passthru($node as node()*) as item()* { 
    element {local-name($node)} {($node/@*, jsonld:sparql-JSON($node/node()))}
};

declare function jsonld:jsonld($node as node()*){
    (serialize(jsonld:sparql-JSON($node), 
        <output:serialization-parameters>
            <output:method>json</output:method>
        </output:serialization-parameters>)(:,
        response:set-header("Content-Type", "application/json"):)
        )
};